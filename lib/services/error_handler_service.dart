import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'analytics_service.dart';
import '../utils/sensitive_data_redactor.dart';
import 'network_error_handler.dart';

class ErrorHandlerService {
  static ErrorHandlerService? _instance;
  static ErrorHandlerService get instance =>
      _instance ??= ErrorHandlerService._();

  ErrorHandlerService._();

  static bool _isIgnorableFirestorePermissionDenied(Object error) {
    return error is FirebaseException &&
        error.plugin == 'cloud_firestore' &&
        error.code == 'permission-denied';
  }

  static bool _isIgnorableFrameworkLifecycleError(Object error) {
    final String text = error.toString();
    return text.contains('Multiple widgets used the same GlobalKey') ||
        text.contains('Duplicate GlobalKey') ||
        text.contains('deactivated widget') ||
        text.contains(
          'Tried to modify a provider while the widget tree was building',
        );
  }

  // Initialize error handling (chains with Crashlytics handlers from main).
  void initialize() {
    final FlutterExceptionHandler? priorFlutter = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      priorFlutter?.call(details);
      _handleFlutterError(details);
    };

    final bool Function(Object, StackTrace)? priorPlatform =
        PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      priorPlatform?.call(error, stack);
      _handlePlatformError(error, stack);
      return true;
    };

    debugPrint('✅ Error handler service initialized');
  }

  // Handle Flutter framework errors
  void _handleFlutterError(FlutterErrorDetails details) {
    debugPrint('🚨 Flutter Error: ${details.exception}');
    debugPrint('📍 Stack trace: ${details.stack}');
    if (_isIgnorableFirestorePermissionDenied(details.exception)) {
      debugPrint(
        'ℹ️ Firestore permission-denied (no global snackbar): '
        '${details.exception}',
      );
      return;
    }
    if (_isIgnorableFrameworkLifecycleError(details.exception)) {
      debugPrint(
        'ℹ️ Framework lifecycle error (no global snackbar): '
        '${details.exception}',
      );
      return;
    }

    // Check if it's a network-related error
    String userMessage;
    if (NetworkErrorHandler.isNetworkError(details.exception)) {
      userMessage = NetworkErrorHandler.getErrorMessage(details.exception);
      debugPrint(
          '🌐 Network Error: ${NetworkErrorHandler.getDebugMessage(details.exception)}');
    } else {
      userMessage = 'Something went wrong. Please try again.';
    }

    // ✅ FIX: Only track error in analytics if Firebase is initialized
    _safeTrackError(
      details.exception.toString(),
      details.stack,
      fatal: false,
    );

    // Show user-friendly error message
    _showErrorSnackBar(userMessage);
  }

  // Handle platform errors
  void _handlePlatformError(Object error, StackTrace stack) {
    debugPrint('🚨 Platform Error: $error');
    debugPrint('📍 Stack trace: $stack');
    if (_isIgnorableFirestorePermissionDenied(error)) {
      debugPrint('ℹ️ Firestore permission-denied (no global snackbar): $error');
      return;
    }
    if (_isIgnorableFrameworkLifecycleError(error)) {
      debugPrint('ℹ️ Framework lifecycle error (no global snackbar): $error');
      return;
    }

    // Check if it's a network-related error
    String userMessage;
    if (NetworkErrorHandler.isNetworkError(error)) {
      userMessage = NetworkErrorHandler.getErrorMessage(error);
      debugPrint(
          '🌐 Network Error: ${NetworkErrorHandler.getDebugMessage(error)}');
    } else {
      userMessage = 'A system error occurred. Please restart the app.';
    }

    // ✅ FIX: Only track error in analytics if Firebase is initialized
    _safeTrackError(
      error.toString(),
      stack,
      fatal: true,
    );

    // Show user-friendly error message
    _showErrorSnackBar(userMessage);
  }

  // Handle network errors
  void handleNetworkError(String endpoint, int statusCode, String message) {
    debugPrint('🌐 Network Error: $endpoint ($statusCode) - $message');

    // Track network error
    _safeTrackError(
      'Network Error: $endpoint ($statusCode) - $message',
      null,
      fatal: false,
    );

    // Show appropriate error message
    String userMessage;
    switch (statusCode) {
      case 400:
        userMessage = 'Invalid request. Please check your input.';
        break;
      case 401:
        userMessage = 'Authentication failed. Please log in again.';
        break;
      case 403:
        userMessage = 'Access denied. You don\'t have permission.';
        break;
      case 404:
        userMessage = 'Resource not found.';
        break;
      case 500:
        userMessage = 'Server error. Please try again later.';
        break;
      case 503:
        userMessage = 'Service unavailable. Please try again later.';
        break;
      default:
        userMessage = 'Network error. Please check your connection.';
    }

    _showErrorSnackBar(userMessage);
  }

  // Handle database errors
  void handleDatabaseError(String operation, String message) {
    debugPrint('🗄️ Database Error: $operation - $message');

    // Track database error
    _safeTrackError(
      'Database Error: $operation - $message',
      null,
      fatal: false,
    );

    _showErrorSnackBar('Data error. Please try again.');
  }

  // Handle authentication errors
  void handleAuthError(String message) {
    debugPrint('🔐 Auth Error: $message');

    // Track auth error
    _safeTrackError(
      'Auth Error: $message',
      null,
      fatal: false,
    );

    _showErrorSnackBar('Authentication failed. Please log in again.');
  }

  // Handle validation errors
  void handleValidationError(String field, String message) {
    debugPrint('✅ Validation Error: $field - $message');

    // Track validation error
    _safeTrackError(
      'Validation Error: $field - $message',
      null,
      fatal: false,
    );

    _showErrorSnackBar('Invalid $field: $message');
  }

  // Handle file upload errors
  void handleFileUploadError(String fileName, String message) {
    debugPrint('📁 File Upload Error: $fileName - $message');

    // Track file upload error
    _safeTrackError(
      'File Upload Error: $fileName - $message',
      null,
      fatal: false,
    );

    _showErrorSnackBar('Failed to upload $fileName. Please try again.');
  }

  // Handle image processing errors
  void handleImageProcessingError(String imageUrl, String message) {
    debugPrint('🖼️ Image Processing Error: $imageUrl - $message');

    // Track image processing error
    _safeTrackError(
      'Image Processing Error: $imageUrl - $message',
      null,
      fatal: false,
    );

    _showErrorSnackBar('Failed to process image. Please try again.');
  }

  // Handle memory errors
  void handleMemoryError(String operation, int memoryUsageMB) {
    debugPrint('💾 Memory Error: $operation - ${memoryUsageMB}MB');

    // Track memory error
    _safeTrackError(
      'Memory Error: $operation - ${memoryUsageMB}MB',
      null,
      fatal: false,
    );

    _showErrorSnackBar('Memory error. Please restart the app.');
  }

  // Handle permission errors
  void handlePermissionError(String permission, String message) {
    debugPrint('🔒 Permission Error: $permission - $message');

    // Track permission error
    _safeTrackError(
      'Permission Error: $permission - $message',
      null,
      fatal: false,
    );

    _showErrorSnackBar('Permission denied: $permission');
  }

  // Show error snackbar
  void _showErrorSnackBar(String message) {
    // This would typically use a global navigator key or context
    // For now, just log the message
    debugPrint('📱 Error Snackbar: $message');
  }

  // Generic error handler
  void handleError(Object error, StackTrace? stackTrace,
      {BuildContext? context, String? tag}) {
    debugPrint('🚨 Generic Error: $error');
    if (stackTrace != null) {
      debugPrint('📍 Stack trace: $stackTrace');
    }

    // Track error in analytics
    _safeTrackError(
      error.toString(),
      stackTrace,
      fatal: false,
    );

    // Show user-friendly error message
    _showErrorSnackBar('An error occurred. Please try again.');
  }

  // Handle specific error types
  void handleSpecificError(String errorType, String message,
      {StackTrace? stackTrace}) {
    debugPrint('🚨 $errorType Error: $message');

    // Track specific error
    _safeTrackError(
      '$errorType Error: $message',
      stackTrace,
      fatal: false,
    );

    // Show appropriate error message
    String userMessage;
    switch (errorType) {
      case 'NullCheck':
        userMessage = 'Data error. Please refresh and try again.';
        break;
      case 'RenderFlex':
        userMessage = 'Layout error. Please restart the app.';
        break;
      case 'ImageReader':
        userMessage = 'Image loading error. Please try again.';
        break;
      case 'GoogleApiManager':
        userMessage = 'Service error. Please try again later.';
        break;
      default:
        userMessage = 'An error occurred. Please try again.';
    }

    _showErrorSnackBar(userMessage);
  }

  // Handle SSL certificate errors specifically
  void handleSSLError(dynamic error) {
    debugPrint('🔒 SSL Error: ${NetworkErrorHandler.getDebugMessage(error)}');

    // Track SSL error in analytics
    _safeTrackError(
      'SSL Error: ${error.toString()}',
      null,
      fatal: false,
    );

    // Show user-friendly SSL error message
    _showErrorSnackBar(NetworkErrorHandler.getErrorMessage(error));
  }

  // Handle recovery actions
  void handleRecoveryAction(String action, VoidCallback callback) {
    try {
      callback();
      debugPrint('✅ Recovery action successful: $action');
    } catch (e) {
      debugPrint('❌ Recovery action failed: $action - $e');
      _showErrorSnackBar('Recovery failed. Please restart the app.');
    }
  }

  // Get error context
  Map<String, dynamic> getErrorContext() {
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'platform': defaultTargetPlatform.name,
      'isDebug': kDebugMode,
      'isProfile': kProfileMode,
      'isRelease': kReleaseMode,
    };
  }

  // ✅ FIX: Safe error tracking that only works if Firebase is initialized
  void _safeTrackError(String error, StackTrace? stackTrace,
      {bool fatal = false}) {
    final String safeError =
        kReleaseMode ? SensitiveDataRedactor.redact(error) : error;
    if (!AnalyticsService.isReady) {
      debugPrint('📊 Error (Crashlytics not ready): $safeError');
      return;
    }
    AnalyticsService.instance.trackError(safeError, stackTrace, fatal: fatal);
  }
}
