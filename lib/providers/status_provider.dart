import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streamers_tip/utils/secure_log.dart';

import '../core/firebase_app_check_startup.dart';
import '../models/user_status.dart';

// Provider for current user's status (read-only stream)
final currentUserStatusProvider = StreamProvider<UserPresence>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    // appLog('❌ StatusProvider: No authenticated user');
    return Stream.value(const UserPresence(
      status: UserStatus.offline,
      lastSeen: null,
    ));
  }

  // appLog('✅ StatusProvider: Listening to status for user ${user.uid}');

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('presence')
      .doc('status')
      .snapshots()
      .map((snapshot) {
    // appLog('📊 StatusProvider: Snapshot received - exists: ${snapshot.exists}');

    if (!snapshot.exists) {
      // appLog('⚠️ StatusProvider: Status document does not exist, returning offline');
      return const UserPresence(
        status: UserStatus.offline,
        lastSeen: null,
      );
    }

    try {
      final presence = UserPresence.fromMap(snapshot.data()!);
      // appLog('✅ StatusProvider: Status loaded - ${presence.status.value}');
      return presence;
    } catch (e) {
      // appLog('❌ StatusProvider: Error parsing status data: $e');
      return const UserPresence(
        status: UserStatus.offline,
        lastSeen: null,
      );
    }
  }).handleError((error) {
    // appLog('❌ StatusProvider: Stream error: $error');
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
  // appLog('✅ UserStatusProvider: Listening to status for user $userId');

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
  Timer? _retryTimer;
  UserStatus? _pendingSyncStatus;
  int _retryAttempt = 0;
  static const int _maxRetryAttempts = 5;

  void _applyPresenceState(UserPresence presence, {required String source}) {
    final UserPresence? current = state.valueOrNull;
    if (current != null && current.status == presence.status) {
      return;
    }
    secureLog('$source: Status updated to ${presence.status.value}');
    state = AsyncValue.data(presence);
  }

  void _initializeStatus() {
    final user = _auth.currentUser;
    if (user == null) {
      // appLog('❌ StatusNotifier: No authenticated user');
      state = const AsyncValue.data(UserPresence(
        status: UserStatus.offline,
        lastSeen: null,
      ));
      return;
    }

    // appLog('✅ StatusNotifier: Initializing status for user ${user.uid}');

    _userDocSub?.cancel();
    _presenceSub?.cancel();

    // LOCATION 1: Listen to main user document (where website writes)
    _userDocSub =
        _firestore.collection('users').doc(user.uid).snapshots().listen(
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
              _applyPresenceState(
                presence,
                source: '🌐 Website → App',
              );
            } catch (e) {
              // appLog('❌ Error parsing status from main document: $e');
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
        // appLog('📊 StatusNotifier: Snapshot received - exists: ${snapshot.exists}');

        if (!snapshot.exists) {
          // appLog('⚠️ StatusNotifier: Status document does not exist, initializing as online');
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
          _applyPresenceState(presence, source: '📱 App');
        } catch (e) {
          secureLog('STATUS_UPDATE_FAILED parse_presence error=$e');
        }
      },
      onError: (Object error) {
        _logStatusFailure('presence_stream', error);
      },
    );
  }

  void _logStatusFailure(String phase, Object error) {
    final String message = error.toString();
    if (_isAppCheckRelated(message)) {
      debugPrint('STATUS_APP_CHECK_ERROR phase=$phase error=$message');
    }
    debugPrint('STATUS_UPDATE_FAILED phase=$phase error=$message');
  }

  bool _isAppCheckRelated(String message) {
    final String lower = message.toLowerCase();
    return lower.contains('app check') ||
        lower.contains('appcheck') ||
        lower.contains('placeholder token') ||
        lower.contains('too many attempts');
  }

  void _applyOptimisticStatus(UserStatus newStatus) {
    final UserPresence? currentPresence = state.valueOrNull;
    if (currentPresence == null) {
      state = AsyncValue.data(
        UserPresence(
          status: newStatus,
          lastSeen: DateTime.now(),
          lastActive: DateTime.now(),
        ),
      );
      return;
    }
    state = AsyncValue.data(
      currentPresence.copyWith(
        status: newStatus,
        lastSeen: DateTime.now(),
        lastActive: DateTime.now(),
      ),
    );
  }

  void _scheduleRetry(UserStatus status) {
    if (_retryAttempt >= _maxRetryAttempts) {
      debugPrint(
        'STATUS_UPDATE_FAILED phase=retry_exhausted status=${status.value}',
      );
      return;
    }
    _pendingSyncStatus = status;
    _retryTimer?.cancel();
    final int seconds = math.min(30, math.pow(2, _retryAttempt).toInt());
    _retryTimer = Timer(Duration(seconds: seconds), () {
      final UserStatus? pending = _pendingSyncStatus;
      if (pending == null) {
        return;
      }
      unawaited(_syncStatusToFirestore(pending, isRetry: true));
    });
  }

  Future<void> _preflightAppCheck() async {
    final AppCheckReadiness readiness =
        await ensureAppCheckReadyForFirestore();
    if (!readiness.isReady) {
      debugPrint('STATUS_APP_CHECK_ERROR detail=${readiness.detail}');
    }
  }

  Future<StatusUpdateOutcome> _syncStatusToFirestore(
    UserStatus newStatus, {
    bool isRetry = false,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      return StatusUpdateOutcome.failed(
        userMessage: 'Status could not sync. Try again.',
      );
    }
    if (!UserStatus.isValidFirestoreValue(newStatus.value)) {
      debugPrint(
        'STATUS_UPDATE_FAILED phase=invalid_value value=${newStatus.value}',
      );
      return StatusUpdateOutcome.failed(
        userMessage: 'Status could not sync. Try again.',
      );
    }
    debugPrint(
      'STATUS_UPDATE_START status=${newStatus.value} '
      'retry=$isRetry attempt=$_retryAttempt',
    );
    await _preflightAppCheck();
    try {
      final String statusValue = newStatus.value;
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('presence')
          .doc('status')
          .set(
        <String, dynamic>{
          'status': statusValue,
          'lastSeen': FieldValue.serverTimestamp(),
          'lastActive': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      await _firestore.collection('users').doc(user.uid).update(
        <String, dynamic>{
          'status': statusValue,
          'userStatus': statusValue,
          'isOnline': newStatus == UserStatus.online,
          'onlineStatus': statusValue,
          'lastSeen': FieldValue.serverTimestamp(),
        },
      );
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('status')
          .doc('current')
          .set(
        <String, dynamic>{
          'value': statusValue,
          'source': 'app',
          'updated_at': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      _pendingSyncStatus = null;
      _retryAttempt = 0;
      _retryTimer?.cancel();
      debugPrint('STATUS_UPDATE_SUCCESS status=$statusValue');
      return StatusUpdateOutcome.ok;
    } on PlatformException catch (e) {
      debugPrint(
        'STATUS_PLATFORM_EXCEPTION code=${e.code} message=${e.message}',
      );
      _logStatusFailure('platform_exception', e);
      _retryAttempt++;
      _scheduleRetry(newStatus);
      return StatusUpdateOutcome.failed(
        userMessage: 'Status could not sync. Try again.',
        pendingRetry: _retryAttempt < _maxRetryAttempts,
      );
    } catch (e, stack) {
      _logStatusFailure('sync', e);
      debugPrint('STATUS_UPDATE_FAILED stack=$stack');
      _retryAttempt++;
      _scheduleRetry(newStatus);
      return StatusUpdateOutcome.failed(
        userMessage: 'Status could not sync. Try again.',
        pendingRetry: _retryAttempt < _maxRetryAttempts,
      );
    }
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

      // appLog('✅ StatusNotifier: Initialized status for user $userId in all locations');
    } catch (e) {
      // appLog('❌ StatusNotifier: Error initializing status: $e');
    }
  }

  // Update user status with optimistic updates
  // Writes to THREE locations for perfect website/app sync:
  // 1. users/{uid}/presence/status (mobile app)
  // 2. users/{uid}.status (website + comments)
  // 3. users/{uid}/status/current (alternative location)
  Future<StatusUpdateOutcome> updateStatus(UserStatus newStatus) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      return StatusUpdateOutcome.failed(
        userMessage: 'Status could not sync. Try again.',
      );
    }
    final UserPresence? currentPresence = state.valueOrNull;
    if (currentPresence?.status == newStatus && _pendingSyncStatus == null) {
      return StatusUpdateOutcome.ok;
    }
    _applyOptimisticStatus(newStatus);
    return _syncStatusToFirestore(newStatus);
  }

  Future<StatusUpdateOutcome> setOnline() async {
    return updateStatus(UserStatus.online);
  }

  Future<StatusUpdateOutcome> setOffline() async {
    return updateStatus(UserStatus.offline);
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
      // appLog('❌ Error setting offline: $error');
    }
  }

  // Update last active timestamp
  Future<void> updateLastActive() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final UserPresence? currentPresence = state.valueOrNull;
    if (currentPresence?.status != UserStatus.online) {
      return;
    }

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
      // appLog('❌ Error updating last active: $error');
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
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
final updateStatusProvider =
    Provider<Future<StatusUpdateOutcome> Function(UserStatus)>((ref) {
  final StatusNotifier notifier = ref.read(statusNotifierProvider.notifier);
  return notifier.updateStatus;
});
