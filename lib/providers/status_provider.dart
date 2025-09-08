import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_status.dart';

// Provider for current user's status (read-only stream)
final currentUserStatusProvider = StreamProvider<UserPresence>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    print('❌ StatusProvider: No authenticated user');
    return Stream.value(const UserPresence(
      status: UserStatus.offline,
      lastSeen: null,
    ));
  }

  print('✅ StatusProvider: Listening to status for user ${user.uid}');

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('presence')
      .doc('status')
      .snapshots()
      .map((snapshot) {
    print('📊 StatusProvider: Snapshot received - exists: ${snapshot.exists}');
    
    if (!snapshot.exists) {
      print('⚠️ StatusProvider: Status document does not exist, returning offline');
      return const UserPresence(
        status: UserStatus.offline,
        lastSeen: null,
      );
    }
    
    try {
      final presence = UserPresence.fromMap(snapshot.data()!);
      print('✅ StatusProvider: Status loaded - ${presence.status.value}');
      return presence;
    } catch (e) {
      print('❌ StatusProvider: Error parsing status data: $e');
      return const UserPresence(
        status: UserStatus.offline,
        lastSeen: null,
      );
    }
  }).handleError((error) {
    print('❌ StatusProvider: Stream error: $error');
    return const UserPresence(
      status: UserStatus.offline,
      lastSeen: null,
    );
  });
});

// Provider for any user's status by UID
final userStatusProvider = StreamProvider.family<UserPresence, String>((ref, userId) {
  print('✅ UserStatusProvider: Listening to status for user $userId');
  
  return FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('presence')
      .doc('status')
      .snapshots()
      .map((snapshot) {
    print('📊 UserStatusProvider: Snapshot received for $userId - exists: ${snapshot.exists}');
    
    if (!snapshot.exists) {
      print('⚠️ UserStatusProvider: Status document does not exist for $userId, returning offline');
      return const UserPresence(
        status: UserStatus.offline,
        lastSeen: null,
      );
    }
    
    try {
      final presence = UserPresence.fromMap(snapshot.data()!);
      print('✅ UserStatusProvider: Status loaded for $userId - ${presence.status.value}');
      return presence;
    } catch (e) {
      print('❌ UserStatusProvider: Error parsing status data for $userId: $e');
      return const UserPresence(
        status: UserStatus.offline,
        lastSeen: null,
      );
    }
  }).handleError((error) {
    print('❌ UserStatusProvider: Stream error for $userId: $error');
    return const UserPresence(
      status: UserStatus.offline,
      lastSeen: null,
    );
  });
});

// Notifier to update status (write operations)
class StatusNotifier extends StateNotifier<AsyncValue<UserPresence>> {
  StatusNotifier() : super(const AsyncValue.loading()) {
    _initializeStatus();
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  void _initializeStatus() {
    final user = _auth.currentUser;
    if (user == null) {
      print('❌ StatusNotifier: No authenticated user');
      state = const AsyncValue.data(UserPresence(
        status: UserStatus.offline,
        lastSeen: null,
      ));
      return;
    }

    print('✅ StatusNotifier: Initializing status for user ${user.uid}');

    // Listen to current user's status
    _firestore
        .collection('users')
        .doc(user.uid)
        .collection('presence')
        .doc('status')
        .snapshots()
        .listen(
      (snapshot) {
        print('📊 StatusNotifier: Snapshot received - exists: ${snapshot.exists}');
        
        if (!snapshot.exists) {
          print('⚠️ StatusNotifier: Status document does not exist, initializing as online');
          // Initialize status as online if it doesn't exist
          _initializeUserStatus(user.uid);
          state = const AsyncValue.data(UserPresence(
            status: UserStatus.online,
            lastSeen: null,
          ));
          return;
        }
        
        try {
          final presence = UserPresence.fromMap(snapshot.data()!);
          print('✅ StatusNotifier: Status loaded - ${presence.status.value}');
          state = AsyncValue.data(presence);
        } catch (e) {
          print('❌ StatusNotifier: Error parsing status data: $e');
          state = AsyncValue.error(e, StackTrace.current);
        }
      },
      onError: (error) {
        print('❌ StatusNotifier: Stream error: $error');
        state = AsyncValue.error(error, StackTrace.current);
      },
    );
  }

  // Initialize user status if it doesn't exist
  Future<void> _initializeUserStatus(String userId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('presence')
          .doc('status')
          .set({
        'status': UserStatus.online.value,
        'lastSeen': FieldValue.serverTimestamp(),
        'lastActive': FieldValue.serverTimestamp(),
      });
      print('✅ StatusNotifier: Initialized status for user $userId');
    } catch (e) {
      print('❌ StatusNotifier: Error initializing status: $e');
    }
  }

  // Update user status with optimistic updates
  Future<void> updateStatus(UserStatus newStatus) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Optimistic update
    final currentPresence = state.valueOrNull;
    if (currentPresence != null) {
      final optimisticPresence = currentPresence.copyWith(
        status: newStatus,
        lastSeen: DateTime.now(),
        lastActive: DateTime.now(),
      );
      state = AsyncValue.data(optimisticPresence);
    }

    try {
      // Update in Firestore
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('presence')
          .doc('status')
          .set({
        'status': newStatus.value,
        'lastSeen': FieldValue.serverTimestamp(),
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('✅ Status updated to ${newStatus.value}');
    } catch (error) {
      // Revert optimistic update on error
      _initializeStatus();
      print('❌ Error updating status: $error');
      rethrow;
    }
  }

  // Set user as online (called on app start/login)
  Future<void> setOnline() async {
    await updateStatus(UserStatus.online);
  }

  // Set user as offline (called on app close/logout)
  Future<void> setOffline() async {
    await updateStatus(UserStatus.offline);
  }

  // Update last active timestamp
  Future<void> updateLastActive() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('presence')
          .doc('status')
          .update({
        'lastActive': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      print('❌ Error updating last active: $error');
    }
  }
}

// Provider for the status notifier
final statusNotifierProvider = StateNotifierProvider<StatusNotifier, AsyncValue<UserPresence>>((ref) {
  return StatusNotifier();
});

// Provider for current user's status (using the notifier)
final currentUserStatusNotifierProvider = Provider<UserPresence?>((ref) {
  final statusAsync = ref.watch(statusNotifierProvider);
  return statusAsync.valueOrNull;
});

// Provider for status update function
final updateStatusProvider = Provider<Future<void> Function(UserStatus)>((ref) {
  final notifier = ref.read(statusNotifierProvider.notifier);
  return notifier.updateStatus;
});
