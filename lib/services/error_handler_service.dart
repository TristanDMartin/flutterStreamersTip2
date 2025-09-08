import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'analytics_service.dart';

class ErrorHandlerService {
  static ErrorHandlerService? _instance;
  static ErrorHandlerService get instance => _instance ??= ErrorHandlerService._();
  
  ErrorHandlerService._();
  
  // Initialize error handling
  void initialize() {
    // Handle Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      _handleFlutterError(details);
    };
    
    // Handle platform errors
    PlatformDispatcher.instance.onError = (error, stack) {
      _handlePlatformError(error, stack);
      return true;
    };
    
    debugPrint('✅ Error handler service initialized');
  }
  
  // Handle Flutter framework errors
  void _handleFlutterError(FlutterErrorDetails details) {
    debugPrint('🚨 Flutter Error: ${details.exception}');
    debugPrint('📍 Stack trace: ${details.stack}');
    
    // Track error in analytics
    AnalyticsService.instance.trackError(
      details.exception.toString(),
      details.stack,
      fatal: false,
    );
    
    // Show user-friendly error message
    _showErrorSnackBar('Something went wrong. Please try again.');
  }
  
  // Handle platform errors
  void _handlePlatformError(Object error, StackTrace stack) {
    debugPrint('🚨 Platform Error: $error');
    debugPrint('📍 Stack trace: $stack');
    
    // Track error in analytics
    AnalyticsService.instance.trackError(
      error.toString(),
      stack,
      fatal: true,
    );
    
    // Show user-friendly error message
    _showErrorSnackBar('A system error occurred. Please restart the app.');
  }
  
  // Handle network errors
  void handleNetworkError(String endpoint, int statusCode, String message) {
    debugPrint('🌐 Network Error: $endpoint ($statusCode) - $message');
    
    // Track network error
    AnalyticsService.instance.trackError(
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
    AnalyticsService.instance.trackError(
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
    AnalyticsService.instance.trackError(
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
    AnalyticsService.instance.trackError(
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
    AnalyticsService.instance.trackError(
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
    AnalyticsService.instance.trackError(
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
    AnalyticsService.instance.trackError(
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
    AnalyticsService.instance.trackError(
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
  void handleError(Object error, StackTrace? stackTrace, {BuildContext? context, String? tag}) {
    debugPrint('🚨 Generic Error: $error');
    if (stackTrace != null) {
      debugPrint('📍 Stack trace: $stackTrace');
    }
    
    // Track error in analytics
    AnalyticsService.instance.trackError(
      error.toString(),
      stackTrace,
      fatal: false,
    );
    
    // Show user-friendly error message
    _showErrorSnackBar('An error occurred. Please try again.');
  }

  // Handle specific error types
  void handleSpecificError(String errorType, String message, {StackTrace? stackTrace}) {
    debugPrint('🚨 $errorType Error: $message');
    
    // Track specific error
    AnalyticsService.instance.trackError(
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
}
