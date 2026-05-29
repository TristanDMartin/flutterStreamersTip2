import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'sensitive_data_redactor.dart';

/// Maps errors to safe, user-visible messages without exposing UIDs or internals.
class UserFacingError {
  UserFacingError._();

  static const String _generic =
      'Something went wrong. Please try again.';

  static String message(Object? error) {
    if (error == null) {
      return _generic;
    }
    final String resolved = _resolve(error);
    if (kReleaseMode) {
      return _sanitizeForRelease(resolved);
    }
    return SensitiveDataRedactor.redactForDisplay(resolved);
  }

  static String _sanitizeForRelease(String resolved) {
    final String redacted = SensitiveDataRedactor.redactForDisplay(resolved);
    if (redacted.contains('[redacted]') || _looksLikeInternalLeak(redacted)) {
      return _generic;
    }
    return redacted;
  }

  static bool _looksLikeInternalLeak(String text) {
    final String lower = text.toLowerCase();
    return lower.contains('firebase') ||
        lower.contains('firestore') ||
        lower.contains('permission-denied') ||
        lower.contains('cloud_firestore') ||
        lower.contains('stacktrace') ||
        lower.contains('exception:') ||
        RegExp(r'\b[a-zA-Z0-9]{28}\b').hasMatch(text);
  }

  static String _resolve(Object error) {
    if (error is firebase_auth.FirebaseAuthException) {
      return _authMessage(error);
    }
    if (error is FirebaseException) {
      return _firebaseMessage(error);
    }
    if (error is StateError && error.message.isNotEmpty) {
      return error.message;
    }
    final String raw = error.toString();
    if (raw.startsWith('Exception: ')) {
      return raw.substring('Exception: '.length);
    }
    return _generic;
  }

  static String _authMessage(firebase_auth.FirebaseAuthException error) {
    switch (error.code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password is too weak. Use at least 8 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'requires-recent-login':
        return 'Please sign in again to continue.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      default:
        return error.message ?? _generic;
    }
  }

  static String _firebaseMessage(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'You do not have permission to perform this action.';
      case 'unavailable':
        return 'Service temporarily unavailable. Try again shortly.';
      case 'not-found':
        return 'The requested item could not be found.';
      case 'already-exists':
        return 'This item already exists.';
      case 'cancelled':
        return 'Operation was cancelled.';
      case 'deadline-exceeded':
      case 'timeout':
        return 'Request timed out. Please try again.';
      case 'resource-exhausted':
        return 'Service is busy. Please try again later.';
      case 'unauthenticated':
        return 'Please sign in to continue.';
      default:
        return _generic;
    }
  }
}
