import 'package:cloud_firestore/cloud_firestore.dart';

/// Service to manage reserved usernames that cannot be taken by new users
class UsernameLockService {
  static final UsernameLockService _instance = UsernameLockService._internal();
  factory UsernameLockService() => _instance;
  UsernameLockService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Reserved usernames that cannot be taken by new users
  static const List<String> _reservedUsernames = [
    'technqs', // Your reserved username
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
    final normalizedUsername = username.toLowerCase().trim();
    return _reservedUsernames.contains(normalizedUsername);
  }

  /// Check if a username is available (not taken and not reserved)
  Future<bool> isUsernameAvailable(String username) async {
    final normalizedUsername = username.toLowerCase().trim();

    // First check if it's reserved
    if (isUsernameReserved(normalizedUsername)) {
      return false;
    }

    // Check if username exists in Firestore
    try {
      final query = await _firestore
          .collection('users')
          .where('username', isEqualTo: normalizedUsername)
          .limit(1)
          .get();

      return query.docs.isEmpty;
    } catch (e) {
      // If there's an error checking, assume it's not available for safety
      return false;
    }
  }

  /// Get all reserved usernames
  List<String> getReservedUsernames() {
    return List.from(_reservedUsernames);
  }

  /// Add a new reserved username (admin only)
  Future<bool> addReservedUsername(String username) async {
    try {
      final normalizedUsername = username.toLowerCase().trim();

      // Check if it's already reserved
      if (isUsernameReserved(normalizedUsername)) {
        return true; // Already reserved
      }

      // Add to reserved usernames collection in Firestore
      await _firestore
          .collection('reserved_usernames')
          .doc(normalizedUsername)
          .set({
        'username': normalizedUsername,
        'reservedAt': FieldValue.serverTimestamp(),
        'reservedBy': 'system', // Could be admin user ID
        'reason': 'Manual reservation',
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Remove a reserved username (admin only)
  Future<bool> removeReservedUsername(String username) async {
    try {
      final normalizedUsername = username.toLowerCase().trim();

      // Don't allow removing core reserved usernames
      if (_reservedUsernames.contains(normalizedUsername)) {
        return false;
      }

      await _firestore
          .collection('reserved_usernames')
          .doc(normalizedUsername)
          .delete();
      return true;
    } catch (e) {
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
    final normalizedUsername = username.toLowerCase().trim();

    // Check length
    if (normalizedUsername.length < 3) {
      return UsernameValidationResult(
        isValid: false,
        errorMessage: 'Username must be at least 3 characters long.',
      );
    }

    if (normalizedUsername.length > 20) {
      return UsernameValidationResult(
        isValid: false,
        errorMessage: 'Username must be 20 characters or less.',
      );
    }

    // Check for valid characters
    final usernameRegex = RegExp(r'^[a-zA-Z0-9_]+$');
    if (!usernameRegex.hasMatch(normalizedUsername)) {
      return UsernameValidationResult(
        isValid: false,
        errorMessage:
            'Username can only contain letters, numbers, and underscores.',
      );
    }

    // Check if reserved
    if (isUsernameReserved(normalizedUsername)) {
      return UsernameValidationResult(
        isValid: false,
        errorMessage: getReservedUsernameErrorMessage(normalizedUsername),
      );
    }

    // Check if available
    final isAvailable = await isUsernameAvailable(normalizedUsername);
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
  final bool isValid;
  final String? errorMessage;

  UsernameValidationResult({
    required this.isValid,
    this.errorMessage,
  });
}
