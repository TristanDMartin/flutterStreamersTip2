import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AdminService {
  static final AdminService instance = AdminService._internal();
  factory AdminService() => instance;
  AdminService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _hasAdminRole(Map<String, dynamic>? userData) {
    if (userData == null) {
      return false;
    }

    final role = userData['role'] as String?;
    final isAdmin = userData['isAdmin'] as bool? ?? false;
    return isAdmin || role == 'admin';
  }

  /// Check if current user is an admin
  Future<bool> isCurrentUserAdmin() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      // Check by username (backup method)
      final userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      if (!userDoc.exists) return false;

      if (_hasAdminRole(userDoc.data())) {
        debugPrint(
          '✅ Admin check: User ${currentUser.uid} has Firestore admin access',
        );
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('❌ Error checking admin status: $e');
      return false;
    }
  }

  /// Check if a specific user ID is an admin
  Future<bool> isUserAdmin(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return false;
      return _hasAdminRole(userDoc.data());
    } catch (e) {
      debugPrint('❌ Error checking user admin status: $e');
      return false;
    }
  }

  /// Grant admin privileges to a user
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

  /// Revoke admin privileges from a user
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

  /// Log admin action
  Future<void> logAdminAction(String action,
      {Map<String, dynamic>? data}) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      await _firestore.collection('admin_logs').add({
        'adminId': currentUser.uid,
        'action': action,
        'data': data,
        'timestamp': FieldValue.serverTimestamp(),
      });
      debugPrint('📝 Admin action logged: $action');
    } catch (e) {
      debugPrint('❌ Error logging admin action: $e');
    }
  }
}
