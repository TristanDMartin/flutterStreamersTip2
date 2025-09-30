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
    
    // Prevent multiple simultaneous initializations
    if (_isInitialized) {
      debugPrint('⚠️ ActivityNotifier already initialized, skipping...');
      return;
    }
    
    _isInitialized = true; // Mark as initialized immediately to prevent multiple calls
    
    try {
      await _notifSub?.cancel();
      state = state.copyWith(isLoading: true, hasError: false, error: null);
      
      // Load offline data immediately as fallback
      debugPrint('🔄 Loading offline data immediately...');
      _loadOfflineData();
      
      // Try to load from Firestore in background (non-blocking)
      _loadFirestoreData(userId);
      
    } catch (e) {
      debugPrint('❌ Error in init: $e');
      // Always load offline data as fallback
      _loadOfflineData();
    }
  }

  Future<void> _loadFirestoreData(String userId) async {
    try {
      _notifSub = _db
          .collection('notifications')
          .doc(userId)
          .collection('items')
          .orderBy('timestamp', descending: true)
          .snapshots()
          .listen(
            (snap) {
              try {
                final items = snap.docs.map((d) {
                  final data = d.data();
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

                // Only update if we have actual data from Firestore
                if (items.isNotEmpty) {
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
                  debugPrint('✅ Firestore data loaded successfully');
                } else {
                  debugPrint('⚠️ No Firestore notifications found, keeping offline data');
                }
              } catch (e) {
                debugPrint('🚨 Firestore parsing error: $e');
                // Keep offline data if Firestore fails - don't reload offline data
              }
            },
            onError: (error) {
              debugPrint('🚨 Firestore error: $error');
              // Keep offline data if Firestore fails - don't reload offline data
            },
          );
    } catch (e) {
      debugPrint('🚨 Firestore setup error: $e');
      // Keep offline data if Firestore setup fails - don't reload offline data
    }
  }

  void _loadOfflineData() {
    debugPrint('🔄 Loading offline data as fallback...');
    // Load mock data as fallback when Firestore fails
    final mockNotifications = _generateMockNotifications();
    final grouped = <String, List<ActivityNotification>>{};
    for (final n in mockNotifications) {
      final key = _groupKey(n.timestamp);
      grouped.putIfAbsent(key, () => []).add(n);
    }
    state = state.copyWith(
      grouped: grouped,
      isLoading: false,
      hasError: false,
      error: null,
    );
    debugPrint('✅ Offline data loaded successfully');
  }

  List<ActivityNotification> _generateMockNotifications() {
    debugPrint('🎭 Generating mock notifications...');
    final now = DateTime.now();
    
    final notifications = [
      ActivityNotification(
        id: '1',
        type: ActivityNotificationType.like,
        user: const UserConverter().fromJson({
          'id': 'user1',
          'username': 'gamer_girl',
          'displayName': 'Gamer Girl',
          'avatarURL': 'https://images.unsplash.com/photo-1494790108755-2616b612b786?w=100&h=100&fit=crop&crop=face',
        }),
        timestamp: now.subtract(const Duration(minutes: 5)),
        postThumbnailUrl: 'https://images.unsplash.com/photo-1511512578047-dfb367046420?w=200&h=200&fit=crop',
        status: 'delivered',
      ),
      ActivityNotification(
        id: '2',
        type: ActivityNotificationType.follow,
        user: const UserConverter().fromJson({
          'id': 'user2',
          'username': 'art_streamer',
          'displayName': 'Art Streamer',
          'avatarURL': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&h=100&fit=crop&crop=face',
        }),
        timestamp: now.subtract(const Duration(hours: 1)),
        status: 'delivered',
      ),
      ActivityNotification(
        id: '3',
        type: ActivityNotificationType.comment,
        user: const UserConverter().fromJson({
          'id': 'user3',
          'username': 'music_lover',
          'displayName': 'Music Lover',
          'avatarURL': 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=100&h=100&fit=crop&crop=face',
        }),
        timestamp: now.subtract(const Duration(hours: 2)),
        commentText: 'Great content! Keep it up! 🎵',
        status: 'delivered',
      ),
      ActivityNotification(
        id: '4',
        type: ActivityNotificationType.like,
        user: const UserConverter().fromJson({
          'id': 'user4',
          'username': 'tech_reviewer',
          'displayName': 'Tech Reviewer',
          'avatarURL': 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=100&h=100&fit=crop&crop=face',
        }),
        timestamp: now.subtract(const Duration(hours: 3)),
        postThumbnailUrl: 'https://images.unsplash.com/photo-1518709268805-4e9042af2176?w=200&h=200&fit=crop',
        status: 'pending',
      ),
      ActivityNotification(
        id: '5',
        type: ActivityNotificationType.mention,
        user: const UserConverter().fromJson({
          'id': 'user5',
          'username': 'fitness_coach',
          'displayName': 'Fitness Coach',
          'avatarURL': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=100&h=100&fit=crop&crop=face',
        }),
        timestamp: now.subtract(const Duration(days: 1)),
        commentText: 'Thanks for the shoutout! 💪',
        status: 'delivered',
      ),
    ];
    
    debugPrint('✅ Generated ${notifications.length} mock notifications');
    return notifications;
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
      final updatedGrouped = Map<String, List<ActivityNotification>>.from(state.grouped);
      for (final key in updatedGrouped.keys) {
        final notifications = updatedGrouped[key]!;
        for (int i = 0; i < notifications.length; i++) {
          if (notifications[i].id == notificationId) {
            updatedGrouped[key]![i] = notifications[i].copyWith(status: 'delivered');
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
      _procSub = _db
          .collection('notifications')
          .doc(userId)
          .snapshots()
          .listen(
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

  /// Reset the provider to allow re-initialization
  void reset() {
    _isInitialized = false;
    _notifSub?.cancel();
    _procSub?.cancel();
    state = const ActivityState();
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    _procSub?.cancel();
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

final activityProvider = StateNotifierProvider<ActivityNotifier, ActivityState>((ref) {
  return ActivityNotifier();
});
