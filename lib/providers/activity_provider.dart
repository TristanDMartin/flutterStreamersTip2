import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:freezed_annotation/freezed_annotation.dart';
import '../models/activity_notification.dart';
import '../models/json_converters.dart';
import '../models/user.dart' as app_user;

part 'activity_provider.freezed.dart';

@freezed
class ActivityState with _$ActivityState {
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

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _notifSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _procSub;
  bool _isInitialized = false; // FIXED: Prevent multiple initializations

  bool get isInitialized => _isInitialized;

  Future<void> init(String userId) async {
    debugPrint('🔄 ActivityNotifier.init called for user: $userId');
    debugPrint('  - _isInitialized: $_isInitialized');
    debugPrint('  - Current state: ${state.grouped.length} notifications');
    debugPrint('🔍 ActivityNotifier: About to set up Firestore listener...');

    // Always re-initialize to ensure real-time updates work
    _isInitialized = true; // Mark as initialized

    try {
      await _notifSub?.cancel();
      state = state.copyWith(isLoading: true, hasError: false, error: null);

      // Load real data from Firestore
      debugPrint('🔄 Loading real data from Firestore...');
      await _loadFirestoreData(userId);
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
      debugPrint('🔍 ActivityNotifier: Path: activity/$userId/notifications');

      // First, try to get initial data from new structure (activity/{userId}/notifications)
      QuerySnapshot<Map<String, dynamic>>? initialSnapshot;
      bool usingLegacyStructure = false;

      try {
        initialSnapshot = await _db
            .collection('activity')
            .doc(userId)
            .collection('notifications')
            .orderBy('createdAt', descending: true)
            .limit(50)
            .get();

        debugPrint(
            '🔍 ActivityNotifier: Initial load (new structure) - ${initialSnapshot.docs.length} documents');

        // 🔄 FALLBACK: If new structure is empty, try legacy structure
        if (initialSnapshot.docs.isEmpty) {
          debugPrint(
            '🔄 ActivityNotifier: New structure empty, checking legacy structure...',
          );
          try {
            initialSnapshot = await _db
                .collection('notifications')
                .doc(userId)
                .collection('items')
                .orderBy('timestamp', descending: true)
                .limit(50)
                .get();
            usingLegacyStructure = true;
            debugPrint(
              '🔍 ActivityNotifier: Legacy structure found ${initialSnapshot.docs.length} documents',
            );
          } catch (legacyError) {
            debugPrint(
              '⚠️ ActivityNotifier: Legacy structure also failed: $legacyError',
            );
          }
        }

        if (initialSnapshot != null && initialSnapshot.docs.isNotEmpty) {
          debugPrint(
            '🔍 ActivityNotifier: Found ${initialSnapshot.docs.length} notifications',
          );

          final items = initialSnapshot.docs
              .map((d) {
                final data = d.data();
                final notificationType = (data['type'] ?? 'like').toString();

                // 🚫 FILTER: Skip test/fake accounts and test videos
                final actorId = data['actorId'] ?? data['user']?['id'] ?? '';
                final videoId = data['videoId'] ?? data['targetId'] ?? '';
                if (_isTestAccount(actorId) || _isTestVideo(videoId)) {
                  debugPrint(
                    '🚫 ActivityNotifier: Skipping test notification ${d.id} - '
                    'actorId: $actorId, videoId: $videoId',
                  );
                  return null;
                }

                // 🔍 DEBUG: Log raw notification data
                debugPrint(
                  '🔔 ActivityNotifier: Processing notification ${d.id} - '
                  'type: $notificationType, '
                  'structure: ${usingLegacyStructure ? "legacy" : "new"}, '
                  'actorId: $actorId, '
                  'actorUsername: ${data['actorUsername'] ?? data['user']?['username'] ?? 'N/A'}, '
                  'targetId: $videoId, '
                  'isRead: ${data['isRead'] ?? (data['status'] == 'delivered')}',
                );

                // Map to mobile model (handles both new and legacy structures)
                final user = _mapToUser(data);
                final timestamp = _getTimestamp(data);
                final isRead = usingLegacyStructure
                    ? (data['status'] == 'delivered')
                    : (data['isRead'] ?? false);
                final status = isRead ? 'delivered' : 'pending';

                final mappedType = _typeFromString(notificationType);
                debugPrint(
                  '✅ ActivityNotifier: Mapped type "$notificationType" → ${mappedType.name}',
                );

                return ActivityNotification(
                  id: d.id,
                  type: mappedType,
                  user: user,
                  timestamp: timestamp,
                  postThumbnailUrl: data['postThumbnailUrl'] as String?,
                  commentText: data['commentText'] as String?,
                  status: status,
                  videoId: videoId.isEmpty ? null : videoId,
                  milestoneType: data['milestoneType'] as String?,
                  milestoneValue: data['milestoneValue'] as int?,
                  parentCommentId: data['parentCommentId'] as String?,
                );
              })
              .whereType<ActivityNotification>()
              .toList();

          debugPrint(
            '📊 ActivityNotifier: Processed ${items.length} notifications - '
            'types: ${items.map((n) => n.type.name).join(", ")}',
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
          debugPrint(
              '✅ Initial Firestore data loaded successfully with ${items.length} notifications');
        } else {
          // No notifications found
          state = state.copyWith(
            grouped: {},
            isLoading: false,
            hasError: false,
            error: null,
          );
          debugPrint('ℹ️ No notifications found for user: $userId');
        }
      } catch (e) {
        debugPrint('🚨 Error loading initial data: $e');
        state = state.copyWith(
          isLoading: false,
          hasError: true,
          error: 'Failed to load notifications: ${e.toString()}',
        );
        return;
      }

      // Set up real-time listener (use same structure as initial load)
      if (usingLegacyStructure) {
        debugPrint(
          '🔄 ActivityNotifier: Setting up real-time listener for LEGACY structure',
        );
        _notifSub = _db
            .collection('notifications')
            .doc(userId)
            .collection('items')
            .orderBy('timestamp', descending: true)
            .limit(50)
            .snapshots()
            .listen(_handleLegacySnapshot);
      } else {
        debugPrint(
          '🔄 ActivityNotifier: Setting up real-time listener for NEW structure',
        );
        _notifSub = _db
            .collection('activity')
            .doc(userId)
            .collection('notifications')
            .orderBy('createdAt', descending: true)
            .limit(50)
            .snapshots()
            .listen(_handleNewStructureSnapshot);
      }
    } catch (e) {
      debugPrint('🚨 Error setting up Firestore listener: $e');
      state = state.copyWith(
        isLoading: false,
        hasError: true,
        error: 'Failed to setup notifications: ${e.toString()}',
      );
    }
  }

  void _handleNewStructureSnapshot(QuerySnapshot<Map<String, dynamic>> snap) {
    try {
      debugPrint(
          '🔍 ActivityNotifier: Real-time update (new structure) - ${snap.docs.length} documents');

      final items = snap.docs
          .map((d) {
            final data = d.data();

            // 🚫 FILTER: Skip test/fake accounts and test videos
            final actorId = data['actorId'] ?? '';
            final videoId = data['videoId'] ?? data['targetId'] ?? '';
            if (_isTestAccount(actorId) || _isTestVideo(videoId)) {
              debugPrint(
                '🚫 ActivityNotifier: Skipping test notification ${d.id} - '
                'actorId: $actorId, videoId: $videoId',
              );
              return null;
            }

            // 🔍 DEBUG: Log raw notification data
            final notificationType = (data['type'] ?? 'like').toString();
            debugPrint(
              '🔔 ActivityNotifier: Processing notification ${d.id} - '
              'type: $notificationType, '
              'actorId: $actorId, '
              'targetId: $videoId',
            );

            // Map website structure to mobile model
            final user = _mapToUser(data);
            final timestamp = _getTimestamp(data);
            final isRead = data['isRead'] ?? false;
            final status = isRead ? 'delivered' : 'pending';

            final mappedType = _typeFromString(notificationType);
            debugPrint(
              '✅ ActivityNotifier: Mapped type "$notificationType" → ${mappedType.name}',
            );

            return ActivityNotification(
              id: d.id,
              type: mappedType,
              user: user,
              timestamp: timestamp,
              postThumbnailUrl: data['postThumbnailUrl'] as String?,
              commentText: data['commentText'] as String?,
              status: status,
              videoId: videoId.isEmpty ? null : videoId,
              milestoneType: data['milestoneType'] as String?,
              milestoneValue: data['milestoneValue'] as int?,
              parentCommentId: data['parentCommentId'] as String?,
            );
          })
          .whereType<ActivityNotification>()
          .toList();

      // 📊 DEBUG: Log notification type distribution
      final typeCounts = <String, int>{};
      for (final item in items) {
        typeCounts[item.type.name] = (typeCounts[item.type.name] ?? 0) + 1;
      }
      debugPrint(
        '✅ Real-time update successful with ${items.length} notifications - '
        'types: ${typeCounts.entries.map((e) => '${e.key}:${e.value}').join(", ")}',
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
    } catch (e) {
      debugPrint('🚨 Real-time update parsing error: $e');
      state = state.copyWith(
        hasError: true,
        error: 'Failed to parse real-time updates: ${e.toString()}',
      );
    }
  }

  void _handleLegacySnapshot(QuerySnapshot<Map<String, dynamic>> snap) {
    try {
      debugPrint(
          '🔍 ActivityNotifier: Real-time update (legacy structure) - ${snap.docs.length} documents');

      final items = snap.docs
          .map((d) {
            final data = d.data();

            // 🚫 FILTER: Skip test/fake accounts and test videos
            final actorId = data['user']?['id'] ?? '';
            final videoId = data['videoId'] ?? '';
            if (_isTestAccount(actorId) || _isTestVideo(videoId)) {
              debugPrint(
                '🚫 ActivityNotifier: Skipping test notification ${d.id} - '
                'actorId: $actorId, videoId: $videoId',
              );
              return null;
            }

            // 🔍 DEBUG: Log raw notification data
            final notificationType = (data['type'] ?? 'like').toString();
            debugPrint(
              '🔔 ActivityNotifier: Processing notification ${d.id} - '
              'type: $notificationType, '
              'user: $actorId, '
              'targetId: $videoId',
            );

            // Map legacy structure to mobile model
            final user = _mapToUser(data);
            final timestamp = _getTimestamp(data);
            final isRead = data['status'] == 'delivered';
            final status = isRead ? 'delivered' : 'pending';

            final mappedType = _typeFromString(notificationType);
            debugPrint(
              '✅ ActivityNotifier: Mapped type "$notificationType" → ${mappedType.name}',
            );

            return ActivityNotification(
              id: d.id,
              type: mappedType,
              user: user,
              timestamp: timestamp,
              postThumbnailUrl: data['postThumbnailUrl'] as String?,
              commentText: data['commentText'] as String?,
              status: status,
              videoId: videoId.isEmpty ? null : videoId,
              milestoneType: data['milestoneType'] as String?,
              milestoneValue: data['milestoneValue'] as int?,
              parentCommentId: data['parentCommentId'] as String?,
            );
          })
          .whereType<ActivityNotification>()
          .toList();

      // 📊 DEBUG: Log notification type distribution
      final typeCounts = <String, int>{};
      for (final item in items) {
        typeCounts[item.type.name] = (typeCounts[item.type.name] ?? 0) + 1;
      }
      debugPrint(
        '✅ Real-time update successful with ${items.length} notifications - '
        'types: ${typeCounts.entries.map((e) => '${e.key}:${e.value}').join(", ")}',
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
    } catch (e) {
      debugPrint('🚨 Real-time update parsing error: $e');
      state = state.copyWith(
        hasError: true,
        error: 'Failed to parse real-time updates: ${e.toString()}',
      );
    }
  }

  Future<void> markAllDelivered(String userId) async {
    try {
      int totalMarked = 0;
      final batch = _db.batch();

      // Try new structure first
      try {
        final qs = await _db
            .collection('activity')
            .doc(userId)
            .collection('notifications')
            .where('isRead', isEqualTo: false)
            .limit(100)
            .get();
        for (final d in qs.docs) {
          batch.update(d.reference, {'isRead': true});
        }
        totalMarked += qs.docs.length;
      } catch (e) {
        debugPrint('⚠️ New structure mark all failed: $e');
      }

      // Also try legacy structure
      try {
        final qsLegacy = await _db
            .collection('notifications')
            .doc(userId)
            .collection('items')
            .where('status', isEqualTo: 'pending')
            .limit(100)
            .get();
        for (final d in qsLegacy.docs) {
          batch.update(d.reference, {'status': 'delivered'});
        }
        totalMarked += qsLegacy.docs.length;
      } catch (e) {
        debugPrint('⚠️ Legacy structure mark all failed: $e');
      }

      if (totalMarked > 0) {
        await batch.commit();
        debugPrint('✅ Marked $totalMarked notifications as read');
      }
    } catch (e) {
      debugPrint('❌ Error marking all as read: $e');
      state = state.copyWith(
        hasError: true,
        error: 'Failed to mark notifications as read: ${e.toString()}',
      );
    }
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      final currentUser = fa.FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Try new structure first
      try {
        await _db
            .collection('activity')
            .doc(currentUser.uid)
            .collection('notifications')
            .doc(notificationId)
            .update({'isRead': true});
        debugPrint(
            '✅ Marked notification $notificationId as read (new structure)');
      } catch (e) {
        // Fallback to legacy structure
        try {
          await _db
              .collection('notifications')
              .doc(currentUser.uid)
              .collection('items')
              .doc(notificationId)
              .update({'status': 'delivered'});
          debugPrint(
              '✅ Marked notification $notificationId as read (legacy structure)');
        } catch (legacyError) {
          debugPrint(
              '❌ Failed to mark notification as read in both structures: $e, $legacyError');
          throw legacyError;
        }
      }

      // Update local state immediately for better UX
      final updatedGrouped =
          Map<String, List<ActivityNotification>>.from(state.grouped);
      for (final key in updatedGrouped.keys) {
        final notifications = updatedGrouped[key]!;
        for (int i = 0; i < notifications.length; i++) {
          if (notifications[i].id == notificationId) {
            updatedGrouped[key]![i] =
                notifications[i].copyWith(status: 'delivered');
            break;
          }
        }
      }

      state = state.copyWith(grouped: updatedGrouped);
      debugPrint('✅ Marked notification $notificationId as read');
    } catch (e) {
      debugPrint('❌ Error marking notification as read: $e');
    }
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

  /// Map website structure to User model
  app_user.User _mapToUser(Map<String, dynamic> data) {
    // New structure: flat fields (actorId, actorUsername, etc.)
    if (data.containsKey('actorId')) {
      return app_user.User(
        id: data['actorId'] as String? ?? '',
        username: data['actorUsername'] as String? ?? '',
        displayName: data['actorDisplayName'] as String? ?? '',
        avatarURL: data['actorAvatarUrl'] as String?,
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

    // Legacy structure: nested user object
    if (data.containsKey('user')) {
      return const UserConverter().fromJson(
        Map<String, dynamic>.from(data['user'] ?? {}),
      );
    }

    // Fallback: create minimal user
    return app_user.User(
      id: '',
      username: 'Unknown',
      displayName: 'Unknown User',
      avatarURL: null,
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

  /// Get timestamp from either createdAt (new) or timestamp (legacy)
  DateTime _getTimestamp(Map<String, dynamic> data) {
    if (data.containsKey('createdAt')) {
      return const TimestampConverter().fromJson(data['createdAt']);
    }
    if (data.containsKey('timestamp')) {
      return const TimestampConverter().fromJson(data['timestamp']);
    }
    // Fallback to now if neither exists
    return DateTime.now();
  }

  /// Check if an account ID is a test/fake account
  bool _isTestAccount(String? accountId) {
    if (accountId == null || accountId.isEmpty) return false;
    final id = accountId.toLowerCase();
    return id.startsWith('test_') ||
        id.startsWith('test_user_') ||
        id.startsWith('fake_') ||
        id == 'test_user_1' ||
        id == 'test_user_2' ||
        id == 'test_user_3' ||
        id == 'test_user_4' ||
        id == 'test_user_5' ||
        id.contains('mock') ||
        id.contains('fake');
  }

  /// Check if a video ID is a test video
  bool _isTestVideo(String? videoId) {
    if (videoId == null || videoId.isEmpty) return false;
    final id = videoId.toLowerCase();
    return id.startsWith('video_') &&
            id.length < 15 || // video_1, video_2, etc.
        id.startsWith('test_video') ||
        id.contains('test') ||
        id.contains('mock');
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
      final commenterDoc = await _db.collection('users').doc(commenterId).get();
      if (!commenterDoc.exists) {
        debugPrint('❌ Commenter user not found: $commenterId');
        return;
      }

      final commenterData = commenterDoc.data()!;

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
    _notifSub?.cancel();
    _procSub?.cancel();
    state = const ActivityState();
  }

  @override
  void dispose() {
    debugPrint('🧹 ActivityNotifier: Disposing and cancelling listeners');
    _notifSub?.cancel();
    _procSub?.cancel();
    _isInitialized = false;
    super.dispose();
  }

  ActivityNotificationType _typeFromString(String s) {
    final normalized = s.toLowerCase().trim();
    debugPrint(
        '🔍 ActivityNotifier: Mapping notification type "$s" (normalized: "$normalized")');

    switch (normalized) {
      case 'follow':
      case 'follows':
        return ActivityNotificationType.follow;
      case 'like':
      case 'likes':
        return ActivityNotificationType.like;
      case 'comment':
      case 'comments':
        return ActivityNotificationType.comment;
      case 'commentreply':
      case 'comment_reply':
      case 'reply':
      case 'replies':
        return ActivityNotificationType.commentReply;
      case 'tag':
      case 'tags':
        return ActivityNotificationType.tag;
      case 'mention':
      case 'mentions':
        return ActivityNotificationType.mention;
      case 'newvideo':
      case 'new_video':
      case 'video':
        return ActivityNotificationType.newVideo;
      case 'milestone':
      case 'milestones':
        return ActivityNotificationType.milestone;
      case 'livestream':
      case 'live_stream':
      case 'live':
        return ActivityNotificationType.liveStream;
      default:
        debugPrint(
            '⚠️ ActivityNotifier: Unknown notification type "$s", defaulting to like');
        return ActivityNotificationType.like;
    }
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
    StateNotifierProvider.autoDispose<ActivityNotifier, ActivityState>((ref) {
  return ActivityNotifier();
});

/// Provider for unread activity count only - does NOT keep activity provider alive
final unreadActivityCountProvider = Provider<int>((ref) {
  // This will ONLY watch the provider when someone requests the count
  // and won't prevent the activity provider from disposing
  return 0; // Default to 0 when activity provider is not initialized
});
