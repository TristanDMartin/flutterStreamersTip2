import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'offline_storage_service.dart';
import 'sync_service.dart';
import 'caching_service.dart';
import 'accessibility_service.dart';
import 'logging_service.dart';

class AppInitializationService {
  static final AppInitializationService _instance = AppInitializationService._internal();
  factory AppInitializationService() => _instance;
  AppInitializationService._internal();

  final OfflineStorageService _offlineStorage = OfflineStorageService();
  final SyncService _syncService = SyncService();
  final CachingService _cachingService = CachingService();
  final AccessibilityService _accessibilityService = AccessibilityService();

  bool _isInitialized = false;

  Future<void> initializeApp(BuildContext context, WidgetRef ref) async {
    if (_isInitialized) return;

    try {
      LoggingService.instance.info('Initializing app services...', tag: 'AppInitializationService');

      // Initialize accessibility service first
      await _accessibilityService.initialize(context);

      // Initialize offline storage
      await _offlineStorage.database; // This will create the database if it doesn't exist

      // Initialize sync service
      await _syncService.initialize();

      // Cleanup expired cache
      await _cachingService.cleanupExpiredCache();

      _isInitialized = true;

      LoggingService.instance.info('App services initialized successfully', tag: 'AppInitializationService');
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to initialize app services',
        tag: 'AppInitializationService',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> dispose() async {
    try {
      await _syncService.dispose();
      await _offlineStorage.close();
      _cachingService.clearMemoryCache();
      
      LoggingService.instance.info('App services disposed', tag: 'AppInitializationService');
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to dispose app services',
        tag: 'AppInitializationService',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // Getters for services
  OfflineStorageService get offlineStorage => _offlineStorage;
  SyncService get syncService => _syncService;
  CachingService get cachingService => _cachingService;
  AccessibilityService get accessibilityService => _accessibilityService;

  bool get isInitialized => _isInitialized;
}
