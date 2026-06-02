import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class HashtagLockService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // List of permanently reserved hashtags
  final Set<String> _reservedHashtags = {
    'owner',
    'founder',
    'admin',
    'moderator',
    'staff',
    'official',
    'streamerstip',
    'system',
    'support',
    'help',
    'test',
    'dev',
    'developer',
    // Add more as needed
  };

  // Validates a hashtag against rules and reserved list
  Future<HashtagValidationResult> validateHashtag(
      String hashtag, String? currentUserId) async {
    // Clean the hashtag (remove # if present)
    final cleanHashtag = hashtag.replaceAll('#', '').toLowerCase();

    if (cleanHashtag.length < 2 || cleanHashtag.length > 20) {
      return HashtagValidationResult(
          isValid: false,
          errorMessage: 'Hashtag must be 2-20 characters long.');
    }

    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(cleanHashtag)) {
      return HashtagValidationResult(
          isValid: false,
          errorMessage:
              'Hashtag can only contain letters, numbers, and underscores.');
    }

    if (_reservedHashtags.contains(cleanHashtag)) {
      // Check if the current user is authorized to use this reserved hashtag
      final isAuthorized =
          await _isUserAuthorizedForHashtag(cleanHashtag, currentUserId);
      if (!isAuthorized) {
        return HashtagValidationResult(
            isValid: false,
            errorMessage: 'This hashtag is reserved and cannot be used.');
      }
    }

    return HashtagValidationResult(isValid: true);
  }

  // Checks if a hashtag is available for use
  Future<bool> isHashtagAvailable(String hashtag, String? currentUserId) async {
    final validationResult = await validateHashtag(hashtag, currentUserId);
    return validationResult.isValid;
  }

  // Checks if a user is authorized to use a reserved hashtag
  Future<bool> _isUserAuthorizedForHashtag(
      String hashtag, String? currentUserId) async {
    if (currentUserId == null) return false;

    try {
      // Check if the user has special permissions for this hashtag
      final doc =
          await _firestore.collection('hashtag_permissions').doc(hashtag).get();

      if (!doc.exists) return false;

      final data = doc.data();
      final authorizedUsers = List<String>.from(data?['authorizedUsers'] ?? []);

      return authorizedUsers.contains(currentUserId);
    } catch (e) {
      // If there's an error checking permissions, deny access for security
      return false;
    }
  }

  // Grants permission for a user to use a reserved hashtag (admin only)
  Future<bool> grantHashtagPermission(String hashtag, String userId) async {
    try {
      final cleanHashtag = hashtag.replaceAll('#', '').toLowerCase();

      // First, try to get the existing document
      final docRef =
          _firestore.collection('hashtag_permissions').doc(cleanHashtag);
      final doc = await docRef.get();

      if (doc.exists) {
        // Document exists, add user to existing list
        await docRef.update({
          'authorizedUsers': FieldValue.arrayUnion([userId]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Document doesn't exist, create it with the user
        await docRef.set({
          'hashtag': cleanHashtag,
          'authorizedUsers': [userId],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      return true;
    } catch (e) {
      debugPrint('Error granting hashtag permission: $e');
      return false;
    }
  }

  // Revokes permission for a user to use a reserved hashtag (admin only)
  Future<bool> revokeHashtagPermission(String hashtag, String userId) async {
    try {
      final cleanHashtag = hashtag.replaceAll('#', '').toLowerCase();

      await _firestore
          .collection('hashtag_permissions')
          .doc(cleanHashtag)
          .update({
        'authorizedUsers': FieldValue.arrayRemove([userId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  // Gets all users authorized to use a specific hashtag
  Future<List<String>> getAuthorizedUsers(String hashtag) async {
    try {
      final cleanHashtag = hashtag.replaceAll('#', '').toLowerCase();

      final doc = await _firestore
          .collection('hashtag_permissions')
          .doc(cleanHashtag)
          .get();

      if (!doc.exists) return [];

      final data = doc.data();
      return List<String>.from(data?['authorizedUsers'] ?? []);
    } catch (e) {
      return [];
    }
  }

  // Checks if a hashtag is reserved
  bool isHashtagReserved(String hashtag) {
    final cleanHashtag = hashtag.replaceAll('#', '').toLowerCase();
    return _reservedHashtags.contains(cleanHashtag);
  }

  // Gets all reserved hashtags
  Set<String> getReservedHashtags() {
    return Set.from(_reservedHashtags);
  }
}

class HashtagValidationResult {
  final bool isValid;
  final String? errorMessage;

  HashtagValidationResult({required this.isValid, this.errorMessage});
}
