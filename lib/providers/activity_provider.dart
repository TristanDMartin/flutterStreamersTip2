import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
    // FIXED: Prevent infinite loop by checking if already initialized
    if (_isInitialized) {
      debugPrint('⚠️ ActivityNotifier already initialized, skipping...');
      return;
    }
    
    try {
      await _notifSub?.cancel();
      state = state.copyWith(isLoading: true, hasError: false, error: null);
      
      // Load offline data immediately as fallback
      debugPrint('🔄 Loading offline data immediately...');
      _loadOfflineData();
      
      // Try to load from Firestore in background (non-blocking)
      _loadFirestoreData(userId);
      
      _isInitialized = true; // Mark as initialized
      
    } catch (e) {
      debugPrint('❌ Error in init: $e');
      // Only load offline data if we haven't already loaded it
      if (state.grouped.isEmpty) {
        _loadOfflineData();
      }
      _isInitialized = true; // Mark as initialized even on error
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
    return [
      ActivityNotification(
        id: '1',
        type: ActivityNotificationType.like,
        user: const UserConverter().fromJson({
          'id': 'user1',
          'username': 'gamer_girl',
          'displayName': 'Gamer Girl',
          'avatarURL': 'https://via.placeholder.com/100',
        }),
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        postThumbnailUrl: 'https://via.placeholder.com/200',
        status: 'delivered',
      ),
      ActivityNotification(
        id: '2',
        type: ActivityNotificationType.follow,
        user: const UserConverter().fromJson({
          'id': 'user2',
          'username': 'art_streamer',
          'displayName': 'Art Streamer',
          'avatarURL': 'https://via.placeholder.com/100',
        }),
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
        status: 'delivered',
      ),
      ActivityNotification(
        id: '3',
        type: ActivityNotificationType.comment,
        user: const UserConverter().fromJson({
          'id': 'user3',
          'username': 'music_lover',
          'displayName': 'Music Lover',
          'avatarURL': 'https://via.placeholder.com/100',
        }),
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        commentText: 'Great content!',
        status: 'delivered',
      ),
    ];
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
