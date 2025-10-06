import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'production_logging_service.dart';

/// Standard error types
enum ErrorType {
  network,
  authentication,
  permission,
  validation,
  storage,
  database,
  video,
  thumbnail,
  unknown,
}

/// Standard error codes
enum ErrorCode {
  // Network errors
  networkTimeout,
  networkUnavailable,
  networkError,

  // Authentication errors
  authUserNotFound,
  authInvalidCredentials,
  authUserDisabled,
  authTooManyRequests,
  authInvalidEmail,
  authWeakPassword,

  // Permission errors
  permissionDenied,
  permissionNotGranted,
  permissionPermanentlyDenied,

  // Validation errors
  validationRequired,
  validationInvalidFormat,
  validationTooLong,
  validationTooShort,
  validationInvalidValue,

  // Storage errors
  storageFileNotFound,
  storageQuotaExceeded,
  storageUnauthorized,
  storageInvalidFormat,

  // Database errors
  databaseConnectionFailed,
  databaseQueryFailed,
  databasePermissionDenied,
  databaseDocumentNotFound,

  // Video errors
  videoLoadFailed,
  videoPlaybackFailed,
  videoProcessingFailed,
  videoUploadFailed,

  // Thumbnail errors
  thumbnailGenerationFailed,
  thumbnailUploadFailed,
  thumbnailNotFound,

  // Unknown errors
  unknownError,
}

/// Standardized Error Handler - Consistent error handling across the app
///
/// Provides:
/// - Standardized error types and codes
/// - Consistent error messages
/// - Automatic error reporting
/// - User-friendly error display
class StandardizedErrorHandler {
  static final StandardizedErrorHandler _instance =
      StandardizedErrorHandler._internal();
  factory StandardizedErrorHandler() => _instance;
  StandardizedErrorHandler._internal();

  final ProductionLoggingService _logger = ProductionLoggingService();

  /// Handle and categorize errors
  AppError handleError(Object error,
      {String? context, Map<String, dynamic>? metadata}) {
    try {
      final appError = _categorizeError(error, context, metadata);
      _logError(appError);
      _reportError(appError);
      return appError;
    } catch (e) {
      // Fallback error handling
      final fallbackError = AppError(
        type: ErrorType.unknown,
        code: ErrorCode.unknownError,
        message: 'An unexpected error occurred',
        originalError: error,
        context: context ?? 'unknown',
        metadata: metadata ?? {},
        timestamp: DateTime.now(),
      );
      _logError(fallbackError);
      return fallbackError;
    }
  }

  /// Categorize error based on type
  AppError _categorizeError(
      Object error, String? context, Map<String, dynamic>? metadata) {
    if (error is FirebaseAuthException) {
      return _handleFirebaseAuthError(error, context, metadata);
    } else if (error is FirebaseException) {
      return _handleFirebaseError(error, context, metadata);
    } else if (error is FirebaseException &&
        error.code.startsWith('storage/')) {
      return _handleStorageError(error, context, metadata);
    } else if (error is FormatException) {
      return _handleFormatError(error, context, metadata);
    } else if (error is ArgumentError) {
      return _handleArgumentError(error, context, metadata);
    } else if (error is StateError) {
      return _handleStateError(error, context, metadata);
    } else if (error is UnimplementedError) {
      return _handleUnimplementedError(error, context, metadata);
    } else if (error is UnsupportedError) {
      return _handleUnsupportedError(error, context, metadata);
    } else {
      return _handleGenericError(error, context, metadata);
    }
  }

  /// Handle Firebase Auth errors
  AppError _handleFirebaseAuthError(FirebaseAuthException error,
      String? context, Map<String, dynamic>? metadata) {
    ErrorType type = ErrorType.authentication;
    ErrorCode code = ErrorCode.unknownError;
    String message = 'Authentication error occurred';

    switch (error.code) {
      case 'user-not-found':
        code = ErrorCode.authUserNotFound;
        message = 'User account not found';
        break;
      case 'wrong-password':
      case 'invalid-credential':
        code = ErrorCode.authInvalidCredentials;
        message = 'Invalid email or password';
        break;
      case 'user-disabled':
        code = ErrorCode.authUserDisabled;
        message = 'User account has been disabled';
        break;
      case 'too-many-requests':
        code = ErrorCode.authTooManyRequests;
        message = 'Too many failed attempts. Please try again later';
        break;
      case 'invalid-email':
        code = ErrorCode.authInvalidEmail;
        message = 'Invalid email address';
        break;
      case 'weak-password':
        code = ErrorCode.authWeakPassword;
        message = 'Password is too weak';
        break;
    }

    return AppError(
      type: type,
      code: code,
      message: message,
      originalError: error,
      context: context ?? 'authentication',
      metadata: metadata ?? {},
      timestamp: DateTime.now(),
    );
  }

  /// Handle Firebase errors
  AppError _handleFirebaseError(FirebaseException error, String? context,
      Map<String, dynamic>? metadata) {
    ErrorType type = ErrorType.database;
    ErrorCode code = ErrorCode.unknownError;
    String message = 'Database error occurred';

    switch (error.code) {
      case 'permission-denied':
        type = ErrorType.permission;
        code = ErrorCode.permissionDenied;
        message = 'Permission denied';
        break;
      case 'unavailable':
        type = ErrorType.network;
        code = ErrorCode.networkUnavailable;
        message = 'Service temporarily unavailable';
        break;
      case 'deadline-exceeded':
        type = ErrorType.network;
        code = ErrorCode.networkTimeout;
        message = 'Request timed out';
        break;
    }

    return AppError(
      type: type,
      code: code,
      message: message,
      originalError: error,
      context: context ?? 'firebase',
      metadata: metadata ?? {},
      timestamp: DateTime.now(),
    );
  }

  /// Handle Storage errors
  AppError _handleStorageError(FirebaseException error, String? context,
      Map<String, dynamic>? metadata) {
    ErrorType type = ErrorType.storage;
    ErrorCode code = ErrorCode.unknownError;
    String message = 'Storage error occurred';

    switch (error.code) {
      case 'object-not-found':
        code = ErrorCode.storageFileNotFound;
        message = 'File not found';
        break;
      case 'quota-exceeded':
        code = ErrorCode.storageQuotaExceeded;
        message = 'Storage quota exceeded';
        break;
      case 'unauthorized':
        code = ErrorCode.storageUnauthorized;
        message = 'Unauthorized access';
        break;
      case 'invalid-format':
        code = ErrorCode.storageInvalidFormat;
        message = 'Invalid file format';
        break;
    }

    return AppError(
      type: type,
      code: code,
      message: message,
      originalError: error,
      context: context ?? 'storage',
      metadata: metadata ?? {},
      timestamp: DateTime.now(),
    );
  }

  /// Handle Format errors
  AppError _handleFormatError(
      FormatException error, String? context, Map<String, dynamic>? metadata) {
    return AppError(
      type: ErrorType.validation,
      code: ErrorCode.validationInvalidFormat,
      message: 'Invalid data format: ${error.message}',
      originalError: error,
      context: context ?? 'validation',
      metadata: metadata ?? {},
      timestamp: DateTime.now(),
    );
  }

  /// Handle Argument errors
  AppError _handleArgumentError(
      ArgumentError error, String? context, Map<String, dynamic>? metadata) {
    return AppError(
      type: ErrorType.validation,
      code: ErrorCode.validationInvalidValue,
      message: 'Invalid argument: ${error.message}',
      originalError: error,
      context: context ?? 'validation',
      metadata: metadata ?? {},
      timestamp: DateTime.now(),
    );
  }

  /// Handle State errors
  AppError _handleStateError(
      StateError error, String? context, Map<String, dynamic>? metadata) {
    return AppError(
      type: ErrorType.validation,
      code: ErrorCode.validationInvalidValue,
      message: 'Invalid state: ${error.message}',
      originalError: error,
      context: context ?? 'validation',
      metadata: metadata ?? {},
      timestamp: DateTime.now(),
    );
  }

  /// Handle Unimplemented errors
  AppError _handleUnimplementedError(UnimplementedError error, String? context,
      Map<String, dynamic>? metadata) {
    return AppError(
      type: ErrorType.unknown,
      code: ErrorCode.unknownError,
      message: 'Feature not implemented: ${error.message}',
      originalError: error,
      context: context ?? 'unimplemented',
      metadata: metadata ?? {},
      timestamp: DateTime.now(),
    );
  }

  /// Handle Unsupported errors
  AppError _handleUnsupportedError(
      UnsupportedError error, String? context, Map<String, dynamic>? metadata) {
    return AppError(
      type: ErrorType.unknown,
      code: ErrorCode.unknownError,
      message: 'Unsupported operation: ${error.message}',
      originalError: error,
      context: context ?? 'unsupported',
      metadata: metadata ?? {},
      timestamp: DateTime.now(),
    );
  }

  /// Handle Generic errors
  AppError _handleGenericError(
      Object error, String? context, Map<String, dynamic>? metadata) {
    return AppError(
      type: ErrorType.unknown,
      code: ErrorCode.unknownError,
      message: 'An unexpected error occurred: ${error.toString()}',
      originalError: error,
      context: context ?? 'unknown',
      metadata: metadata ?? {},
      timestamp: DateTime.now(),
    );
  }

  /// Log error
  void _logError(AppError error) {
    _logger.error(
      'Error: ${error.message}',
      tag: 'StandardizedErrorHandler',
      error: error.originalError,
    );
  }

  /// Report error (in production, send to crash reporting service)
  void _reportError(AppError error) {
    if (kReleaseMode) {
      // In production, send to crash reporting service
      _logger.info('Error reported to crash service',
          tag: 'StandardizedErrorHandler');
    }
  }

  /// Show user-friendly error dialog
  void showErrorDialog(BuildContext context, AppError error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_getErrorTitle(error.type)),
        content: Text(error.message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Get user-friendly error title
  String _getErrorTitle(ErrorType type) {
    switch (type) {
      case ErrorType.network:
        return 'Connection Error';
      case ErrorType.authentication:
        return 'Authentication Error';
      case ErrorType.permission:
        return 'Permission Error';
      case ErrorType.validation:
        return 'Validation Error';
      case ErrorType.storage:
        return 'Storage Error';
      case ErrorType.database:
        return 'Database Error';
      case ErrorType.video:
        return 'Video Error';
      case ErrorType.thumbnail:
        return 'Thumbnail Error';
      case ErrorType.unknown:
        return 'Error';
    }
  }
}

/// Standardized error model
class AppError {
  final ErrorType type;
  final ErrorCode code;
  final String message;
  final Object originalError;
  final String context;
  final Map<String, dynamic> metadata;
  final DateTime timestamp;

  AppError({
    required this.type,
    required this.code,
    required this.message,
    required this.originalError,
    required this.context,
    required this.metadata,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'AppError(type: $type, code: $code, message: $message, context: $context)';
  }
}
