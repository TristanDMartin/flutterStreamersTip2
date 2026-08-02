import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:freezed_annotation/freezed_annotation.dart';
import '../features/activity/activity_notification_rules.dart';
import '../models/activity_notification.dart';
import '../models/user.dart' as app_user;
import '../services/public_profile_firestore.dart';
import '../services/user_blocking_service.dart';

part 'activity_provider.freezed.dart';

@freezed
sealed class ActivityState with _$ActivityState {
  const factory ActivityState({
    @Default({}) Map<String, List<ActivityNotification>> grouped,
    @Default(false) bool isLoading,
    @Default(false) bool isProcessing,
    @Default(0) int processingCount,
    String? error,
    @Default(false) bool hasError,
  }) = _ActivityState;
}

class ActivityNotifier extends StateNotifier<ActivityState> {
  ActivityNotifier() : super(const ActivityState());

  static const String _forumIdPrefix = 'forum:';

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _notifSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _forumSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _procSub;
  final Map<String, app_user.User> _userCache = <String, app_user.User>{};
  final Map<String, ActivityNotification> _primaryItems = {};
  final Map<String, ActivityNotification> _forumItems = {};
  bool _isMarkingAllRead = false;
  Completer<void>? _markAllCompleter;
  final Set<String> _forceDeliveredIds = <String>{};
  bool _isInitialized = false;
  String? _activeUserId;
  VoidCallback? _blockListListener;

  bool get isInitialized => _isInitialized;

  Future<void> init(String userId, {bool forceReload = false}) async {
    if (_isInitialized &&
        _activeUserId == userId &&
        !forceReload) {
      debugPrint(
        '⏭️ ActivityNotifier.init skipped — already loaded for $userId',
      );
      return;
    }
    debugPrint('🔄 ActivityNotifier.init called for user: $userId');
    debugPrint('  - _isInitialized: $_isInitialized');
    debugPrint('  - Current state: ${state.grouped.length} notifications');
    _isInitialized = true;
    _activeUserId = userId;

    try {
      await _notifSub?.cancel();
      final bool hasCachedNotifications = state.grouped.isNotEmpty;
      if (!hasCachedNotifications) {
        state = state.copyWith(isLoading: true, hasError: false, error: null);
      }

      debugPrint('🔄 Loading real data from Firestore...');
      await _loadFirestoreData(userId);
      _blockListListener ??= () {
        unawaited(_rebuildGroupedState());
      };
      UserBlockingService().blockListRevision.addListener(_blockListListener!);
    } catch (e) {
      debugPrint('❌ Error in init: $e');
      state = state.copyWith(
        isLoading: false,
        hasError: true,
        error: 'Failed to load notifications: ${e.toString()}',
      );
    }
  }

  Future<void> _loadFirestoreData(String userId) async {
    try {
      debugPrint(
          '🔍 ActivityNotifier: Setting up Firestore listener for user: $userId');
      debugPrint(
          '🔍 ActivityNotifier: Primary path: notifications/$userId/items');
      debugPrint('🔍 ActivityNotifier: Forum path: forumNotifications');

      await _notifSub?.cancel();
      await _forumSub?.cancel();
      _primaryItems.clear();
      _forumItems.clear();

      try {
        final QuerySnapshot<Map<String, dynamic>> primarySnapshot =
            await _queryPrimaryNotifications(userId);
        await _replacePrimarySnapshot(primarySnapshot);
        await _mergeUnreadPrimaryNotifications(userId);
      } catch (e) {
        debugPrint(
            '⚠️ ActivityNotifier: Primary notifications denied/failed: $e');
      }

      try {
        final QuerySnapshot<Map<String, dynamic>> forumSnapshot =
            await _queryForumNotifications(userId);
        await _replaceForumSnapshot(forumSnapshot);
      } catch (e) {
        debugPrint(
            '⚠️ ActivityNotifier: Forum notifications denied/failed: $e');
      }

      unawaited(_rebuildGroupedState());

      _notifSub = _listenPrimaryNotifications(userId);
      _forumSub = _listenForumNotifications(userId);
    } catch (e) {
      debugPrint('🚨 Error setting up Firestore listener: $e');
      state = state.copyWith(
        isLoading: false,
        hasError: true,
        error: 'Failed to setup notifications: ${e.toString()}',
      );
    }
  }

  CollectionReference<Map<String, dynamic>> _primaryCollection(String userId) {
    return _db.collection('notifications').doc(userId).collection('items');
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _queryPrimaryNotifications(
    String userId,
  ) async {
    final CollectionReference<Map<String, dynamic>> col =
        _primaryCollection(userId);
    try {
      return await col.orderBy('timestamp', descending: true).limit(75).get();
    } catch (e) {
      debugPrint(
        '⚠️ ActivityNotifier: orderBy timestamp failed, trying createdAt: $e',
      );
    }
    try {
      return await col.orderBy('createdAt', descending: true).limit(75).get();
    } catch (e) {
      debugPrint(
        '⚠️ ActivityNotifier: orderBy createdAt failed, unordered: $e',
      );
    }
    return col.limit(75).get();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _queryForumNotifications(
    String userId,
  ) async {
    final Query<Map<String, dynamic>> base = _db
        .collection('forumNotifications')
        .where('userId', isEqualTo: userId);
    try {
      return await base.orderBy('createdAt', descending: true).limit(75).get();
    } catch (e) {
      debugPrint(
        '⚠️ ActivityNotifier: forum orderBy createdAt failed, unordered: $e',
      );
    }
    return base.limit(75).get();
  }

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>
      _listenPrimaryNotifications(String userId) {
    return _primaryCollection(userId)
        .orderBy('timestamp', descending: true)
        .limit(75)
        .snapshots()
        .listen(
      (QuerySnapshot<Map<String, dynamic>> snap) {
        unawaited(_handlePrimarySnapshot(snap));
      },
      onError: (Object error) {
        debugPrint(
          '⚠️ ActivityNotifier: Primary timestamp listener error: $error',
        );
        unawaited(_attachPrimaryFallbackListener(userId));
      },
    );
  }

  Future<void> _attachPrimaryFallbackListener(String userId) async {
    await _notifSub?.cancel();
    final CollectionReference<Map<String, dynamic>> col =
        _primaryCollection(userId);
    try {
      _notifSub = col
          .orderBy('createdAt', descending: true)
          .limit(75)
          .snapshots()
          .listen(
        (QuerySnapshot<Map<String, dynamic>> snap) {
          unawaited(_handlePrimarySnapshot(snap));
        },
        onError: (Object error) {
          debugPrint(
            '⚠️ ActivityNotifier: Primary createdAt listener error: $error',
          );
          unawaited(_attachPrimaryUnorderedListener(userId));
        },
      );
      return;
    } catch (e) {
      debugPrint('⚠️ ActivityNotifier: createdAt listen setup failed: $e');
    }
    await _attachPrimaryUnorderedListener(userId);
  }

  Future<void> _attachPrimaryUnorderedListener(String userId) async {
    await _notifSub?.cancel();
    _notifSub = _primaryCollection(userId).limit(75).snapshots().listen(
      (QuerySnapshot<Map<String, dynamic>> snap) {
        unawaited(_handlePrimarySnapshot(snap));
      },
      onError: (Object error) {
        debugPrint(
          '⚠️ ActivityNotifier: Primary unordered listener error: $error',
        );
        // Keep last good items — never wipe the feed on a transient error.
      },
    );
  }

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>
      _listenForumNotifications(String userId) {
    return _db
        .collection('forumNotifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(75)
        .snapshots()
        .listen(
      (QuerySnapshot<Map<String, dynamic>> snap) {
        unawaited(_handleForumSnapshot(snap));
      },
      onError: (Object error) {
        debugPrint('⚠️ ActivityNotifier: Forum listener error: $error');
        unawaited(_attachForumUnorderedListener(userId));
      },
    );
  }

  Future<void> _attachForumUnorderedListener(String userId) async {
    await _forumSub?.cancel();
    _forumSub = _db
        .collection('forumNotifications')
        .where('userId', isEqualTo: userId)
        .limit(75)
        .snapshots()
        .listen(
      (QuerySnapshot<Map<String, dynamic>> snap) {
        unawaited(_handleForumSnapshot(snap));
      },
      onError: (Object error) {
        debugPrint(
          '⚠️ ActivityNotifier: Forum unordered listener error: $error',
        );
      },
    );
  }

  Future<void> _handlePrimarySnapshot(
      QuerySnapshot<Map<String, dynamic>> snap) async {
    try {
      await _replacePrimarySnapshot(snap);
      final String? uid = fa.FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await _mergeUnreadPrimaryNotifications(uid);
      }
      unawaited(_rebuildGroupedState());
    } catch (e) {
      debugPrint('🚨 Primary notification parsing error: $e');
      state = state.copyWith(
        hasError: true,
        error: 'Failed to parse notifications: ${e.toString()}',
      );
    }
  }

  /// Retention queue writers store epoch millis for `timestamp`. Those docs
  /// sort after Firestore Timestamps and can fall outside `limit(75)`. Pull
  /// unread explicitly so Tippy/planner items still appear (website parity).
  Future<void> _mergeUnreadPrimaryNotifications(String userId) async {
    if (_isMarkingAllRead) {
      return;
    }
    try {
      final QuerySnapshot<Map<String, dynamic>> unread = await _db
          .collection('notifications')
          .doc(userId)
          .collection('items')
          .where('isRead', isEqualTo: false)
          .limit(50)
          .get();
      if (unread.docs.isEmpty || _isMarkingAllRead) {
        return;
      }
      final List<ActivityNotification?> mapped = await Future.wait(
        unread.docs.map(_mapPrimaryNotificationDoc),
      );
      if (_isMarkingAllRead) {
        return;
      }
      for (final ActivityNotification? item in mapped) {
        if (item == null) {
          continue;
        }
        if (_forceDeliveredIds.contains(item.id)) {
          _primaryItems[item.id] = item.copyWith(status: 'delivered');
          continue;
        }
        final ActivityNotification? existing = _primaryItems[item.id];
        if (existing != null &&
            existing.status == 'delivered' &&
            item.status == 'pending') {
          // Stale unread get after mark-as-read — keep delivered.
          continue;
        }
        _primaryItems[item.id] = item;
      }
    } catch (e) {
      debugPrint('⚠️ ActivityNotifier: Unread merge skipped: $e');
    }
  }

  Future<void> _handleForumSnapshot(
      QuerySnapshot<Map<String, dynamic>> snap) async {
    try {
      await _replaceForumSnapshot(snap);
      unawaited(_rebuildGroupedState());
    } catch (e) {
      debugPrint('🚨 Forum notification parsing error: $e');
      state = state.copyWith(
        hasError: true,
        error: 'Failed to parse forum notifications: ${e.toString()}',
      );
    }
  }

  Future<void> _replacePrimarySnapshot(
      QuerySnapshot<Map<String, dynamic>> snap) async {
    final mappedItems = await Future.wait(
      snap.docs.map(_mapPrimaryNotificationDoc),
    );
    _primaryItems
      ..clear()
      ..addEntries(
        mappedItems
            .whereType<ActivityNotification>()
            .map((item) => MapEntry(item.id, item)),
      );
    debugPrint(
      '✅ ActivityNotifier: Primary notifications loaded: ${_primaryItems.length}',
    );
  }

  Future<void> _replaceForumSnapshot(
      QuerySnapshot<Map<String, dynamic>> snap) async {
    final mappedItems = await Future.wait(
      snap.docs.map(_mapForumNotificationDoc),
    );
    _forumItems
      ..clear()
      ..addEntries(
        mappedItems
            .whereType<ActivityNotification>()
            .map((item) => MapEntry(item.id, item)),
      );
    debugPrint(
      '✅ ActivityNotifier: Forum notifications loaded: ${_forumItems.length}',
    );
  }

  Future<void> _rebuildGroupedState() async {
    final Set<String> blockedUserIds =
        (await UserBlockingService().getBlockedUsers()).toSet();
    final rawItems = <ActivityNotification>[
      ..._primaryItems.values,
      ..._forumItems.values,
    ]..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final items = _dedupeNotifications(
      blockedUserIds.isEmpty
          ? rawItems
          : rawItems
              .where(
                (ActivityNotification notification) =>
                    !blockedUserIds.contains(notification.user.id),
              )
              .toList(growable: false),
    );

    final grouped = <String, List<ActivityNotification>>{};
    for (final n in items) {
      final key = _groupKey(n.timestamp);
      grouped.putIfAbsent(key, () => []).add(n);
    }

    state = state.copyWith(
      grouped: grouped,
      isLoading: false,
      hasError: false,
      error: null,
    );
  }

  List<ActivityNotification> _dedupeNotifications(
    List<ActivityNotification> items,
  ) {
    final byKey = <String, ActivityNotification>{};
    for (final item in items) {
      final key = _dedupeKey(item);
      final existing = byKey[key];
      if (existing == null || item.timestamp.isAfter(existing.timestamp)) {
        byKey[key] = item;
      }
    }

    final deduped = byKey.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final dropped = items.length - deduped.length;
    if (dropped > 0) {
      debugPrint('🧹 ActivityNotifier: Deduped $dropped repeated rows');
    }
    return deduped;
  }

  String _dedupeKey(ActivityNotification notification) {
    final targetId = notification.videoId ??
        notification.threadId ??
        notification.postId ??
        notification.parentCommentId ??
        notification.commentId ??
        notification.chatId ??
        '';
    return [
      notification.type.name,
      notification.user.id,
      targetId,
      notification.commentText ?? '',
    ].join('|');
  }

  Future<ActivityNotification?> _mapPrimaryNotificationDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data();
    final actorId = _notificationActorId(data);
    final videoId = _notificationVideoId(data);
    if (_isTestAccount(actorId) || _isTestVideo(videoId)) {
      return null;
    }

    final notificationType = (data['type'] ?? '').toString();
    if (shouldHideFromActivityFeed(notificationType)) {
      return null;
    }
    final bool isRead = !isActivityNotificationDocUnread(data) ||
        _forceDeliveredIds.contains(doc.id);
    final String displayMessage = activityNotificationDisplayMessage(data);
    final String thumbnailUrl = await _resolvePrimaryThumbnail(data, videoId);
    return ActivityNotification(
      id: doc.id,
      type: activityNotificationTypeFromString(notificationType),
      user: await _mapToUser(data),
      timestamp: readActivityTimestamp(data),
      postThumbnailUrl: thumbnailUrl.ifEmpty(null),
      commentText: displayMessage.ifEmpty(null),
      status: isRead ? 'delivered' : 'pending',
      videoId: videoId.ifEmpty(null),
      chatId: _stringField(data, const ['chatId']).ifEmpty(null),
      actionUrl: _stringField(data, const ['actionUrl']).ifEmpty(null),
      // Keep the Firestore type for Tippy/planner routing + filters.
      actionType: notificationType.isEmpty ? 'admin_broadcast' : notificationType,
      threadId: _stringField(data, const ['threadId']).ifEmpty(null),
      postId: _stringField(data, const ['postId']).ifEmpty(null),
      commentId: _stringField(data, const ['commentId']).ifEmpty(null),
      milestoneType: data['milestoneType'] as String?,
      milestoneValue: data['milestoneValue'] as int?,
      parentCommentId:
          _stringField(data, const ['parentCommentId', 'commentId'])
              .ifEmpty(null),
    );
  }

  Future<ActivityNotification?> _mapForumNotificationDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data();
    final actorId = _notificationActorId(data);
    if (_isTestAccount(actorId)) {
      return null;
    }

    final notificationType = (data['type'] ?? '').toString();
    final String forumId = '$_forumIdPrefix${doc.id}';
    final bool isRead = !isActivityNotificationDocUnread(data) ||
        _forceDeliveredIds.contains(forumId) ||
        _forceDeliveredIds.contains(doc.id);
    final String displayMessage = activityNotificationDisplayMessage(data);
    return ActivityNotification(
      id: forumId,
      type: activityNotificationTypeFromString(notificationType),
      user: await _mapToUser(data),
      timestamp: readActivityTimestamp(data),
      postThumbnailUrl: _stringField(data, const [
        'postThumbnailUrl',
        'thumbnailUrl',
        'thumbnailURL',
      ]).ifEmpty(null),
      commentText: displayMessage.isNotEmpty
          ? displayMessage
          : _stringField(data, const ['commentText', 'body', 'title'])
              .ifEmpty(null),
      status: isRead ? 'delivered' : 'pending',
      actionType:
          notificationType.isEmpty ? 'admin_broadcast' : notificationType,
      threadId: _stringField(data, const ['threadId', 'postId']).ifEmpty(null),
      postId: _stringField(data, const ['postId', 'threadId']).ifEmpty(null),
      commentId: _stringField(data, const ['commentId']).ifEmpty(null),
      parentCommentId:
          _stringField(data, const ['postId', 'threadId']).ifEmpty(null),
    );
  }

  Future<void> markAllDelivered(String userId) async {
    final Completer<void>? inFlight = _markAllCompleter;
    if (inFlight != null) {
      return inFlight.future;
    }
    final Completer<void> completer = Completer<void>();
    _markAllCompleter = completer;
    _isMarkingAllRead = true;
    final previousGrouped = state.grouped;
    debugPrint('📬 ActivityNotifier: markAllDelivered starting for $userId');
    try {
      _forceDeliveredIds
        ..addAll(_primaryItems.keys)
        ..addAll(_forumItems.keys);
      for (final String id in _primaryItems.keys.toList(growable: false)) {
        final ActivityNotification? item = _primaryItems[id];
        if (item == null || item.status == 'delivered') {
          continue;
        }
        _primaryItems[id] = item.copyWith(status: 'delivered');
      }
      for (final String id in _forumItems.keys.toList(growable: false)) {
        final ActivityNotification? item = _forumItems[id];
        if (item == null || item.status == 'delivered') {
          continue;
        }
        _forumItems[id] = item.copyWith(status: 'delivered');
      }
      state = state.copyWith(
        grouped: {
          for (final entry in state.grouped.entries)
            entry.key: entry.value
                .map((notification) =>
                    notification.copyWith(status: 'delivered'))
                .toList(growable: false),
        },
      );
      int totalMarked = 0;
      try {
        totalMarked += await _markPrimaryUnreadPages(userId);
      } catch (e) {
        debugPrint('⚠️ Primary mark all failed: $e');
      }
      try {
        totalMarked += await _markForumUnreadPages(userId);
      } catch (e) {
        debugPrint('⚠️ Forum mark all failed: $e');
      }
      debugPrint(
        '✅ ActivityNotifier: markAllDelivered finished — marked $totalMarked',
      );
    } catch (e) {
      debugPrint('❌ Error marking all as read: $e');
      state = state.copyWith(
        grouped: previousGrouped,
        hasError: true,
        error: 'Failed to mark notifications as read: ${e.toString()}',
      );
    } finally {
      _isMarkingAllRead = false;
      _markAllCompleter = null;
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
  }

  Future<int> _markPrimaryUnreadPages(String userId) async {
    int totalMarked = 0;
    for (int page = 0; page < 10; page++) {
      final QuerySnapshot<Map<String, dynamic>> qs = await _db
          .collection('notifications')
          .doc(userId)
          .collection('items')
          .where('isRead', isEqualTo: false)
          .limit(100)
          .get();
      if (qs.docs.isEmpty) {
        break;
      }
      final WriteBatch batch = _db.batch();
      for (final QueryDocumentSnapshot<Map<String, dynamic>> d in qs.docs) {
        _forceDeliveredIds.add(d.id);
        batch.update(d.reference, {
          'isRead': true,
          'read': true,
          'readAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      totalMarked += qs.docs.length;
      if (qs.docs.length < 100) {
        break;
      }
    }
    return totalMarked;
  }

  Future<int> _markForumUnreadPages(String userId) async {
    int totalMarked = 0;
    for (int page = 0; page < 10; page++) {
      final QuerySnapshot<Map<String, dynamic>> qsForum = await _db
          .collection('forumNotifications')
          .where('userId', isEqualTo: userId)
          .where('read', isEqualTo: false)
          .limit(100)
          .get();
      if (qsForum.docs.isEmpty) {
        break;
      }
      final WriteBatch batch = _db.batch();
      for (final QueryDocumentSnapshot<Map<String, dynamic>> d
          in qsForum.docs) {
        _forceDeliveredIds.add('$_forumIdPrefix${d.id}');
        _forceDeliveredIds.add(d.id);
        batch.update(d.reference, {
          'read': true,
          'readAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      totalMarked += qsForum.docs.length;
      if (qsForum.docs.length < 100) {
        break;
      }
    }
    return totalMarked;
  }

  Future<bool> markNotificationAsRead(String notificationId) async {
    final previousGrouped = state.grouped;
    try {
      final currentUser = fa.FirebaseAuth.instance.currentUser;
      if (currentUser == null) return false;

      _patchNotificationStatus(notificationId, 'delivered');

      if (notificationId.startsWith(_forumIdPrefix)) {
        final forumId = notificationId.substring(_forumIdPrefix.length);
        await _db.collection('forumNotifications').doc(forumId).update({
          'read': true,
          'readAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('✅ Marked forum notification $forumId as read');
      } else {
        await _db
            .collection('notifications')
            .doc(currentUser.uid)
            .collection('items')
            .doc(notificationId)
            .update({
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('✅ Marked notification $notificationId as read');
      }

      debugPrint('✅ Marked notification $notificationId as read');
      return true;
    } catch (e) {
      debugPrint('❌ Error marking notification as read: $e');
      state = state.copyWith(
        grouped: previousGrouped,
        hasError: false,
        error: null,
      );
      return false;
    }
  }

  void _patchNotificationStatus(String notificationId, String status) {
    final updatedGrouped = <String, List<ActivityNotification>>{};
    for (final entry in state.grouped.entries) {
      updatedGrouped[entry.key] = entry.value
          .map((notification) => notification.id == notificationId
              ? notification.copyWith(status: status)
              : notification)
          .toList(growable: false);
    }
    state = state.copyWith(grouped: updatedGrouped);
  }

  // Get count of unread notifications
  int getUnreadCount() {
    int count = 0;
    for (final notifications in state.grouped.values) {
      for (final notification in notifications) {
        // Check both status (legacy) and isRead (new structure)
        if (notification.status == 'pending') {
          count++;
        }
      }
    }
    return count;
  }

  String _stringField(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return '';
  }

  String _notificationActorId(Map<String, dynamic> data) {
    final nestedActor = data['actor'];
    final nestedActorMap = nestedActor is Map ? nestedActor : null;
    final nestedUser = data['user'];
    final nestedUserMap = nestedUser is Map ? nestedUser : null;
    final flatId = _stringField(data, const <String>[
      'actor.id',
      'actorId',
      'fromUserId',
      'sourceUserId',
      'senderId',
      'likerId',
      'commenterId',
      'followerId',
      'taggerId',
      'mentionerId',
    ]);
    if (flatId.isNotEmpty) return flatId;
    final actorId =
        (nestedActorMap?['id'] ?? nestedActorMap?['uid'] ?? '').toString();
    if (actorId.trim().isNotEmpty) return actorId.trim();
    return (nestedUserMap?['id'] ?? nestedUserMap?['uid'] ?? '').toString();
  }

  String _notificationVideoId(Map<String, dynamic> data) {
    final String type = (data['type'] ?? '').toString();
    // Retention / Tippy system prompts store targetId=uid — never treat as video.
    if (isGlobalSystemNotificationType(type)) {
      return _stringField(data, const <String>['videoId', 'mediaId']);
    }
    final metadata = data['metadata'];
    final metadataMap = metadata is Map ? metadata : null;
    return _stringField(data, const <String>[
          'videoId',
          'targetId',
          'mediaId',
        ]).ifEmpty((metadataMap?['videoId'] ?? '').toString().trim()) ??
        '';
  }

  Future<String> _resolvePrimaryThumbnail(
    Map<String, dynamic> data,
    String videoId,
  ) async {
    final directMuxId = _stringField(data, const <String>[
      'muxPlaybackId',
      'playbackId',
      'mux_playback_id',
    ]);
    if (directMuxId.isNotEmpty) {
      return _muxThumbnailUrl(directMuxId);
    }

    final directMuxThumbnail = _stringField(data, const <String>[
      'muxThumbnailUrl',
      'muxThumbnailURL',
      'mux_thumbnail_url',
    ]);
    if (directMuxThumbnail.isNotEmpty) {
      return _upgradeMuxThumbnailUrl(directMuxThumbnail);
    }

    if (videoId.isNotEmpty) {
      try {
        final videoDoc = await _db.collection('videos').doc(videoId).get();
        final videoData = videoDoc.data();
        if (videoData != null) {
          final videoMuxId = _stringField(videoData, const <String>[
            'muxPlaybackId',
            'playbackId',
            'mux_playback_id',
          ]);
          if (videoMuxId.isNotEmpty) {
            return _muxThumbnailUrl(videoMuxId);
          }
          final videoMuxThumbnail = _stringField(videoData, const <String>[
            'muxThumbnailUrl',
            'muxThumbnailURL',
            'mux_thumbnail_url',
          ]);
          if (videoMuxThumbnail.isNotEmpty) {
            return _upgradeMuxThumbnailUrl(videoMuxThumbnail);
          }
        }
      } catch (e) {
        debugPrint(
            '⚠️ ActivityNotifier: Failed to resolve video thumbnail: $e');
      }
    }

    final fallback = _stringField(data, const <String>[
      'postThumbnailUrl',
      'videoThumbnailUrl',
      'thumbnailUrl',
      'thumbnailURL',
      'imageUrl',
    ]);
    return _upgradeMuxThumbnailUrl(fallback);
  }

  String _muxThumbnailUrl(String playbackId) {
    return 'https://image.mux.com/$playbackId/thumbnail.jpg?width=720&height=1280&fit_mode=smartcrop';
  }

  String _upgradeMuxThumbnailUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host != 'image.mux.com') {
      return url;
    }
    final params = Map<String, String>.from(uri.queryParameters);
    params['width'] = '720';
    params['height'] = '1280';
    params['fit_mode'] = 'smartcrop';
    return uri.replace(queryParameters: params).toString();
  }

  Future<app_user.User?> _fetchUser(String userId) async {
    if (userId.isEmpty) return null;
    final cached = _userCache[userId];
    if (cached != null) return cached;

    try {
      // Prefer public mirror — private users/{uid} is owner-only.
      DocumentSnapshot<Map<String, dynamic>> doc =
          await _db.collection('publicUsers').doc(userId).get();
      if (!doc.exists) {
        final currentUid = fa.FirebaseAuth.instance.currentUser?.uid;
        if (currentUid != null && currentUid == userId) {
          doc = await _db.collection('users').doc(userId).get();
        }
      }
      if (!doc.exists) return null;
      final data = <String, dynamic>{
        'id': doc.id,
        ...?doc.data(),
      };
      final user = app_user.User.fromMap(data);
      _userCache[userId] = user;
      return user;
    } catch (e) {
      debugPrint('⚠️ ActivityNotifier: Failed to fetch user $userId: $e');
      return null;
    }
  }

  /// Map website and legacy notification structures to a populated User model.
  Future<app_user.User> _mapToUser(Map<String, dynamic> data) async {
    final nestedActor = data['actor'];
    if (nestedActor is Map && nestedActor.isNotEmpty) {
      final actorMap = Map<String, dynamic>.from(nestedActor);
      final actor = await _userFromNotificationMap(actorMap);
      if (actor != null) {
        _userCache[actor.id] = actor;
        return actor;
      }
    }

    final nestedUser = data['user'];
    if (nestedUser is Map && nestedUser.isNotEmpty) {
      final nestedMap = Map<String, dynamic>.from(nestedUser);
      final nested = await _userFromNotificationMap(nestedMap);
      if (nested != null) {
        _userCache[nested.id] = nested;
        return nested;
      }
    }

    final actorId = _notificationActorId(data);
    final fetchedUser = await _fetchUser(actorId);
    if (fetchedUser != null) return fetchedUser;

    final username = _stringField(data, const <String>[
      'actorUsername',
      'fromUsername',
      'fromUserName',
      'senderUsername',
      'likerUsername',
      'commenterUsername',
      'followerUsername',
      'taggerUsername',
      'mentionerUsername',
    ]);
    final displayName = _stringField(data, const <String>[
      'actorDisplayName',
      'fromDisplayName',
      'fromUserName',
      'senderDisplayName',
      'likerDisplayName',
      'commenterDisplayName',
      'followerDisplayName',
      'taggerDisplayName',
      'mentionerDisplayName',
    ]);
    final avatarUrl = _stringField(data, const <String>[
      'actorAvatarUrl',
      'actorAvatarURL',
      'fromAvatarUrl',
      'fromAvatarURL',
      'senderAvatarUrl',
      'avatarURL',
      'avatarUrl',
    ]);

    return app_user.User(
      id: actorId,
      username: username.isNotEmpty ? username : 'unknown',
      displayName: displayName.isNotEmpty
          ? displayName
          : (username.isNotEmpty ? username : 'Unknown User'),
      avatarURL: avatarUrl.isNotEmpty ? avatarUrl : null,
      onlineStatus: 'offline',
      hashtags: const [],
      followerCount: 0,
      followingCount: 0,
      postCount: 0,
      bio: null,
      aiSelf: '',
      calendarEvents: const [],
      privacy: const app_user.UserPrivacy(),
      pinnedVideoIds: const [],
      role: 'user',
    );
  }

  Future<app_user.User?> _userFromNotificationMap(
      Map<String, dynamic> data) async {
    final id = _stringField(data, const ['id', 'uid', 'userId']);
    if (id.isEmpty) return null;

    final fetchedUser = await _fetchUser(id);
    if (fetchedUser != null) return fetchedUser;

    final username =
        _stringField(data, const ['username', 'userName', 'handle']);
    final displayName =
        _stringField(data, const ['displayName', 'name', 'username']);
    final avatarUrl = _stringField(data, const [
      'avatarURL',
      'avatarUrl',
      'photoURL',
      'photoUrl',
    ]);

    return app_user.User(
      id: id,
      username: username.isNotEmpty ? username : id,
      displayName: displayName.isNotEmpty
          ? displayName
          : (username.isNotEmpty ? username : id),
      avatarURL: avatarUrl.isNotEmpty ? avatarUrl : null,
      onlineStatus: 'offline',
      hashtags: const [],
      followerCount: 0,
      followingCount: 0,
      postCount: 0,
      bio: null,
      aiSelf: '',
      calendarEvents: const [],
      privacy: const app_user.UserPrivacy(),
      pinnedVideoIds: const [],
      role: 'user',
    );
  }

  /// Check if an account ID is a test/fake account
  bool _isTestAccount(String? accountId) {
    return isSyntheticTestAccountId(accountId);
  }

  /// Check if a video ID is a test video
  bool _isTestVideo(String? videoId) {
    return isSyntheticTestVideoId(videoId);
  }

  /// Force refresh notifications from Firestore
  Future<void> refresh(String userId) async {
    debugPrint('🔄 Force refreshing notifications for user: $userId');
    await _loadFirestoreData(userId);
  }

  void startProcessingListener(String userId) {
    try {
      _procSub?.cancel();
      _procSub = _db.collection('notifications').doc(userId).snapshots().listen(
        (doc) {
          try {
            final data = doc.data() ?? {};
            state = state.copyWith(
              isProcessing: (data['isProcessing'] ?? false) as bool,
              processingCount: (data['processingCount'] ?? 0) as int,
            );
          } catch (e) {
            // Silently handle processing listener errors
            debugPrint('Error in processing listener: $e');
          }
        },
        onError: (error) {
          debugPrint('Processing listener error: $error');
        },
      );
    } catch (e) {
      debugPrint('Failed to start processing listener: $e');
    }
  }

  /// Test method to manually create notifications of all types
  Future<void> createTestNotification(String userId) async {
    try {
      debugPrint('🧪 Creating test notifications for user: $userId');

      // Get current user data for more realistic test notifications
      final currentUser = fa.FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        debugPrint('❌ No current user found for test notifications');
        return;
      }

      // Get current user's display name and photo URL
      final userDoc = await _db.collection('users').doc(currentUser.uid).get();
      final userData = userDoc.data() ?? {};

      final testUser = {
        'id': currentUser.uid,
        'username': userData['username'] ?? 'current_user',
        'displayName': userData['displayName'] ??
            currentUser.displayName ??
            'Current User',
        'avatarURL': userData['avatarURL'] ??
            currentUser.photoURL ??
            'https://images.unsplash.com/photo-1494790108755-2616b612b786?w=100&h=100&fit=crop&crop=face',
      };

      // Create all notification types
      final notificationTypes = [
        {
          'type': 'like',
          'data': {
            'videoId': 'test_video',
            'postThumbnailUrl':
                'https://images.unsplash.com/photo-1511512578047-dfb367046420?w=200&h=200&fit=crop'
          }
        },
        {'type': 'follow', 'data': {}},
        {
          'type': 'comment',
          'data': {
            'videoId': 'test_video',
            'commentText': 'Great video!',
            'postThumbnailUrl':
                'https://images.unsplash.com/photo-1511512578047-dfb367046420?w=200&h=200&fit=crop'
          }
        },
        {
          'type': 'tag',
          'data': {
            'videoId': 'test_video',
            'postThumbnailUrl':
                'https://images.unsplash.com/photo-1511512578047-dfb367046420?w=200&h=200&fit=crop'
          }
        },
        {
          'type': 'mention',
          'data': {
            'videoId': 'test_video',
            'postThumbnailUrl':
                'https://images.unsplash.com/photo-1511512578047-dfb367046420?w=200&h=200&fit=crop'
          }
        },
      ];

      for (final notificationType in notificationTypes) {
        final notificationData = {
          'type': notificationType['type'],
          'user': testUser,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'status': 'pending',
          ...notificationType['data'] as Map<String, dynamic>,
        };

        await _db
            .collection('notifications')
            .doc(userId)
            .collection('items')
            .add(notificationData);
      }

      debugPrint('✅ Test notifications created successfully (all types)');
    } catch (e) {
      debugPrint('❌ Error creating test notifications: $e');
    }
  }

  /// Method to create test notifications with different users for more realistic testing
  Future<void> createRealisticTestNotifications(String userId) async {
    try {
      debugPrint('🧪 Creating realistic test notifications for user: $userId');

      // Create notifications from different users with high-quality avatars
      final testUsers = [
        {
          'id': 'test_user_1',
          'username': 'gamer_pro',
          'displayName': 'Gamer Pro',
          'avatarURL':
              'https://images.unsplash.com/photo-1494790108755-2616b612b786?w=200&h=200&fit=crop&crop=face&auto=format&q=80',
        },
        {
          'id': 'test_user_2',
          'username': 'art_creator',
          'displayName': 'Art Creator',
          'avatarURL':
              'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&h=200&fit=crop&crop=face&auto=format&q=80',
        },
        {
          'id': 'test_user_3',
          'username': 'music_lover',
          'displayName': 'Music Lover',
          'avatarURL':
              'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=200&h=200&fit=crop&crop=face&auto=format&q=80',
        },
        {
          'id': 'test_user_4',
          'username': 'tech_reviewer',
          'displayName': 'Tech Reviewer',
          'avatarURL':
              'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=200&h=200&fit=crop&crop=face&auto=format&q=80',
        },
        {
          'id': 'test_user_5',
          'username': 'fitness_coach',
          'displayName': 'Fitness Coach',
          'avatarURL':
              'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200&h=200&fit=crop&crop=face&auto=format&q=80',
        },
      ];

      final now = DateTime.now();

      // Create various notification types from different users with high-quality video thumbnails
      final notifications = [
        {
          'type': 'like',
          'user': testUsers[0],
          'videoId': 'video_1',
          'postThumbnailUrl':
              'https://images.unsplash.com/photo-1511512578047-dfb367046420?w=300&h=300&fit=crop&auto=format&q=80',
          'timestamp':
              Timestamp.fromDate(now.subtract(const Duration(minutes: 5))),
          'status': 'pending',
        },
        {
          'type': 'follow',
          'user': testUsers[1],
          'timestamp':
              Timestamp.fromDate(now.subtract(const Duration(hours: 1))),
          'status': 'delivered',
        },
        {
          'type': 'comment',
          'user': testUsers[2],
          'videoId': 'video_2',
          'commentText': 'Amazing content! Keep it up! 🎵',
          'postThumbnailUrl':
              'https://images.unsplash.com/photo-1511512578047-dfb367046420?w=300&h=300&fit=crop&auto=format&q=80',
          'timestamp':
              Timestamp.fromDate(now.subtract(const Duration(hours: 2))),
          'status': 'delivered',
        },
        {
          'type': 'like',
          'user': testUsers[3],
          'videoId': 'video_3',
          'postThumbnailUrl':
              'https://images.unsplash.com/photo-1518709268805-4e9042af2176?w=300&h=300&fit=crop&auto=format&q=80',
          'timestamp':
              Timestamp.fromDate(now.subtract(const Duration(hours: 3))),
          'status': 'pending',
        },
        {
          'type': 'mention',
          'user': testUsers[4],
          'videoId': 'video_4',
          'postThumbnailUrl':
              'https://images.unsplash.com/photo-1511512578047-dfb367046420?w=300&h=300&fit=crop&auto=format&q=80',
          'timestamp':
              Timestamp.fromDate(now.subtract(const Duration(days: 1))),
          'status': 'delivered',
        },
        {
          'type': 'comment',
          'user': testUsers[0],
          'videoId': 'video_5',
          'commentText': 'This is incredible! 🔥',
          'postThumbnailUrl':
              'https://images.unsplash.com/photo-1518709268805-4e9042af2176?w=300&h=300&fit=crop&auto=format&q=80',
          'timestamp':
              Timestamp.fromDate(now.subtract(const Duration(hours: 4))),
          'status': 'delivered',
        },
        {
          'type': 'like',
          'user': testUsers[2],
          'videoId': 'video_6',
          'postThumbnailUrl':
              'https://images.unsplash.com/photo-1511512578047-dfb367046420?w=300&h=300&fit=crop&auto=format&q=80',
          'timestamp':
              Timestamp.fromDate(now.subtract(const Duration(hours: 6))),
          'status': 'pending',
        },
      ];

      for (final notification in notifications) {
        await _db
            .collection('notifications')
            .doc(userId)
            .collection('items')
            .add(notification);
      }

      debugPrint('✅ Realistic test notifications created successfully');
    } catch (e) {
      debugPrint('❌ Error creating realistic test notifications: $e');
    }
  }

  /// Method to simulate a comment notification from another user
  Future<void> simulateCommentNotification(
      String userId, String commenterId, String videoId) async {
    try {
      debugPrint('🧪 Simulating comment notification for user: $userId');

      // Get commenter user data
      final Map<String, dynamic>? commenterData =
          await PublicProfileFirestore.instance.getProfileMap(commenterId);
      if (commenterData == null) {
        debugPrint('❌ Commenter user not found: $commenterId');
        return;
      }

      // Create notification data
      final notificationData = {
        'type': 'comment',
        'user': {
          'id': commenterId,
          'username': commenterData['username'] ?? 'Unknown',
          'displayName': commenterData['displayName'] ?? 'Unknown',
          'avatarURL': commenterData['avatarURL'] ?? commenterData['avatarUrl'],
        },
        'videoId': videoId,
        'commentText': 'Great video! This is a test comment.',
        'postThumbnailUrl':
            'https://images.unsplash.com/photo-1511512578047-dfb367046420?w=200&h=200&fit=crop',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'status': 'pending',
      };

      // Add notification to Firestore
      await _db
          .collection('notifications')
          .doc(userId)
          .collection('items')
          .add(notificationData);

      debugPrint('✅ Comment notification simulated successfully');
    } catch (e) {
      debugPrint('❌ Error simulating comment notification: $e');
    }
  }

  /// Reset the provider to allow re-initialization
  void reset() {
    _isInitialized = false;
    _activeUserId = null;
    _notifSub?.cancel();
    _forumSub?.cancel();
    _procSub?.cancel();
    _primaryItems.clear();
    _forumItems.clear();
    _forceDeliveredIds.clear();
    state = const ActivityState();
  }

  @override
  void dispose() {
    debugPrint('🧹 ActivityNotifier: Disposing and cancelling listeners');
    if (_blockListListener != null) {
      UserBlockingService().blockListRevision.removeListener(_blockListListener!);
      _blockListListener = null;
    }
    _notifSub?.cancel();
    _forumSub?.cancel();
    _procSub?.cancel();
    _isInitialized = false;
    _activeUserId = null;
    super.dispose();
  }

  ActivityNotificationType _typeFromString(String s) {
    return activityNotificationTypeFromString(s);
  }

  String _groupKey(DateTime dt) {
    final now = DateTime.now();
    final d = DateTime(dt.year, dt.month, dt.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${dt.month}/${dt.day}/${dt.year}';
  }
}

final activityProvider =
    StateNotifierProvider<ActivityNotifier, ActivityState>((ref) {
  ref.keepAlive();
  return ActivityNotifier();
});

/// Suppresses Discover/nav unread after Activity is viewed until Firestore
/// confirms zero, or until unread grows past what was already acknowledged.
class ActivityNavUnreadBadge extends Notifier<int> {
  bool _suppressed = false;
  bool _awaitingBaseline = false;
  int _acknowledgedCount = 0;
  int _firestoreCount = 0;

  @override
  int build() {
    ref.keepAlive();
    ref.listen<AsyncValue<int>>(
      unreadActivityCountProvider,
      (AsyncValue<int>? previous, AsyncValue<int> next) {
        if (!next.hasValue) {
          return;
        }
        _firestoreCount = next.value ?? 0;
        _recompute();
      },
      fireImmediately: true,
    );
    return 0;
  }

  void clearAfterActivityViewed() {
    _suppressed = true;
    _awaitingBaseline = true;
    state = 0;
    _recompute();
  }

  void _recompute() {
    if (!_suppressed) {
      state = _firestoreCount;
      return;
    }
    if (_awaitingBaseline) {
      // Don't lock a 0 baseline before the unread stream has real data —
      // that would treat the first N as "brand new" and revive the badge.
      if (_firestoreCount > 0) {
        _acknowledgedCount = _firestoreCount;
        _awaitingBaseline = false;
      }
      state = 0;
      return;
    }
    if (_firestoreCount == 0) {
      _suppressed = false;
      _acknowledgedCount = 0;
      state = 0;
      return;
    }
    if (_firestoreCount <= _acknowledgedCount) {
      _acknowledgedCount = _firestoreCount;
      state = 0;
      return;
    }
    _suppressed = false;
    _acknowledgedCount = 0;
    state = _firestoreCount;
  }
}

final activityNavUnreadCountProvider =
    NotifierProvider<ActivityNavUnreadBadge, int>(ActivityNavUnreadBadge.new);

/// Live unread Activity badge count, matching the website contract.
final unreadActivityCountProvider = StreamProvider<int>((ref) {
  ref.keepAlive();
  final currentUser = fa.FirebaseAuth.instance.currentUser;
  if (currentUser == null) {
    return Stream<int>.value(0);
  }

  final controller = StreamController<int>();
  var primaryUnread = 0;
  var forumUnread = 0;
  var primaryReady = false;
  var forumReady = false;

  void emitIfReady() {
    if (!primaryReady || !forumReady || controller.isClosed) {
      return;
    }
    controller.add(primaryUnread + forumUnread);
  }

  final primarySub = FirebaseFirestore.instance
      .collection('notifications')
      .doc(currentUser.uid)
      .collection('items')
      .where('isRead', isEqualTo: false)
      .snapshots()
      .listen((snapshot) {
    primaryUnread = snapshot.docs.where((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
      final Map<String, dynamic> data = doc.data();
      if (shouldHideFromActivityUnreadBadge(data['type'] as String?)) {
        return false;
      }
      return isActivityNotificationDocUnread(data);
    }).length;
    primaryReady = true;
    emitIfReady();
  }, onError: (_) {
    primaryUnread = 0;
    primaryReady = true;
    emitIfReady();
  });

  final forumSub = FirebaseFirestore.instance
      .collection('forumNotifications')
      .where('userId', isEqualTo: currentUser.uid)
      .where('read', isEqualTo: false)
      .snapshots()
      .listen((snapshot) {
    forumUnread = snapshot.docs.length;
    forumReady = true;
    emitIfReady();
  }, onError: (_) {
    forumUnread = 0;
    forumReady = true;
    emitIfReady();
  });

  ref.onDispose(() {
    primarySub.cancel();
    forumSub.cancel();
    controller.close();
  });

  return controller.stream;
});

extension on String {
  String? ifEmpty(String? fallback) => isEmpty ? fallback : this;
}
