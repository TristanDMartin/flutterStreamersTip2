import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_status.dart';

// Provider for current user's status (read-only stream)
final currentUserStatusProvider = StreamProvider<UserPresence>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    // print('❌ StatusProvider: No authenticated user');
    return Stream.value(const UserPresence(
      status: UserStatus.offline,
      lastSeen: null,
    ));
  }

  // print('✅ StatusProvider: Listening to status for user ${user.uid}');

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('presence')
      .doc('status')
      .snapshots()
      .map((snapshot) {
    // print('📊 StatusProvider: Snapshot received - exists: ${snapshot.exists}');

    if (!snapshot.exists) {
      // print('⚠️ StatusProvider: Status document does not exist, returning offline');
      return const UserPresence(
        status: UserStatus.offline,
        lastSeen: null,
      );
    }

    try {
      final presence = UserPresence.fromMap(snapshot.data()!);
      // print('✅ StatusProvider: Status loaded - ${presence.status.value}');
      return presence;
    } catch (e) {
      // print('❌ StatusProvider: Error parsing status data: $e');
      return const UserPresence(
        status: UserStatus.offline,
        lastSeen: null,
      );
    }
  }).handleError((error) {
    // print('❌ StatusProvider: Stream error: $error');
    return const UserPresence(
      status: UserStatus.offline,
      lastSeen: null,
    );
  });
});

// Provider for any user's status by UID
// ✅ DUAL LISTENING: Listens to BOTH website and app status locations
final userStatusProvider =
    StreamProvider.family<UserPresence, String>((ref, userId) {
  // print('✅ UserStatusProvider: Listening to status for user $userId');

  final firestore = FirebaseFirestore.instance;

  // Create streams for both locations
  final mainDocStream =
      firestore.collection('users').doc(userId).snapshots().map((snapshot) {
    if (snapshot.exists && snapshot.data() != null) {
      final data = snapshot.data()!;
      final statusValue = data['status'] as String? ??
          data['userStatus'] as String? ??
          data['onlineStatus'] as String?;
      if (statusValue != null) {
        try {
          final status = UserStatus.fromString(statusValue);
          final lastSeen = data['lastSeen'] as Timestamp?;
          return UserPresence(
            status: status,
            lastSeen: lastSeen?.toDate(),
            lastActive: lastSeen?.toDate(),
          );
        } catch (e) {
          return const UserPresence(
            status: UserStatus.offline,
            lastSeen: null,
          );
        }
      }
    }
    return const UserPresence(
      status: UserStatus.offline,
      lastSeen: null,
    );
  });

  final presenceStream = firestore
      .collection('users')
      .doc(userId)
      .collection('presence')
      .doc('status')
      .snapshots()
      .map((snapshot) {
    if (!snapshot.exists) {
      return const UserPresence(
        status: UserStatus.offline,
        lastSeen: null,
      );
    }

    try {
      final presence = UserPresence.fromMap(snapshot.data()!);
      return presence;
    } catch (e) {
      return const UserPresence(
        status: UserStatus.offline,
        lastSeen: null,
      );
    }
  });

  // Merge both streams using StreamController
  final controller = StreamController<UserPresence>();

  mainDocStream.listen(
    (presence) => controller.add(presence),
    onError: (error) => controller.addError(error),
  );

  presenceStream.listen(
    (presence) => controller.add(presence),
    onError: (error) => controller.addError(error),
  );

  return controller.stream
      .distinct((a, b) => a.status == b.status)
      .handleError((error) {
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

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userDocSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _presenceSub;

  void _initializeStatus() {
    final user = _auth.currentUser;
    if (user == null) {
      // print('❌ StatusNotifier: No authenticated user');
      state = const AsyncValue.data(UserPresence(
        status: UserStatus.offline,
        lastSeen: null,
      ));
      return;
    }

    // print('✅ StatusNotifier: Initializing status for user ${user.uid}');

    _userDocSub?.cancel();
    _presenceSub?.cancel();

    // LOCATION 1: Listen to main user document (where website writes)
    _userDocSub = _firestore.collection('users').doc(user.uid).snapshots().listen(
      (snapshot) {
        if (snapshot.exists && snapshot.data() != null) {
          final data = snapshot.data()!;
          final statusValue = data['status'] as String? ??
              data['userStatus'] as String? ??
              data['onlineStatus'] as String?;
          if (statusValue != null) {
            try {
              final status = UserStatus.fromString(statusValue);
              final lastSeen = data['lastSeen'] as Timestamp?;
              final presence = UserPresence(
                status: status,
                lastSeen: lastSeen?.toDate(),
                lastActive: lastSeen?.toDate(),
              );
              log('🌐 Website → App: Status updated to ${status.value}');
              state = AsyncValue.data(presence);
            } catch (e) {
              // print('❌ Error parsing status from main document: $e');
            }
          }
        }
      },
    );

    // LOCATION 2: Listen to presence subcollection (where app writes)
    _presenceSub = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('presence')
        .doc('status')
        .snapshots()
        .listen(
      (snapshot) {
        // print('📊 StatusNotifier: Snapshot received - exists: ${snapshot.exists}');

        if (!snapshot.exists) {
          // print('⚠️ StatusNotifier: Status document does not exist, initializing as online');
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
          log('📱 App: Status updated to ${presence.status.value}');
          state = AsyncValue.data(presence);
        } catch (e) {
          // print('❌ StatusNotifier: Error parsing status data: $e');
          state = AsyncValue.error(e, StackTrace.current);
        }
      },
      onError: (error) {
        // print('❌ StatusNotifier: Stream error: $error');
        state = AsyncValue.error(error, StackTrace.current);
      },
    );
  }

  // Initialize user status if it doesn't exist
  // Writes to THREE locations for perfect website/app sync
  Future<void> _initializeUserStatus(String userId) async {
    try {
      // ✅ LOCATION 1: Initialize in presence subcollection (mobile app)
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

      // ✅ LOCATION 2: Initialize in main user document (website + comments)
      await _firestore.collection('users').doc(userId).update({
        'status': UserStatus.online.value,
        'userStatus': UserStatus.online.value,
        'isOnline': true,
        'onlineStatus': UserStatus.online.value,
        'lastSeen': FieldValue.serverTimestamp(),
      });

      // ✅ LOCATION 3: Initialize in status subcollection (alternative location)
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('status')
          .doc('current')
          .set({
        'value': UserStatus.online.value,
        'source': 'app',
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // print('✅ StatusNotifier: Initialized status for user $userId in all locations');
    } catch (e) {
      // print('❌ StatusNotifier: Error initializing status: $e');
    }
  }

  // Update user status with optimistic updates
  // Writes to THREE locations for perfect website/app sync:
  // 1. users/{uid}/presence/status (mobile app)
  // 2. users/{uid}.status (website + comments)
  // 3. users/{uid}/status/current (alternative location)
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
      // ✅ LOCATION 1: Update in presence subcollection (mobile app)
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

      // ✅ LOCATION 2: Update in main user document (website + comments compatibility)
      await _firestore.collection('users').doc(user.uid).update({
        'status': newStatus.value,
        'userStatus': newStatus.value,
        'isOnline': newStatus == UserStatus.online,
        'onlineStatus': newStatus.value,
        'lastSeen': FieldValue.serverTimestamp(),
      });

      // ✅ LOCATION 3: Update in status subcollection (alternative location for website)
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('status')
          .doc('current')
          .set({
        'value': newStatus.value,
        'source': 'app',
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // print('✅ Status updated to ${newStatus.value} in all locations');
    } catch (error) {
      // Revert optimistic update on error
      _initializeStatus();
      // print('❌ Error updating status: $error');
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

  // Emergency offline update (called on app termination)
  // Writes directly without optimistic updates
  Future<void> setOfflineImmediate() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Write to all three locations immediately
      await Future.wait([
        // Location 1: Presence subcollection
        _firestore
            .collection('users')
            .doc(user.uid)
            .collection('presence')
            .doc('status')
            .update({
          'status': UserStatus.offline.value,
          'lastSeen': FieldValue.serverTimestamp(),
        }),

        // Location 2: Main user document
        _firestore.collection('users').doc(user.uid).update({
          'status': UserStatus.offline.value,
          'userStatus': UserStatus.offline.value,
          'isOnline': false,
          'onlineStatus': UserStatus.offline.value,
          'lastSeen': FieldValue.serverTimestamp(),
        }),

        // Location 3: Status subcollection
        _firestore
            .collection('users')
            .doc(user.uid)
            .collection('status')
            .doc('current')
            .set({
          'value': UserStatus.offline.value,
          'source': 'app',
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)),
      ]);
    } catch (error) {
      // print('❌ Error setting offline: $error');
    }
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
      // print('❌ Error updating last active: $error');
    }
  }

  @override
  void dispose() {
    _userDocSub?.cancel();
    _presenceSub?.cancel();
    super.dispose();
  }
}

// Provider for the status notifier
final statusNotifierProvider =
    StateNotifierProvider<StatusNotifier, AsyncValue<UserPresence>>((ref) {
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
