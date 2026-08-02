import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/app_check_http_headers.dart';
import '../core/backend/site_api_base.dart';
import '../widgets/profile/profile_username_rules.dart';

/// Thrown when a username is already owned by another account.
class UsernameTakenException implements Exception {
  UsernameTakenException(this.username);

  final String username;

  @override
  String toString() => 'Username "$username" is already taken.';
}

/// Thrown when the backend rejects a username claim for a clear reason.
class UsernameClaimException implements Exception {
  const UsernameClaimException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

/// Service to manage reserved usernames that cannot be taken by new users
class UsernameLockService {
  UsernameLockService({
    FirebaseFirestore? firestore,
    http.Client? httpClient,
    String? siteApiBase,
  })  : _firestoreOverride = firestore,
        _http = httpClient ?? http.Client(),
        _siteApiBase = resolveSiteApiBase(explicitOverride: siteApiBase);

  final FirebaseFirestore? _firestoreOverride;
  final http.Client _http;
  final String _siteApiBase;
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
      // No usernames/{name} doc → treat as available.
      // Do not query users by usernameLowercase: private user docs are
      // owner-read-only, so that fallback always throws permission-denied.
      return true;
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
      if (ownerUid == null || ownerUid.isEmpty) {
        return false;
      }
      return ownerUid == userId;
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        if (kDebugMode) {
          debugPrint(
            'UsernameLockService: usernames/$normalizedUsername read denied',
          );
        }
        // Registry unreadable — do not fall back to private users queries.
        // Optimistic available; final claim still revalidates server-side.
        return true;
      }
      rethrow;
    }
  }

  /// Claims [username] for [userId] via the same site API as web
  /// (`/api/username/change`, with claim fallback). Client writes to
  /// `usernames/` are denied by Firestore rules.
  ///
  /// When [allowSoftSkip] is true (Tippy create profile), server 5xx / auth
  /// gaps do not block saving users/{uid} — registry lock can retry later.
  Future<void> reserveUsername({
    required String username,
    required String userId,
    String? previousUsername,
    bool allowSoftSkip = false,
  }) async {
    final String normalizedUsername =
        ProfileUsernameRules.normalize(username);
    final UsernameValidationResult validation =
        await validateUsernameForUser(normalizedUsername, userId);
    if (!validation.isValid) {
      throw UsernameClaimException(
        validation.errorMessage ?? 'Invalid username',
        code: 'invalid',
      );
    }
    final User? authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null || authUser.uid != userId) {
      throw const UsernameClaimException(
        'Sign in required to claim a username.',
        code: 'auth',
      );
    }
    try {
      await authUser.reload();
    } catch (_) {}
    final User resolvedUser =
        FirebaseAuth.instance.currentUser ?? authUser;
    String currentNormalized = ProfileUsernameRules.normalize(
      previousUsername ?? '',
    );
    try {
      final DocumentSnapshot<Map<String, dynamic>> userSnap =
          await _firestore.collection('users').doc(userId).get();
      final Map<String, dynamic>? data = userSnap.data();
      final String fromDoc = ProfileUsernameRules.normalize(
        (data?['usernameNormalized'] as String?) ??
            (data?['usernameLowercase'] as String?) ??
            (data?['username'] as String?) ??
            '',
      );
      if (fromDoc.isNotEmpty) {
        currentNormalized = fromDoc;
      }
    } catch (_) {}
    if (currentNormalized.isNotEmpty &&
        currentNormalized == normalizedUsername) {
      return;
    }
    final bool isInitialClaim = currentNormalized.isEmpty;
    if (!resolvedUser.emailVerified) {
      if (kDebugMode) {
        debugPrint(
          'UsernameLockService: skip registry lock until email verified '
          '($normalizedUsername, initial=$isInitialClaim)',
        );
      }
      return;
    }
    final String? idToken = await resolvedUser.getIdToken(true);
    if (idToken == null || idToken.isEmpty) {
      throw const UsernameClaimException(
        'Sign in required to claim a username.',
        code: 'auth',
      );
    }
    try {
      // Prefer change: Tippy/new accounts often fail claim (provisioning /
      // "already claimed" when users/ has a provisional name).
      await _postUsernameApi(
        uri: Uri.parse(siteUsernameChangeUrl(base: _siteApiBase)),
        idToken: idToken,
        username: normalizedUsername,
        action: 'change',
      );
      return;
    } on UsernameClaimException catch (changeError) {
      if (!isInitialClaim) {
        if (allowSoftSkip && _canSoftSkipUsernameLock(changeError)) {
          debugPrint(
            'UsernameLockService: soft-skip change lock: $changeError',
          );
          return;
        }
        rethrow;
      }
      try {
        await _postUsernameApi(
          uri: Uri.parse(siteUsernameClaimUrl(base: _siteApiBase)),
          idToken: idToken,
          username: normalizedUsername,
          action: 'claim',
        );
        return;
      } on UsernameTakenException {
        rethrow;
      } on UsernameClaimException catch (claimError) {
        if (allowSoftSkip && _canSoftSkipUsernameLock(claimError)) {
          debugPrint(
            'UsernameLockService: soft-skip claim lock: $claimError',
          );
          return;
        }
        if (_canSoftSkipUsernameLock(claimError)) {
          throw changeError;
        }
        rethrow;
      }
    } on UsernameTakenException {
      rethrow;
    }
  }

  bool _canSoftSkipUsernameLock(UsernameClaimException error) {
    final String code = (error.code ?? '').toLowerCase();
    return code == 'username_api' ||
        code == 'server' ||
        code == 'auth' ||
        code == 'account_not_provisioned' ||
        code == 'email_verification';
  }

  Future<void> _postUsernameApi({
    required Uri uri,
    required String idToken,
    required String username,
    required String action,
  }) async {
    final Map<String, String> headers =
        await buildAuthenticatedHttpHeaders(
      idToken: idToken,
      extra: const <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );
    final http.Response response = await _http
        .post(
          uri,
          headers: headers,
          body: jsonEncode(<String, dynamic>{'username': username}),
        )
        .timeout(const Duration(seconds: 25));
    final Map<String, dynamic> body = _decodeJsonMap(response.body);
    if (kDebugMode) {
      final String bodyPreview = response.body.length > 240
          ? '${response.body.substring(0, 240)}…'
          : response.body;
      debugPrint(
        'UsernameLockService: $action status=${response.statusCode} '
        'code=${body['code'] ?? body['error']} body=$bodyPreview',
      );
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (body['success'] == false) {
        _throwFromUsernameBody(body, username);
      }
      return;
    }
    _throwFromUsernameBody(body, username, statusCode: response.statusCode);
  }

  Map<String, dynamic> _decodeJsonMap(String raw) {
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return <String, dynamic>{};
  }

  Never _throwFromUsernameBody(
    Map<String, dynamic> body,
    String username, {
    int? statusCode,
  }) {
    final Object? errorObj = body['error'];
    final Map<String, dynamic>? errorMap = errorObj is Map
        ? Map<String, dynamic>.from(errorObj)
        : null;
    final String code = (
      (errorMap?['code'] as String?) ??
          (body['code'] as String?) ??
          ''
    ).trim();
    final String message = (
      (errorMap?['message'] as String?) ??
          (body['message'] as String?) ??
          ''
    ).trim();
    final String lowerMessage = message.toLowerCase();
    final String lowerCode = code.toLowerCase();
    if (statusCode == 401 ||
        lowerCode.contains('auth') ||
        lowerMessage.contains('unauthenticated')) {
      throw const UsernameClaimException(
        'Session expired. Sign in again, then create your profile.',
        code: 'auth',
      );
    }
    if (statusCode != null && statusCode >= 500) {
      throw const UsernameClaimException(
        'Username service temporarily unavailable. Try again in a moment.',
        code: 'server',
      );
    }
    if (lowerCode.contains('email_verification') ||
        lowerMessage.contains('email verification') ||
        lowerMessage.contains('verify your email')) {
      throw const UsernameClaimException(
        'Verify your email before choosing a username.',
        code: 'email_verification',
      );
    }
    if (lowerCode.contains('account_not_provisioned') ||
        lowerMessage.contains('account activation') ||
        lowerMessage.contains('not provisioned')) {
      throw const UsernameClaimException(
        'Complete account activation before claiming a username.',
        code: 'account_not_provisioned',
      );
    }
    if (lowerMessage.contains('already claimed') ||
        lowerMessage.contains('use changeusername')) {
      throw const UsernameClaimException(
        'Username already claimed. Use changeUsername instead.',
        code: 'already_claimed',
      );
    }
    if (statusCode == 409 ||
        lowerCode.contains('unavailable') ||
        lowerMessage.contains('taken') ||
        lowerMessage.contains('unavailable')) {
      throw UsernameTakenException(username);
    }
    throw UsernameClaimException(
      message.isNotEmpty
          ? message
          : 'Could not claim username. Try again.',
      code: code.isNotEmpty ? code : 'username_api',
    );
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
