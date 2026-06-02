import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'offline_storage_service.dart';
import 'scheduled_post_service.dart';
import 'logging_service.dart';
import '../models/scheduled_post.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final OfflineStorageService _offlineStorage = OfflineStorageService();
  final ScheduledPostService _scheduledPostService = ScheduledPostService();
  final Connectivity _connectivity = Connectivity();

  Timer? _syncTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isSyncing = false;

  Future<void> initialize() async {
    try {
      // Start listening to connectivity changes
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        _onConnectivityChanged,
      );

      // Start periodic sync (every 5 minutes)
      _syncTimer = Timer.periodic(
        const Duration(minutes: 5),
        (_) => _performSync(),
      );

      // Perform initial sync
      await _performSync();

      LoggingService.instance
          .info('Sync service initialized', tag: 'SyncService');
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to initialize sync service',
        tag: 'SyncService',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _onConnectivityChanged(List<ConnectivityResult> results) async {
    final isConnected = results.any((result) =>
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.ethernet);

    if (isConnected) {
      LoggingService.instance
          .info('Network connected, starting sync', tag: 'SyncService');
      await _performSync();
    } else {
      LoggingService.instance.info(
          'Network disconnected, entering offline mode',
          tag: 'SyncService');
      await _offlineStorage.setOfflineMode(true);
    }
  }

  Future<void> _performSync() async {
    if (_isSyncing) return;

    try {
      _isSyncing = true;

      // Check if we're online
      final connectivityResults = await _connectivity.checkConnectivity();
      final isOnline = connectivityResults.any((result) =>
          result == ConnectivityResult.mobile ||
          result == ConnectivityResult.wifi ||
          result == ConnectivityResult.ethernet);

      if (!isOnline) {
        await _offlineStorage.setOfflineMode(true);
        return;
      }

      await _offlineStorage.setOfflineMode(false);

      // Sync pending changes to server
      await _syncPendingChanges();

      // Sync latest data from server
      await _syncFromServer();

      await _offlineStorage.setLastSyncTime(DateTime.now());

      LoggingService.instance
          .info('Sync completed successfully', tag: 'SyncService');
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Sync failed',
        tag: 'SyncService',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _syncPendingChanges() async {
    try {
      final pendingItems = await _offlineStorage.getPendingSyncItems();

      for (final item in pendingItems) {
        try {
          await _syncItem(item);
          await _offlineStorage.markSyncItemCompleted(item['id']);
        } catch (e) {
          LoggingService.instance.error(
            'Failed to sync item ${item['id']}: $e',
            tag: 'SyncService',
          );
          await _offlineStorage.markSyncItemFailed(item['id'], e.toString());
        }
      }
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to sync pending changes',
        tag: 'SyncService',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _syncItem(Map<String, dynamic> item) async {
    final tableName = item['table_name'];
    final operation = item['operation'];
    final data = jsonDecode(item['data']);

    switch (tableName) {
      case 'scheduled_posts':
        await _syncScheduledPost(operation, data);
        break;
      default:
        LoggingService.instance.warning(
          'Unknown table for sync: $tableName',
          tag: 'SyncService',
        );
    }
  }

  Future<void> _syncScheduledPost(
      String operation, Map<String, dynamic> data) async {
    switch (operation) {
      case 'upsert':
        final post = ScheduledPost.fromJson(data);
        await _scheduledPostService.createScheduledPost(
          caption: post.caption,
          tags: post.tags,
          visibility: post.visibility,
          media: post.media,
          platforms: post.platforms,
          schedule: post.schedule!,
          analyticsHints: post.analyticsHints,
        );
        break;
      case 'delete':
        await _scheduledPostService.cancelPost(data['id']);
        break;
      default:
        LoggingService.instance.warning(
          'Unknown operation for scheduled posts: $operation',
          tag: 'SyncService',
        );
    }
  }

  Future<void> _syncFromServer() async {
    try {
      // Sync scheduled posts from server
      final serverPosts = await _scheduledPostService.getScheduledPosts();
      for (final post in serverPosts) {
        await _offlineStorage.saveScheduledPost(post);
      }

      LoggingService.instance
          .info('Data synced from server', tag: 'SyncService');
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to sync from server',
        tag: 'SyncService',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // Manual sync methods
  Future<void> syncNow() async {
    await _performSync();
  }

  Future<void> forceSync() async {
    _isSyncing = false;
    await _performSync();
  }

  Future<bool> isOnline() async {
    try {
      final connectivityResults = await _connectivity.checkConnectivity();
      return connectivityResults.any((result) =>
          result == ConnectivityResult.mobile ||
          result == ConnectivityResult.wifi ||
          result == ConnectivityResult.ethernet);
    } catch (e) {
      return false;
    }
  }

  Future<bool> isOfflineMode() async {
    return await _offlineStorage.isOfflineMode();
  }

  Future<DateTime?> getLastSyncTime() async {
    return await _offlineStorage.getLastSyncTime();
  }

  Future<int> getPendingSyncCount() async {
    final pendingItems = await _offlineStorage.getPendingSyncItems();
    return pendingItems.length;
  }

  Future<void> clearSyncQueue() async {
    try {
      final db = await _offlineStorage.database;
      await db.delete('sync_queue');
      LoggingService.instance.info('Sync queue cleared', tag: 'SyncService');
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to clear sync queue',
        tag: 'SyncService',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> dispose() async {
    _syncTimer?.cancel();
    _connectivitySubscription?.cancel();
    await _offlineStorage.close();
  }
}
