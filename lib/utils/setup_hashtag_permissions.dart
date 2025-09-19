import 'package:cloud_firestore/cloud_firestore.dart';

/// Utility script to set up initial hashtag permissions
/// Run this once to grant Owner and Founder hashtag permissions to specific users
class HashtagPermissionSetup {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Sets up hashtag permissions for Owner and Founder
  /// Replace the user IDs with the actual Owner and Founder user IDs
  static Future<void> setupInitialPermissions() async {
    try {
      // Replace these with actual user IDs
      const String ownerUserId = 'YOUR_OWNER_USER_ID_HERE';
      const String founderUserId = 'YOUR_FOUNDER_USER_ID_HERE';
      
      // Grant Owner hashtag permission
      await _firestore
          .collection('hashtag_permissions')
          .doc('owner')
          .set({
        'hashtag': 'owner',
        'authorizedUsers': [ownerUserId],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Grant Founder hashtag permission
      await _firestore
          .collection('hashtag_permissions')
          .doc('founder')
          .set({
        'hashtag': 'founder',
        'authorizedUsers': [founderUserId],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Hashtag permissions set up successfully!');
      print('Owner hashtag granted to: $ownerUserId');
      print('Founder hashtag granted to: $founderUserId');
    } catch (e) {
      print('❌ Error setting up hashtag permissions: $e');
    }
  }

  /// Adds a user to Owner hashtag permissions
  static Future<void> addOwnerPermission(String userId) async {
    try {
      await _firestore
          .collection('hashtag_permissions')
          .doc('owner')
          .set({
        'hashtag': 'owner',
        'authorizedUsers': FieldValue.arrayUnion([userId]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      print('✅ Owner permission granted to: $userId');
    } catch (e) {
      print('❌ Error granting Owner permission: $e');
    }
  }

  /// Adds a user to Founder hashtag permissions
  static Future<void> addFounderPermission(String userId) async {
    try {
      await _firestore
          .collection('hashtag_permissions')
          .doc('founder')
          .set({
        'hashtag': 'founder',
        'authorizedUsers': FieldValue.arrayUnion([userId]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      print('✅ Founder permission granted to: $userId');
    } catch (e) {
      print('❌ Error granting Founder permission: $e');
    }
  }
}
