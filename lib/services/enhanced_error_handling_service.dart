import 'package:flutter/material.dart';
import 'dart:async';

enum ErrorType {
  // Camera errors
  cameraPermissionDenied,
  cameraNotAvailable,
  cameraInitializationFailed,
  cameraRecordingFailed,
  cameraFocusFailed,
  cameraZoomFailed,
  cameraFlashFailed,

  // Video processing errors
  videoProcessingFailed,
  videoCompressionFailed,
  videoThumbnailFailed,
  videoDurationInvalid,
  videoSizeExceeded,
  videoFormatUnsupported,

  // Upload errors
  networkConnectionFailed,
  uploadTimeout,
  uploadFailed,
  storageQuotaExceeded,
  fileCorrupted,

  // Moderation errors
  moderationServiceUnavailable,
  moderationTimeout,
  moderationFailed,
  contentAnalysisFailed,

  // Authentication errors
  userNotAuthenticated,
  sessionExpired,
  permissionDenied,

  // General errors
  unknownError,
  systemError,
  configurationError,
}

class ErrorDetails {
  final ErrorType type;
  final String message;
  final String? technicalDetails;
  final Map<String, dynamic>? context;
  final DateTime timestamp;
  final String? stackTrace;
  final bool isRecoverable;
  final List<String> suggestedActions;

  const ErrorDetails({
    required this.type,
    required this.message,
    this.technicalDetails,
    this.context,
    required this.timestamp,
    this.stackTrace,
    this.isRecoverable = false,
    this.suggestedActions = const [],
  });

  String get userFriendlyMessage {
    switch (type) {
      case ErrorType.cameraPermissionDenied:
        return 'Camera access is required to record videos. Please enable camera permissions in your device settings.';
      case ErrorType.cameraNotAvailable:
        return 'Camera is not available on this device. Please try using a different device.';
      case ErrorType.cameraInitializationFailed:
        return 'Failed to initialize camera. Please restart the app and try again.';
      case ErrorType.cameraRecordingFailed:
        return 'Failed to start recording. Please check your device storage and try again.';
      case ErrorType.cameraFocusFailed:
        return 'Camera focus failed. Please try tapping on the screen to focus.';
      case ErrorType.cameraZoomFailed:
        return 'Camera zoom failed. Please try adjusting zoom again.';
      case ErrorType.cameraFlashFailed:
        return 'Camera flash failed. Please try toggling flash again.';

      case ErrorType.videoProcessingFailed:
        return 'Failed to process video. Please try recording again.';
      case ErrorType.videoCompressionFailed:
        return 'Failed to compress video. The file may be too large.';
      case ErrorType.videoThumbnailFailed:
        return 'Failed to generate video thumbnail. The video will upload without a preview.';
      case ErrorType.videoDurationInvalid:
        return 'Video duration is invalid. Please record a video between 1 second and 5 minutes.';
      case ErrorType.videoSizeExceeded:
        return 'Video file is too large. Please record a shorter video or reduce quality.';
      case ErrorType.videoFormatUnsupported:
        return 'Video format is not supported. Please try recording again.';

      case ErrorType.networkConnectionFailed:
        return 'No internet connection. Please check your network and try again.';
      case ErrorType.uploadTimeout:
        return 'Upload timed out. Please check your connection and try again.';
      case ErrorType.uploadFailed:
        return 'Upload failed. Please try again.';
      case ErrorType.storageQuotaExceeded:
        return 'Storage quota exceeded. Please contact support.';
      case ErrorType.fileCorrupted:
        return 'Video file is corrupted. Please record again.';

      case ErrorType.moderationServiceUnavailable:
        return 'Content moderation is temporarily unavailable. Please try again later.';
      case ErrorType.moderationTimeout:
        return 'Content moderation timed out. Please try again.';
      case ErrorType.moderationFailed:
        return 'Content moderation failed. Please try again.';
      case ErrorType.contentAnalysisFailed:
        return 'Content analysis failed. Please try again.';

      case ErrorType.userNotAuthenticated:
        return 'Please log in to upload videos.';
      case ErrorType.sessionExpired:
        return 'Your session has expired. Please log in again.';
      case ErrorType.permissionDenied:
        return 'You do not have permission to perform this action.';

      case ErrorType.unknownError:
        return 'An unexpected error occurred. Please try again.';
      case ErrorType.systemError:
        return 'A system error occurred. Please restart the app.';
      case ErrorType.configurationError:
        return 'App configuration error. Please contact support.';
    }
  }

  String get recoveryMessage {
    if (!isRecoverable) return 'This error cannot be recovered automatically.';

    switch (type) {
      case ErrorType.cameraPermissionDenied:
        return 'Go to Settings > Apps > StreamersTip > Permissions > Camera and enable access.';
      case ErrorType.networkConnectionFailed:
        return 'Check your Wi-Fi or mobile data connection.';
      case ErrorType.uploadTimeout:
        return 'Try uploading during off-peak hours or use a stronger connection.';
      case ErrorType.videoSizeExceeded:
        return 'Try recording a shorter video or reducing the quality.';
      case ErrorType.cameraInitializationFailed:
        return 'Close other camera apps and restart StreamersTip.';
      default:
        return 'Try the suggested actions below.';
    }
  }
}

class EnhancedErrorHandlingService {
  static final EnhancedErrorHandlingService _instance =
      EnhancedErrorHandlingService._internal();
  factory EnhancedErrorHandlingService() => _instance;
  EnhancedErrorHandlingService._internal();

  final List<ErrorDetails> _errorHistory = [];
  final StreamController<ErrorDetails> _errorStreamController =
      StreamController<ErrorDetails>.broadcast();

  Stream<ErrorDetails> get errorStream => _errorStreamController.stream;
  List<ErrorDetails> get errorHistory => List.unmodifiable(_errorHistory);

  /// Handle and log an error
  Future<void> handleError({
    required ErrorType type,
    required String message,
    String? technicalDetails,
    Map<String, dynamic>? context,
    String? stackTrace,
    bool isRecoverable = false,
    List<String> suggestedActions = const [],
  }) async {
    final errorDetails = ErrorDetails(
      type: type,
      message: message,
      technicalDetails: technicalDetails,
      context: context,
      timestamp: DateTime.now(),
      stackTrace: stackTrace,
      isRecoverable: isRecoverable,
      suggestedActions: suggestedActions,
    );

    // Add to history
    _errorHistory.add(errorDetails);

    // Emit to stream
    _errorStreamController.add(errorDetails);

    // Log to console for debugging
    // appLog('🚨 Error: ${errorDetails.type} - ${errorDetails.message}');
    if (technicalDetails != null) {
      // appLog('🔧 Technical: $technicalDetails');
    }
    if (context != null) {
      // appLog('📋 Context: $context');
    }

    // Store in persistent storage for analytics
    await _storeErrorForAnalytics(errorDetails);
  }

  /// Handle camera-specific errors
  Future<void> handleCameraError({
    required String operation,
    required dynamic error,
    Map<String, dynamic>? context,
  }) async {
    ErrorType errorType;
    String message;
    bool isRecoverable = false;
    List<String> suggestedActions = [];

    if (error.toString().contains('permission')) {
      errorType = ErrorType.cameraPermissionDenied;
      message = 'Camera permission denied during $operation';
      isRecoverable = true;
      suggestedActions = [
        'Enable camera permissions in device settings',
        'Restart the app after enabling permissions',
      ];
    } else if (error.toString().contains('not available') ||
        error.toString().contains('not found')) {
      errorType = ErrorType.cameraNotAvailable;
      message = 'Camera not available during $operation';
      suggestedActions = ['Try using a different device'];
    } else if (error.toString().contains('initialization') ||
        error.toString().contains('init')) {
      errorType = ErrorType.cameraInitializationFailed;
      message = 'Camera initialization failed during $operation';
      isRecoverable = true;
      suggestedActions = [
        'Close other camera apps',
        'Restart the app',
        'Check device storage space',
      ];
    } else if (error.toString().contains('recording') ||
        error.toString().contains('record')) {
      errorType = ErrorType.cameraRecordingFailed;
      message = 'Camera recording failed during $operation';
      isRecoverable = true;
      suggestedActions = [
        'Check device storage space',
        'Close other apps using camera',
        'Try recording again',
      ];
    } else if (error.toString().contains('focus')) {
      errorType = ErrorType.cameraFocusFailed;
      message = 'Camera focus failed during $operation';
      isRecoverable = true;
      suggestedActions = ['Tap on the screen to focus', 'Try again'];
    } else if (error.toString().contains('zoom')) {
      errorType = ErrorType.cameraZoomFailed;
      message = 'Camera zoom failed during $operation';
      isRecoverable = true;
      suggestedActions = ['Try adjusting zoom again'];
    } else if (error.toString().contains('flash')) {
      errorType = ErrorType.cameraFlashFailed;
      message = 'Camera flash failed during $operation';
      isRecoverable = true;
      suggestedActions = ['Try toggling flash again'];
    } else {
      errorType = ErrorType.unknownError;
      message = 'Unknown camera error during $operation: ${error.toString()}';
      isRecoverable = true;
      suggestedActions = ['Try again', 'Restart the app'];
    }

    await handleError(
      type: errorType,
      message: message,
      technicalDetails: error.toString(),
      context: {
        'operation': operation,
        ...?context,
      },
      isRecoverable: isRecoverable,
      suggestedActions: suggestedActions,
    );
  }

  /// Handle video processing errors
  Future<void> handleVideoProcessingError({
    required String operation,
    required dynamic error,
    Map<String, dynamic>? context,
  }) async {
    ErrorType errorType;
    String message;
    bool isRecoverable = false;
    List<String> suggestedActions = [];

    if (error.toString().contains('compression') ||
        error.toString().contains('encode')) {
      errorType = ErrorType.videoCompressionFailed;
      message = 'Video compression failed during $operation';
      isRecoverable = true;
      suggestedActions = [
        'Try recording a shorter video',
        'Reduce video quality',
        'Check device storage space',
      ];
    } else if (error.toString().contains('thumbnail') ||
        error.toString().contains('preview')) {
      errorType = ErrorType.videoThumbnailFailed;
      message = 'Video thumbnail generation failed during $operation';
      isRecoverable = true;
      suggestedActions = ['Video will upload without preview', 'Try again'];
    } else if (error.toString().contains('duration') ||
        error.toString().contains('length')) {
      errorType = ErrorType.videoDurationInvalid;
      message = 'Video duration is invalid during $operation';
      isRecoverable = true;
      suggestedActions = [
        'Record a video between 1 second and 5 minutes',
        'Try recording again',
      ];
    } else if (error.toString().contains('size') ||
        error.toString().contains('large')) {
      errorType = ErrorType.videoSizeExceeded;
      message = 'Video file size exceeded during $operation';
      isRecoverable = true;
      suggestedActions = [
        'Record a shorter video',
        'Reduce video quality',
        'Check device storage space',
      ];
    } else if (error.toString().contains('format') ||
        error.toString().contains('unsupported')) {
      errorType = ErrorType.videoFormatUnsupported;
      message = 'Video format not supported during $operation';
      isRecoverable = true;
      suggestedActions = ['Try recording again', 'Check device compatibility'];
    } else {
      errorType = ErrorType.videoProcessingFailed;
      message =
          'Video processing failed during $operation: ${error.toString()}';
      isRecoverable = true;
      suggestedActions = ['Try recording again', 'Restart the app'];
    }

    await handleError(
      type: errorType,
      message: message,
      technicalDetails: error.toString(),
      context: {
        'operation': operation,
        ...?context,
      },
      isRecoverable: isRecoverable,
      suggestedActions: suggestedActions,
    );
  }

  /// Handle upload errors
  Future<void> handleUploadError({
    required String operation,
    required dynamic error,
    Map<String, dynamic>? context,
  }) async {
    ErrorType errorType;
    String message;
    bool isRecoverable = false;
    List<String> suggestedActions = [];

    if (error.toString().contains('network') ||
        error.toString().contains('connection') ||
        error.toString().contains('internet')) {
      errorType = ErrorType.networkConnectionFailed;
      message = 'Network connection failed during $operation';
      isRecoverable = true;
      suggestedActions = [
        'Check your internet connection',
        'Try switching between Wi-Fi and mobile data',
        'Try again when connection is stable',
      ];
    } else if (error.toString().contains('timeout') ||
        error.toString().contains('timed out')) {
      errorType = ErrorType.uploadTimeout;
      message = 'Upload timed out during $operation';
      isRecoverable = true;
      suggestedActions = [
        'Check your internet connection',
        'Try uploading during off-peak hours',
        'Try a shorter video',
      ];
    } else if (error.toString().contains('quota') ||
        error.toString().contains('storage')) {
      errorType = ErrorType.storageQuotaExceeded;
      message = 'Storage quota exceeded during $operation';
      isRecoverable = false;
      suggestedActions = ['Contact support for assistance'];
    } else if (error.toString().contains('corrupted') ||
        error.toString().contains('invalid')) {
      errorType = ErrorType.fileCorrupted;
      message = 'Video file is corrupted during $operation';
      isRecoverable = true;
      suggestedActions = ['Record the video again', 'Try a different video'];
    } else {
      errorType = ErrorType.uploadFailed;
      message = 'Upload failed during $operation: ${error.toString()}';
      isRecoverable = true;
      suggestedActions = ['Try again', 'Check your connection'];
    }

    await handleError(
      type: errorType,
      message: message,
      technicalDetails: error.toString(),
      context: {
        'operation': operation,
        ...?context,
      },
      isRecoverable: isRecoverable,
      suggestedActions: suggestedActions,
    );
  }

  /// Handle moderation errors
  Future<void> handleModerationError({
    required String operation,
    required dynamic error,
    Map<String, dynamic>? context,
  }) async {
    ErrorType errorType;
    String message;
    bool isRecoverable = false;
    List<String> suggestedActions = [];

    if (error.toString().contains('unavailable') ||
        error.toString().contains('service')) {
      errorType = ErrorType.moderationServiceUnavailable;
      message = 'Moderation service unavailable during $operation';
      isRecoverable = true;
      suggestedActions = ['Try again later', 'Save as draft for now'];
    } else if (error.toString().contains('timeout') ||
        error.toString().contains('timed out')) {
      errorType = ErrorType.moderationTimeout;
      message = 'Moderation timed out during $operation';
      isRecoverable = true;
      suggestedActions = ['Try again', 'Check your connection'];
    } else if (error.toString().contains('analysis') ||
        error.toString().contains('content')) {
      errorType = ErrorType.contentAnalysisFailed;
      message = 'Content analysis failed during $operation';
      isRecoverable = true;
      suggestedActions = ['Try again', 'Save as draft for now'];
    } else {
      errorType = ErrorType.moderationFailed;
      message = 'Moderation failed during $operation: ${error.toString()}';
      isRecoverable = true;
      suggestedActions = ['Try again', 'Save as draft for now'];
    }

    await handleError(
      type: errorType,
      message: message,
      technicalDetails: error.toString(),
      context: {
        'operation': operation,
        ...?context,
      },
      isRecoverable: isRecoverable,
      suggestedActions: suggestedActions,
    );
  }

  /// Show error dialog to user
  Future<void> showErrorDialog({
    required BuildContext context,
    required ErrorDetails errorDetails,
    VoidCallback? onRetry,
    VoidCallback? onCancel,
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: Row(
            children: [
              Icon(
                _getErrorIcon(errorDetails.type),
                color: _getErrorColor(errorDetails.type),
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _getErrorTitle(errorDetails.type),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  errorDetails.userFriendlyMessage,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                if (errorDetails.isRecoverable) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'How to fix:',
                          style: TextStyle(
                            color: Colors.blue,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          errorDetails.recoveryMessage,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (errorDetails.suggestedActions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Suggested actions:',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...errorDetails.suggestedActions.map((action) => Padding(
                        padding: const EdgeInsets.only(left: 8, top: 2),
                        child: Text(
                          '• $action',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      )),
                ],
              ],
            ),
          ),
          actions: [
            if (onCancel != null)
              TextButton(
                onPressed: onCancel,
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            if (errorDetails.isRecoverable && onRetry != null)
              TextButton(
                onPressed: onRetry,
                child: const Text(
                  'Try Again',
                  style: TextStyle(color: Color(0xFF9248D2)),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'OK',
                style: TextStyle(color: Color(0xFF9248D2)),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Get error icon based on error type
  IconData _getErrorIcon(ErrorType type) {
    switch (type) {
      case ErrorType.cameraPermissionDenied:
      case ErrorType.cameraNotAvailable:
      case ErrorType.cameraInitializationFailed:
      case ErrorType.cameraRecordingFailed:
      case ErrorType.cameraFocusFailed:
      case ErrorType.cameraZoomFailed:
      case ErrorType.cameraFlashFailed:
        return Icons.camera_alt;
      case ErrorType.videoProcessingFailed:
      case ErrorType.videoCompressionFailed:
      case ErrorType.videoThumbnailFailed:
      case ErrorType.videoDurationInvalid:
      case ErrorType.videoSizeExceeded:
      case ErrorType.videoFormatUnsupported:
        return Icons.videocam;
      case ErrorType.networkConnectionFailed:
      case ErrorType.uploadTimeout:
      case ErrorType.uploadFailed:
        return Icons.cloud_upload;
      case ErrorType.moderationServiceUnavailable:
      case ErrorType.moderationTimeout:
      case ErrorType.moderationFailed:
      case ErrorType.contentAnalysisFailed:
        return Icons.security;
      case ErrorType.userNotAuthenticated:
      case ErrorType.sessionExpired:
      case ErrorType.permissionDenied:
        return Icons.person;
      default:
        return Icons.error;
    }
  }

  /// Get error color based on error type
  Color _getErrorColor(ErrorType type) {
    switch (type) {
      case ErrorType.cameraPermissionDenied:
      case ErrorType.userNotAuthenticated:
      case ErrorType.sessionExpired:
        return Colors.orange;
      case ErrorType.networkConnectionFailed:
      case ErrorType.uploadTimeout:
        return Colors.blue;
      case ErrorType.storageQuotaExceeded:
      case ErrorType.fileCorrupted:
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  /// Get error title based on error type
  String _getErrorTitle(ErrorType type) {
    switch (type) {
      case ErrorType.cameraPermissionDenied:
        return 'Camera Access Required';
      case ErrorType.cameraNotAvailable:
        return 'Camera Not Available';
      case ErrorType.cameraInitializationFailed:
        return 'Camera Error';
      case ErrorType.cameraRecordingFailed:
        return 'Recording Failed';
      case ErrorType.videoProcessingFailed:
        return 'Video Processing Error';
      case ErrorType.networkConnectionFailed:
        return 'Connection Error';
      case ErrorType.uploadTimeout:
        return 'Upload Timeout';
      case ErrorType.uploadFailed:
        return 'Upload Failed';
      case ErrorType.moderationServiceUnavailable:
        return 'Moderation Unavailable';
      case ErrorType.userNotAuthenticated:
        return 'Authentication Required';
      case ErrorType.storageQuotaExceeded:
        return 'Storage Full';
      default:
        return 'Error';
    }
  }

  /// Store error for analytics
  Future<void> _storeErrorForAnalytics(ErrorDetails errorDetails) async {
    // This would store errors in a local database or send to analytics service
    // For now, just print to console
    // appLog('📊 Error Analytics: ${errorDetails.type} at ${errorDetails.timestamp}');
  }

  /// Clear error history
  void clearErrorHistory() {
    _errorHistory.clear();
  }

  /// Get errors by type
  List<ErrorDetails> getErrorsByType(ErrorType type) {
    return _errorHistory.where((error) => error.type == type).toList();
  }

  /// Get recent errors
  List<ErrorDetails> getRecentErrors({int limit = 10}) {
    final sortedErrors = List<ErrorDetails>.from(_errorHistory)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sortedErrors.take(limit).toList();
  }

  /// Dispose resources
  void dispose() {
    _errorStreamController.close();
  }
}
