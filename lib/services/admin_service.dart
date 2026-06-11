import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Firestore role / `admin.isAdmin` drives **UI** (shield). Custom claim
/// `admin` drives **rules + Cloud Functions**.
class AdminService {
  static final AdminService instance = AdminService._internal();
  factory AdminService() => instance;
  AdminService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String kFallbackAdminUid = 'bU0RxyZ2L4ULAv1Co5L4f825yV73';
  static const String kFallbackAdminEmail = 'technqs@gmail.com';
  static const Set<String> kFallbackAdminUsernames = <String>{
    'technqs',
    'buzzz',
  };

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

    debugPrint('ADMIN_USERNAME=$username');
    debugPrint('ADMIN_IS_ADMIN=$isAdmin');
    debugPrint('ADMIN_ROLE=${role ?? ''}');
    debugPrint('ADMIN_ACCESS=$adminAccess');
    debugPrint('ADMIN_STATUS=${adminStatus ?? ''}');

    if (isAdmin) {
      debugPrint(
          'ADMIN_FINAL_DECISION=granted source=$logSource reason=isAdmin');
      return true;
    }
    if (role == 'admin') {
      debugPrint('ADMIN_FINAL_DECISION=granted source=$logSource reason=role');
      return true;
    }
    if (adminAccess && adminStatus == 'active') {
      debugPrint(
        'ADMIN_FINAL_DECISION=granted source=$logSource reason=adminAccess_active',
      );
      return true;
    }
    final Object? adminMap = userData?['admin'];
    if (adminMap is Map && adminMap['isAdmin'] == true) {
      debugPrint(
        'ADMIN_FINAL_DECISION=granted source=$logSource reason=admin_nested',
      );
      return true;
    }
    if (matchesFallbackAdminAllowlist(
      cachedUserMap: userData,
      authUser: authUser,
    )) {
      debugPrint(
          'ADMIN_FINAL_DECISION=granted source=$logSource reason=fallback');
      return true;
    }
    debugPrint('ADMIN_FINAL_DECISION=denied source=$logSource');
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

  static bool matchesFallbackAdminAllowlist({
    Map<String, dynamic>? cachedUserMap,
    User? authUser,
  }) {
    final User? user = authUser ??
        (Firebase.apps.isNotEmpty ? FirebaseAuth.instance.currentUser : null);
    final String uid =
        (cachedUserMap?['id'] ?? cachedUserMap?['uid'] ?? user?.uid ?? '')
            .toString()
            .trim();
    if (uid == kFallbackAdminUid) {
      return true;
    }
    final String email = (cachedUserMap?['email'] ?? user?.email ?? '')
        .toString()
        .toLowerCase()
        .trim();
    if (email == kFallbackAdminEmail) {
      return true;
    }
    final String username =
        (cachedUserMap?['username'] ?? '').toString().toLowerCase().trim();
    if (username.isNotEmpty && kFallbackAdminUsernames.contains(username)) {
      return true;
    }
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
    final User? user = _auth.currentUser;
    debugPrint(
      'ADMIN_SYNC_STATE phase=$phase '
      'uid=${user?.uid ?? cachedUserMap?['id'] ?? cachedUserMap?['uid']} '
      'username=${cachedUserMap?['username']} '
      'immediate=$immediate remote=$remote fallback=$fallback granted=$granted',
    );
  }

  /// Owner accounts may self-merge client-writable admin activation fields.
  Future<void> ensureOwnerAdminActivation({
    Map<String, dynamic>? cachedUserMap,
  }) async {
    final User? authUser = _auth.currentUser;
    if (authUser == null) {
      return;
    }
    if (!matchesFallbackAdminAllowlist(
      cachedUserMap: cachedUserMap,
      authUser: authUser,
    )) {
      return;
    }
    try {
      final DocumentSnapshot<Map<String, dynamic>> doc =
          await _firestore.collection('users').doc(authUser.uid).get();
      final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
      if (_readIsAdmin(data) || _readRole(data) == 'admin') {
        return;
      }
      if (_readAdminAccess(data) && _readAdminStatus(data) == 'active') {
        return;
      }
      await _firestore.collection('users').doc(authUser.uid).set(
        <String, dynamic>{
          'adminAccess': true,
          'adminStatus': 'active',
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      debugPrint(
        'ADMIN_FINAL_DECISION=granted source=ensure_owner_document '
        'uid=${authUser.uid}',
      );
    } catch (e) {
      debugPrint('⚠️ ensureOwnerAdminActivation failed: $e');
    }
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
      debugPrint('⚠️ resolveAdminAccess remote failed: $e');
    }
    if (remoteGranted) {
      _logAdminSyncState(
        phase: 'resolve_remote',
        cachedUserMap: cachedUserMap,
        remote: true,
        granted: true,
      );
      debugPrint('ADMIN_FINAL_DECISION=granted source=remote');
      return true;
    }
    final bool fallback = matchesFallbackAdminAllowlist(
      cachedUserMap: cachedUserMap,
      authUser: authUser,
    );
    if (fallback) {
      debugPrint('ADMIN_FINAL_DECISION=granted source=fallback_timeout');
      return true;
    }
    _logAdminSyncState(
      phase: 'resolve_denied',
      cachedUserMap: cachedUserMap,
      remote: false,
      fallback: false,
      granted: false,
    );
    debugPrint('ADMIN_FINAL_DECISION=denied source=resolve');
    return false;
  }

  Future<bool> _resolveRemoteAdminAccess({
    Map<String, dynamic>? cachedUserMap,
  }) async {
    if (await hasAdminCustomClaim()) {
      debugPrint('ADMIN_FINAL_DECISION=granted source=jwt_claim');
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
        debugPrint(
            'ADMIN_FINAL_DECISION=denied source=firestore reason=no_auth');
        return false;
      }
      if (matchesFallbackAdminAllowlist(
        cachedUserMap: cachedUserMap,
        authUser: currentUser,
      )) {
        debugPrint('ADMIN_FINAL_DECISION=granted source=firestore_fallback');
        return true;
      }
      final DocumentSnapshot<Map<String, dynamic>> userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      if (!userDoc.exists) {
        debugPrint(
            'ADMIN_FINAL_DECISION=denied source=firestore reason=no_doc');
        return false;
      }
      return userDocGrantsAdminAccess(
        userDoc.data(),
        authUser: currentUser,
        logSource: 'firestore_remote',
      );
    } catch (e) {
      debugPrint('❌ hasFirestoreRulesAdminAccess: $e');
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
        debugPrint(
          '✅ Admin check: User ${currentUser.uid} has Firestore admin fields',
        );
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error checking admin status: $e');
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
      debugPrint('✅ Granted admin role to user: $userId');
    } catch (e) {
      debugPrint('❌ Error granting admin role: $e');
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
      debugPrint('✅ Revoked admin role from user: $userId');
    } catch (e) {
      debugPrint('❌ Error revoking admin role: $e');
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
      debugPrint('📝 Admin action logged: $action');
    } catch (e) {
      debugPrint('❌ Error logging admin action: $e');
    }
  }
}
