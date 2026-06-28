import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../widgets/profile/profile_username_rules.dart';

/// Thrown when a username is already owned by another account.
class UsernameTakenException implements Exception {
  UsernameTakenException(this.username);

  final String username;

  @override
  String toString() => 'Username "$username" is already taken.';
}

/// Service to manage reserved usernames that cannot be taken by new users
class UsernameLockService {
  UsernameLockService({FirebaseFirestore? firestore})
      : _firestoreOverride = firestore;

  final FirebaseFirestore? _firestoreOverride;
  FirebaseFirestore? _firestoreCache;

  FirebaseFirestore get _firestore {
    if (_firestoreOverride != null) {
      return _firestoreOverride!;
    }
    if (_firestoreCache == null) {
      if (Firebase.apps.isEmpty) {
        throw StateError('Firebase not initialized');
      }
      _firestoreCache = FirebaseFirestore.instance;
    }
    return _firestoreCache!;
  }

  // Reserved usernames that cannot be taken by new users
  static const List<String> _reservedUsernames = <String>[
    'technqs',
    'buzzz',
    'admin',
    'administrator',
    'moderator',
    'support',
    'help',
    'api',
    'system',
    'root',
    'test',
    'demo',
    'sample',
    'official',
    'streamerstip',
    'app',
    'service',
    'bot',
    'automated',
    'noreply',
    'no-reply',
  ];

  /// Check if a username is reserved and cannot be taken
  bool isUsernameReserved(String username) {
    final String normalizedUsername =
        ProfileUsernameRules.normalize(username);
    return _reservedUsernames.contains(normalizedUsername);
  }

  /// Check if a username is available (not taken and not reserved)
  Future<bool> isUsernameAvailable(String username) async {
    return isUsernameAvailableForUser(username, '');
  }

  /// Allows the current [userId] to keep an already-owned username.
  Future<bool> isUsernameAvailableForUser(
    String username,
    String userId,
  ) async {
    final String normalizedUsername =
        ProfileUsernameRules.normalize(username);
    if (normalizedUsername.isEmpty ||
        !ProfileUsernameRules.isFormatValid(normalizedUsername)) {
      return false;
    }
    if (isUsernameReserved(normalizedUsername)) {
      return false;
    }
    try {
      final bool? mappingResult = await _lookupUsernameMapping(
        normalizedUsername: normalizedUsername,
        userId: userId,
      );
      if (mappingResult != null) {
        return mappingResult;
      }
      return _lookupUsernameOnUserProfiles(
        normalizedUsername: normalizedUsername,
        userId: userId,
      );
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'UsernameLockService: availability check failed for '
          '$normalizedUsername: $error',
        );
        debugPrint('$stackTrace');
      }
      rethrow;
    }
  }

  Future<bool?> _lookupUsernameMapping({
    required String normalizedUsername,
    required String userId,
  }) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> usernameDoc =
          await _firestore.collection('usernames').doc(normalizedUsername).get();
      if (!usernameDoc.exists) {
        return null;
      }
      final String? ownerUid = usernameDoc.data()?['uid'] as String?;
      return ownerUid == userId;
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        if (kDebugMode) {
          debugPrint(
            'UsernameLockService: usernames/$normalizedUsername read denied, '
            'falling back to users query',
          );
        }
        return null;
      }
      rethrow;
    }
  }

  Future<bool> _lookupUsernameOnUserProfiles({
    required String normalizedUsername,
    required String userId,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> lowercaseQuery = await _firestore
        .collection('users')
        .where('usernameLowercase', isEqualTo: normalizedUsername)
        .limit(1)
        .get();
    if (lowercaseQuery.docs.isNotEmpty) {
      return lowercaseQuery.docs.first.id == userId;
    }
    final QuerySnapshot<Map<String, dynamic>> legacyQuery = await _firestore
        .collection('users')
        .where('username', isEqualTo: normalizedUsername)
        .limit(1)
        .get();
    if (legacyQuery.docs.isEmpty) {
      return true;
    }
    return legacyQuery.docs.first.id == userId;
  }

  /// Atomically reserves [username] for [userId].
  Future<void> reserveUsername({
    required String username,
    required String userId,
    String? previousUsername,
  }) async {
    final String normalizedUsername =
        ProfileUsernameRules.normalize(username);
    final UsernameValidationResult validation =
        await validateUsernameForUser(normalizedUsername, userId);
    if (!validation.isValid) {
      throw Exception(validation.errorMessage ?? 'Invalid username');
    }
    final String? previousNormalized = previousUsername == null
        ? null
        : ProfileUsernameRules.normalize(previousUsername);
    final DocumentReference<Map<String, dynamic>> usernameRef =
        _firestore.collection('usernames').doc(normalizedUsername);
    final DocumentReference<Map<String, dynamic>> userRef =
        _firestore.collection('users').doc(userId);
    await _firestore.runTransaction((Transaction transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> existingUsername =
          await transaction.get(usernameRef);
      if (existingUsername.exists) {
        final String? ownerUid = existingUsername.data()?['uid'] as String?;
        if (ownerUid != null && ownerUid != userId) {
          throw UsernameTakenException(normalizedUsername);
        }
      }
      transaction.set(
        usernameRef,
        <String, dynamic>{
          'uid': userId,
          'username': normalizedUsername,
          'createdAt': FieldValue.serverTimestamp(),
        },
      );
      transaction.set(
        userRef,
        <String, dynamic>{
          'username': normalizedUsername,
          'usernameLowercase': normalizedUsername,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      if (previousNormalized != null &&
          previousNormalized.isNotEmpty &&
          previousNormalized != normalizedUsername) {
        final DocumentReference<Map<String, dynamic>> previousRef =
            _firestore.collection('usernames').doc(previousNormalized);
        final DocumentSnapshot<Map<String, dynamic>> previousSnap =
            await transaction.get(previousRef);
        if (previousSnap.exists &&
            previousSnap.data()?['uid'] == userId) {
          transaction.delete(previousRef);
        }
      }
    });
  }

  /// Get all reserved usernames
  List<String> getReservedUsernames() {
    return List<String>.from(_reservedUsernames);
  }

  /// Add a new reserved username (admin only)
  Future<bool> addReservedUsername(String username) async {
    try {
      final String normalizedUsername =
          ProfileUsernameRules.normalize(username);
      if (isUsernameReserved(normalizedUsername)) {
        return true;
      }
      await _firestore
          .collection('reserved_usernames')
          .doc(normalizedUsername)
          .set(<String, dynamic>{
        'username': normalizedUsername,
        'reservedAt': FieldValue.serverTimestamp(),
        'reservedBy': 'system',
        'reason': 'Manual reservation',
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Remove a reserved username (admin only)
  Future<bool> removeReservedUsername(String username) async {
    try {
      final String normalizedUsername =
          ProfileUsernameRules.normalize(username);
      if (_reservedUsernames.contains(normalizedUsername)) {
        return false;
      }
      await _firestore
          .collection('reserved_usernames')
          .doc(normalizedUsername)
          .delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Get validation error message for reserved username
  String getReservedUsernameErrorMessage(String username) {
    if (username.toLowerCase() == 'technqs') {
      return 'This username is reserved and cannot be taken.';
    }
    return 'This username is reserved and cannot be taken.';
  }

  /// Validate username during registration
  Future<UsernameValidationResult> validateUsername(String username) async {
    return validateUsernameForUser(username, '');
  }

  Future<UsernameValidationResult> validateUsernameForUser(
    String username,
    String userId,
  ) async {
    final String normalizedUsername =
        ProfileUsernameRules.normalize(username);
    final String? localError =
        ProfileUsernameRules.localValidationMessage(normalizedUsername);
    if (localError != null) {
      return UsernameValidationResult(
        isValid: false,
        errorMessage: localError,
      );
    }
    if (isUsernameReserved(normalizedUsername)) {
      return UsernameValidationResult(
        isValid: false,
        errorMessage: getReservedUsernameErrorMessage(normalizedUsername),
      );
    }
    final bool isAvailable = await isUsernameAvailableForUser(
      normalizedUsername,
      userId,
    );
    if (!isAvailable) {
      return UsernameValidationResult(
        isValid: false,
        errorMessage: 'This username is already taken.',
      );
    }
    return UsernameValidationResult(
      isValid: true,
      errorMessage: null,
    );
  }
}

/// Result of username validation
class UsernameValidationResult {
  const UsernameValidationResult({
    required this.isValid,
    required this.errorMessage,
  });

  final bool isValid;
  final String? errorMessage;
}
