import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AdminService {
  static final AdminService instance = AdminService._internal();
  factory AdminService() => instance;
  AdminService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // List of admin user IDs (UIDs)
  // Add your technqs account UID here
  static const List<String> _adminUserIds = [
    'bU0RxyZ2L4ULAv1Co5L4f825yV73', // technqs UID
    // Add more admin UIDs as needed
  ];

  // List of admin usernames (as backup)
  static const List<String> _adminUsernames = [
    'technqs',
    // Add more admin usernames as needed
  ];

  /// Check if current user is an admin
  Future<bool> isCurrentUserAdmin() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      // Check by UID first (most reliable)
      if (_adminUserIds.contains(currentUser.uid)) {
        debugPrint('✅ Admin check: User ${currentUser.uid} is admin (by UID)');
        return true;
      }

      // Check by username (backup method)
      final userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      if (!userDoc.exists) return false;

      final username = userDoc.data()?['username'] as String?;
      if (username != null && _adminUsernames.contains(username)) {
        debugPrint(
          '✅ Admin check: User $username is admin (by username)',
        );
        return true;
      }

      // Check role field in user document
      final role = userDoc.data()?['role'] as String?;
      if (role == 'admin') {
        debugPrint(
          '✅ Admin check: User ${currentUser.uid} has admin role',
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
      if (_adminUserIds.contains(userId)) return true;

      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return false;

      final username = userDoc.data()?['username'] as String?;
      if (username != null && _adminUsernames.contains(username)) return true;

      final role = userDoc.data()?['role'] as String?;
      return role == 'admin';
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
