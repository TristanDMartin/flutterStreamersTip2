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

  /// Debug-only UI bootstrap; never populated in release builds.
  static Set<String> get _shieldBootstrapUsernames {
    if (!kDebugMode) {
      return const <String>{};
    }
    return const <String>{'technqs', 'buzzz'};
  }

  /// Matches [firestore.rules] `isFirestoreAdminSelf()` only (no username
  /// bootstrap). Use before queries that require `isUserAdmin()` in rules.
  static bool userDocHasRulesAlignedAdmin(Map<String, dynamic>? userData) {
    if (userData == null) {
      return false;
    }
    final String? role = userData['role'] as String?;
    final bool legacy = userData['isAdmin'] as bool? ?? false;
    final Object? adminMap = userData['admin'];
    bool nested = false;
    if (adminMap is Map) {
      nested = adminMap['isAdmin'] == true;
    }
    return legacy || role == 'admin' || nested;
  }

  /// True if [userData] carries admin fields. Username bootstrap is debug-only.
  static bool userMapIndicatesAdmin(Map<String, dynamic>? userData) {
    if (userData == null) {
      return false;
    }
    final String un =
        (userData['username'] ?? '').toString().toLowerCase().trim();
    if (un.isNotEmpty && _shieldBootstrapUsernames.contains(un)) {
      return true;
    }
    return userDocHasRulesAlignedAdmin(userData);
  }

  bool _hasAdminRole(Map<String, dynamic>? userData) =>
      userMapIndicatesAdmin(userData);

  /// JWT `admin` claim or Firestore admin fields rules use — not username
  /// bootstrap.
  Future<bool> hasFirestoreRulesAdminAccess() async {
    try {
      if (await hasAdminCustomClaim()) {
        return true;
      }
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        return false;
      }
      final DocumentSnapshot<Map<String, dynamic>> userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      if (!userDoc.exists) {
        return false;
      }
      final bool aligned = userDocHasRulesAlignedAdmin(userDoc.data());
      if (aligned) {
        debugPrint(
          '✅ Admin check: rules-aligned admin for ${currentUser.uid}',
        );
      }
      return aligned;
    } catch (e) {
      debugPrint('❌ hasFirestoreRulesAdminAccess: $e');
      return false;
    }
  }

  /// Shield visibility: cached profile map, JWT `admin`, or Firestore doc.
  Future<bool> hasAdminUiAccess({
    Map<String, dynamic>? cachedUserMap,
  }) async {
    if (userMapIndicatesAdmin(cachedUserMap)) {
      return true;
    }
    try {
      if (await hasAdminCustomClaim()) {
        return true;
      }
    } catch (e) {
      debugPrint('⚠️ Admin claim check failed: $e');
    }
    return isCurrentUserAdmin();
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
