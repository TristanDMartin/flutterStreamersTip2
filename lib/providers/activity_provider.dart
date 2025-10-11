import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import '../models/activity_notification.dart';
import '../models/json_converters.dart';

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
      debugPrint('🔍 ActivityNotifier: Path: notifications/$userId/items');

      // First, try to get initial data
      try {
        final initialSnapshot = await _db
            .collection('notifications')
            .doc(userId)
            .collection('items')
            .orderBy('timestamp', descending: true)
            .get();

        debugPrint(
            '🔍 ActivityNotifier: Initial load - ${initialSnapshot.docs.length} documents');

        if (initialSnapshot.docs.isNotEmpty) {
          final items = initialSnapshot.docs.map((d) {
            final data = d.data();
            debugPrint(
                '🔍 ActivityNotifier: Processing document ${d.id}: $data');

            return ActivityNotification(
              id: d.id,
              type: _typeFromString((data['type'] ?? 'like').toString()),
              user: const UserConverter().fromJson(
                Map<String, dynamic>.from(data['user'] ?? {}),
              ),
              timestamp: const TimestampConverter().fromJson(data['timestamp']),
              postThumbnailUrl: data['postThumbnailUrl'] as String?,
              commentText: data['commentText'] as String?,
              status: (data['status'] ?? 'pending').toString(),
              videoId: data['videoId'] as String?,
            );
          }).toList();

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

      // Then set up real-time listener
      _notifSub = _db
          .collection('notifications')
          .doc(userId)
          .collection('items')
          .orderBy('timestamp', descending: true)
          .snapshots()
          .listen(
        (snap) {
          try {
            debugPrint(
                '🔍 ActivityNotifier: Real-time update - ${snap.docs.length} documents');

            final items = snap.docs.map((d) {
              final data = d.data();
              return ActivityNotification(
                id: d.id,
                type: _typeFromString((data['type'] ?? 'like').toString()),
                user: const UserConverter().fromJson(
                  Map<String, dynamic>.from(data['user'] ?? {}),
                ),
                timestamp:
                    const TimestampConverter().fromJson(data['timestamp']),
                postThumbnailUrl: data['postThumbnailUrl'] as String?,
                commentText: data['commentText'] as String?,
                status: (data['status'] ?? 'pending').toString(),
                videoId: data['videoId'] as String?,
              );
            }).toList();

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
                '✅ Real-time update successful with ${items.length} notifications');
          } catch (e) {
            debugPrint('🚨 Real-time update parsing error: $e');
            state = state.copyWith(
              hasError: true,
              error: 'Failed to parse real-time updates: ${e.toString()}',
            );
          }
        },
        onError: (error) {
          debugPrint('🚨 Real-time listener error: $error');
          state = state.copyWith(
            hasError: true,
            error: 'Real-time updates failed: ${error.toString()}',
          );
        },
      );
    } catch (e) {
      debugPrint('🚨 Firestore setup error: $e');
      state = state.copyWith(
        isLoading: false,
        hasError: true,
        error: 'Failed to setup notifications: ${e.toString()}',
      );
    }
  }

  Future<void> markAllDelivered(String userId) async {
    try {
      final qs = await _db
          .collection('notifications')
          .doc(userId)
          .collection('items')
          .where('status', isEqualTo: 'pending')
          .get();
      final batch = _db.batch();
      for (final d in qs.docs) {
        batch.update(d.reference, {'status': 'delivered'});
      }
      await batch.commit();
    } catch (e) {
      state = state.copyWith(
        hasError: true,
        error: 'Failed to mark notifications as read: ${e.toString()}',
      );
    }
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Update in Firestore
      await _db
          .collection('notifications')
          .doc(currentUser.uid)
          .collection('items')
          .doc(notificationId)
          .update({'status': 'delivered'});

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
        if (notification.status == 'pending') {
          count++;
        }
      }
    }
    return count;
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
      final currentUser = FirebaseAuth.instance.currentUser;
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
    switch (s) {
      case 'follow':
        return ActivityNotificationType.follow;
      case 'comment':
        return ActivityNotificationType.comment;
      case 'tag':
        return ActivityNotificationType.tag;
      case 'mention':
        return ActivityNotificationType.mention;
      default:
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
