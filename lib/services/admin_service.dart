import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Firestore role / `admin.isAdmin` drives **UI** (shield). Custom claim
/// `admin` drives **rules + Cloud Functions**.
class AdminService {
  static final AdminService instance = AdminService._internal();
  factory AdminService() => instance;
  AdminService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // REMOVED: Client-side admin allowlist (security risk).
  // Admin access now determined solely by server-controlled Firestore fields:
  // - isAdmin, role='admin', or (adminAccess=true + adminStatus='active')
  // - Custom claims verified by Firebase rules
  // - Never trust client-side allowlists in production

  static const Duration adminRemoteResolveTimeout = Duration(seconds: 1);

  static String _readUsername(Map<String, dynamic>? userData) {
    return (userData?['username'] ?? '').toString().toLowerCase().trim();
  }

  static bool _readIsAdmin(Map<String, dynamic>? userData) {
    if (userData?['isAdmin'] == true) {
      return true;
    }
    final Object? adminMap = userData?['admin'];
    if (adminMap is Map && adminMap['isAdmin'] == true) {
      return true;
    }
    return false;
  }

  static String? _readRole(Map<String, dynamic>? userData) {
    final Object? role = userData?['role'];
    if (role == null) {
      return null;
    }
    return role.toString();
  }

  static bool _readAdminAccess(Map<String, dynamic>? userData) {
    return userData?['adminAccess'] == true;
  }

  static String? _readAdminStatus(Map<String, dynamic>? userData) {
    final Object? status = userData?['adminStatus'];
    if (status == null) {
      return null;
    }
    return status.toString().toLowerCase().trim();
  }

  /// Logs field snapshot and returns whether admin is granted from [userData].
  static bool userDocGrantsAdminAccess(
    Map<String, dynamic>? userData, {
    User? authUser,
    String logSource = 'user_doc',
  }) {
    final String username = _readUsername(userData);
    final bool isAdmin = _readIsAdmin(userData);
    final String? role = _readRole(userData);
    final bool adminAccess = _readAdminAccess(userData);
    final String? adminStatus = _readAdminStatus(userData);

    if (kDebugMode) {
      debugPrint('ADMIN_USERNAME=$username');
      debugPrint('ADMIN_IS_ADMIN=$isAdmin');
      debugPrint('ADMIN_ROLE=${role ?? ''}');
      debugPrint('ADMIN_ACCESS=$adminAccess');
      debugPrint('ADMIN_STATUS=${adminStatus ?? ''}');
    }

    if (isAdmin) {
      if (kDebugMode) {
        debugPrint(
            'ADMIN_FINAL_DECISION=granted source=$logSource reason=isAdmin');
      }
      return true;
    }
    if (role == 'admin') {
      if (kDebugMode) {
        debugPrint(
            'ADMIN_FINAL_DECISION=granted source=$logSource reason=role');
      }
      return true;
    }
    if (adminAccess && adminStatus == 'active') {
      if (kDebugMode) {
        debugPrint(
          'ADMIN_FINAL_DECISION=granted source=$logSource reason=adminAccess_active',
        );
      }
      return true;
    }
    final Object? adminMap = userData?['admin'];
    if (adminMap is Map && adminMap['isAdmin'] == true) {
      if (kDebugMode) {
        debugPrint(
          'ADMIN_FINAL_DECISION=granted source=$logSource reason=admin_nested',
        );
      }
      return true;
    }
    if (kDebugMode) {
      debugPrint('ADMIN_FINAL_DECISION=denied source=$logSource');
    }
    return false;
  }

  /// Matches Firestore rules admin fields plus expanded app admin fields.
  static bool userDocHasRulesAlignedAdmin(Map<String, dynamic>? userData) {
    return userDocGrantsAdminAccess(userData, logSource: 'rules_aligned');
  }

  /// True if [userData] carries admin fields or matches fallback allowlist.
  static bool userMapIndicatesAdmin(Map<String, dynamic>? userData) {
    return hasImmediateAdminAccess(cachedUserMap: userData);
  }

  /// DEPRECATED: Client-side allowlist removed for production security.
  /// Always returns false. Admin access must come from server-controlled
  /// Firestore fields (isAdmin, role, adminAccess+adminStatus) and custom claims.
  @Deprecated('Client-side admin allowlist removed. Use server fields only.')
  static bool matchesFallbackAdminAllowlist({
    Map<String, dynamic>? cachedUserMap,
    User? authUser,
  }) {
    return false;
  }

  /// Synchronous admin check from cached profile + auth (no network).
  static bool hasImmediateAdminAccess({
    Map<String, dynamic>? cachedUserMap,
    User? authUser,
  }) {
    return userDocGrantsAdminAccess(
      cachedUserMap,
      authUser: authUser,
      logSource: 'immediate',
    );
  }

  bool _hasAdminRole(Map<String, dynamic>? userData) =>
      userMapIndicatesAdmin(userData);

  void _logAdminSyncState({
    required String phase,
    Map<String, dynamic>? cachedUserMap,
    bool? immediate,
    bool? remote,
    bool? fallback,
    bool? granted,
  }) {
    if (kDebugMode) {
      final User? user = _auth.currentUser;
      debugPrint(
        'ADMIN_SYNC_STATE phase=$phase '
        'uid=${user?.uid ?? cachedUserMap?['id'] ?? cachedUserMap?['uid']} '
        'username=${cachedUserMap?['username']} '
        'immediate=$immediate remote=$remote fallback=$fallback granted=$granted',
      );
    }
  }

  /// DEPRECATED: Self-activation removed for production security.
  /// Admin fields must be set server-side only (Cloud Functions, Admin SDK).
  /// Client-side activation creates a security vulnerability.
  @Deprecated('Admin activation must be server-side only.')
  Future<void> ensureOwnerAdminActivation({
    Map<String, dynamic>? cachedUserMap,
  }) async {
    final User? authUser = _auth.currentUser;
    if (authUser == null) {
      return;
    }
    // SECURITY: No longer allow client-side admin self-activation
    return;
  }

  /// Resolves admin within [adminRemoteResolveTimeout]; never hangs.
  Future<bool> resolveAdminAccess({
    Map<String, dynamic>? cachedUserMap,
    Duration remoteTimeout = adminRemoteResolveTimeout,
  }) async {
    final User? authUser = _auth.currentUser;
    final bool immediate = hasImmediateAdminAccess(
      cachedUserMap: cachedUserMap,
      authUser: authUser,
    );
    _logAdminSyncState(
      phase: 'resolve_start',
      cachedUserMap: cachedUserMap,
      immediate: immediate,
    );
    if (immediate) {
      return true;
    }
    await ensureOwnerAdminActivation(cachedUserMap: cachedUserMap);
    bool remoteGranted = false;
    try {
      remoteGranted =
          await _resolveRemoteAdminAccess(cachedUserMap: cachedUserMap)
              .timeout(remoteTimeout, onTimeout: () => false);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ resolveAdminAccess remote failed: $e');
      }
    }
    if (remoteGranted) {
      _logAdminSyncState(
        phase: 'resolve_remote',
        cachedUserMap: cachedUserMap,
        remote: true,
        granted: true,
      );
      if (kDebugMode) {
        debugPrint('ADMIN_FINAL_DECISION=granted source=remote');
      }
      return true;
    }
    final bool fallback = matchesFallbackAdminAllowlist(
      cachedUserMap: cachedUserMap,
      authUser: authUser,
    );
    if (fallback) {
      if (kDebugMode) {
        debugPrint('ADMIN_FINAL_DECISION=granted source=fallback_timeout');
      }
      return true;
    }
    _logAdminSyncState(
      phase: 'resolve_denied',
      cachedUserMap: cachedUserMap,
      remote: false,
      fallback: false,
      granted: false,
    );
    if (kDebugMode) {
      debugPrint('ADMIN_FINAL_DECISION=denied source=resolve');
    }
    return false;
  }

  Future<bool> _resolveRemoteAdminAccess({
    Map<String, dynamic>? cachedUserMap,
  }) async {
    if (await hasAdminCustomClaim()) {
      if (kDebugMode) {
        debugPrint('ADMIN_FINAL_DECISION=granted source=jwt_claim');
      }
      return true;
    }
    return hasFirestoreRulesAdminAccess(cachedUserMap: cachedUserMap);
  }

  /// JWT `admin` claim or Firestore admin fields on users/{uid}.
  Future<bool> hasFirestoreRulesAdminAccess({
    Map<String, dynamic>? cachedUserMap,
  }) async {
    try {
      if (await hasAdminCustomClaim()) {
        return true;
      }
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        if (kDebugMode) {
          debugPrint(
              'ADMIN_FINAL_DECISION=denied source=firestore reason=no_auth');
        }
        return false;
      }
      if (matchesFallbackAdminAllowlist(
        cachedUserMap: cachedUserMap,
        authUser: currentUser,
      )) {
        if (kDebugMode) {
          debugPrint('ADMIN_FINAL_DECISION=granted source=firestore_fallback');
        }
        return true;
      }
      final DocumentSnapshot<Map<String, dynamic>> userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      if (!userDoc.exists) {
        if (kDebugMode) {
          debugPrint(
              'ADMIN_FINAL_DECISION=denied source=firestore reason=no_doc');
        }
        return false;
      }
      return userDocGrantsAdminAccess(
        userDoc.data(),
        authUser: currentUser,
        logSource: 'firestore_remote',
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ hasFirestoreRulesAdminAccess: $e');
      }
      return matchesFallbackAdminAllowlist(
        cachedUserMap: cachedUserMap,
        authUser: _auth.currentUser,
      );
    }
  }

  /// Shield visibility: cached profile map, JWT `admin`, or Firestore doc.
  Future<bool> hasAdminUiAccess({
    Map<String, dynamic>? cachedUserMap,
  }) async {
    return resolveAdminAccess(cachedUserMap: cachedUserMap);
  }

  Future<bool> hasAdminCustomClaim() async {
    final User? u = _auth.currentUser;
    if (u == null) {
      return false;
    }
    final IdTokenResult t = await u.getIdTokenResult();
    return t.claims?['admin'] == true;
  }

  /// Refresh ID token after Cloud-side claim updates.
  Future<void> refreshIdTokenForAdminSession() async {
    final User? u = _auth.currentUser;
    if (u == null) {
      return;
    }
    await u.getIdToken(true);
  }

  Future<bool> isCurrentUserAdmin() async {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        return false;
      }
      final DocumentSnapshot<Map<String, dynamic>> userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      if (!userDoc.exists) {
        return false;
      }
      if (_hasAdminRole(userDoc.data())) {
        if (kDebugMode) {
          debugPrint(
            '✅ Admin check: User ${currentUser.uid} has Firestore admin fields',
          );
        }
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error checking admin status: $e');
      }
      return false;
    }
  }

  Future<bool> isUserAdmin(String userId) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> userDoc =
          await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        return false;
      }
      return _hasAdminRole(userDoc.data());
    } catch (e) {
      debugPrint('❌ Error checking user admin status: $e');
      return false;
    }
  }

  Future<void> grantAdminRole(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'role': 'admin',
        'isAdmin': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (kDebugMode) {
        debugPrint('✅ Granted admin role to user: $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error granting admin role: $e');
      }
      rethrow;
    }
  }

  Future<void> revokeAdminRole(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'role': 'user',
        'isAdmin': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (kDebugMode) {
        debugPrint('✅ Revoked admin role from user: $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error revoking admin role: $e');
      }
      rethrow;
    }
  }

  Future<void> logAdminAction(
    String action, {
    Map<String, dynamic>? data,
  }) async {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        return;
      }
      await _firestore.collection('admin_logs').add({
        'adminId': currentUser.uid,
        'adminUid': currentUser.uid,
        'action': action,
        'data': data,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (kDebugMode) {
        debugPrint('📝 Admin action logged: $action');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error logging admin action: $e');
      }
    }
  }
}
