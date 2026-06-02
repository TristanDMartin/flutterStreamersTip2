import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamers_tip/utils/secure_log.dart';

class ErrorHandlingService {
  static final ErrorHandlingService _instance =
      ErrorHandlingService._internal();
  factory ErrorHandlingService() => _instance;
  ErrorHandlingService._internal();

  // Error types
  static const String networkError = 'network_error';
  static const String serverError = 'server_error';
  static const String authError = 'auth_error';
  static const String videoError = 'video_error';
  static const String uploadError = 'upload_error';
  static const String cacheError = 'cache_error';
  static const String unknownError = 'unknown_error';

  // Connectivity monitoring
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isOnline = true;
  final StreamController<bool> _connectivityController =
      StreamController<bool>.broadcast();

  // Error tracking
  final List<AppError> _errorHistory = [];
  static const int _maxErrorHistory = 100;

  // Retry configuration
  static const int _maxRetryAttempts = 3;
  static const Duration _retryDelay = Duration(seconds: 2);
  final Map<String, int> _retryCounts = {};

  /// Initialize error handling service
  Future<void> initialize() async {
    // Start connectivity monitoring
    _startConnectivityMonitoring();

    // Load offline data
    await _loadOfflineData();

    secureLog('🛡️ Error handling service initialized');
  }

  /// Start monitoring network connectivity
  void _startConnectivityMonitoring() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        final wasOnline = _isOnline;
        _isOnline = results.contains(ConnectivityResult.mobile) ||
            results.contains(ConnectivityResult.wifi) ||
            results.contains(ConnectivityResult.ethernet);

        if (wasOnline != _isOnline) {
          _connectivityController.add(_isOnline);
          secureLog(
              '🌐 Connectivity changed: ${_isOnline ? "Online" : "Offline"}');

          if (_isOnline) {
            _handleReconnection();
          }
        }
      },
    );
  }

  /// Handle reconnection when coming back online
  void _handleReconnection() {
    secureLog('🔄 Handling reconnection...');
    // Retry failed operations
    _retryFailedOperations();
    // Sync offline data
    _syncOfflineData();
  }

  /// Check if device is online
  bool get isOnline => _isOnline;

  /// Get connectivity stream
  Stream<bool> get connectivityStream => _connectivityController.stream;

  /// Handle and categorize errors
  AppError handleError(dynamic error,
      {String? context, Map<String, dynamic>? metadata}) {
    final appError = _categorizeError(error, context, metadata);
    _logError(appError);
    _addToHistory(appError);
    return appError;
  }

  /// Categorize error based on type and content
  AppError _categorizeError(
      dynamic error, String? context, Map<String, dynamic>? metadata) {
    String type = unknownError;
    String message = 'An unexpected error occurred';
    int? statusCode;
    bool isRetryable = false;

    if (error is SocketException) {
      type = networkError;
      message = 'No internet connection. Please check your network settings.';
      isRetryable = true;
    } else if (error is HttpException) {
      type = serverError;
      message = 'Server error: ${error.message}';
      statusCode = 500;
      isRetryable = true;
    } else if (error is FormatException) {
      type = serverError;
      message = 'Invalid data format received from server';
      isRetryable = false;
    } else if (error is TimeoutException) {
      type = networkError;
      message = 'Request timed out. Please try again.';
      isRetryable = true;
    } else if (error.toString().contains('auth') ||
        error.toString().contains('permission')) {
      type = authError;
      message = 'Authentication failed. Please log in again.';
      isRetryable = false;
    } else if (error.toString().contains('video') ||
        error.toString().contains('player')) {
      type = videoError;
      message = 'Video playback error. Please try again.';
      isRetryable = true;
    } else if (error.toString().contains('upload')) {
      type = uploadError;
      message = 'Upload failed. Please check your connection and try again.';
      isRetryable = true;
    } else if (error.toString().contains('cache')) {
      type = cacheError;
      message = 'Cache error. Some features may not work properly.';
      isRetryable = true;
    }

    return AppError(
      type: type,
      message: message,
      originalError: error,
      context: context,
      metadata: metadata ?? {},
      statusCode: statusCode,
      isRetryable: isRetryable,
      timestamp: DateTime.now(),
    );
  }

  /// Log error for debugging
  void _logError(AppError error) {
    if (kDebugMode) {
      // appLog('❌ Error [${error.type}]: ${error.message}');
      if (error.originalError != null) {
        // appLog('   Original: ${error.originalError}');
      }
      if (error.context != null) {
        // appLog('   Context: ${error.context}');
      }
    }
  }

  /// Add error to history
  void _addToHistory(AppError error) {
    _errorHistory.add(error);
    if (_errorHistory.length > _maxErrorHistory) {
      _errorHistory.removeAt(0);
    }
  }

  /// Retry operation with exponential backoff
  Future<T?> retryOperation<T>(
    Future<T> Function() operation, {
    String? operationId,
    int? maxAttempts,
    Duration? delay,
  }) async {
    final id = operationId ?? DateTime.now().millisecondsSinceEpoch.toString();
    final attempts = maxAttempts ?? _maxRetryAttempts;
    final retryDelay = delay ?? _retryDelay;

    for (int attempt = 1; attempt <= attempts; attempt++) {
      try {
        if (!_isOnline && _requiresNetwork(operation)) {
          throw const SocketException('No internet connection');
        }

        final result = await operation();
        _retryCounts.remove(id);
        return result;
      } catch (e) {
        final error = handleError(e, context: 'retry_operation', metadata: {
          'operation_id': id,
          'attempt': attempt,
          'max_attempts': attempts,
        });

        if (attempt == attempts || !error.isRetryable) {
          _retryCounts.remove(id);
          rethrow;
        }

        if (kDebugMode) {
          // appLog('🔄 Retrying operation $id (attempt $attempt/$attempts)');
        }

        await Future.delayed(retryDelay * attempt);
      }
    }

    return null;
  }

  /// Check if operation requires network
  bool _requiresNetwork(Function operation) {
    // This is a simplified check - in production you might want to
    // annotate operations or use a more sophisticated approach
    return true;
  }

  /// Retry failed operations when back online
  void _retryFailedOperations() {
    // This would implement retry logic for failed operations
    // stored during offline mode
    secureLog('🔄 Retrying failed operations...');
  }

  /// Load offline data
  Future<void> _loadOfflineData() async {
    try {
      await SharedPreferences.getInstance();
      // Load offline data from SharedPreferences
      secureLog('📱 Loading offline data...');
    } catch (e) {
      secureLog('❌ Error loading offline data: $e');
    }
  }

  /// Sync offline data when back online
  void _syncOfflineData() {
    // This would implement sync logic for offline data
    secureLog('🔄 Syncing offline data...');
  }

  /// Show error dialog to user
  void showErrorDialog(BuildContext context, AppError error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_getErrorTitle(error.type)),
        content: Text(error.message),
        actions: [
          if (error.isRetryable)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Retry logic would be implemented here
              },
              child: const Text('Retry'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Show error snackbar
  void showErrorSnackBar(BuildContext context, AppError error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error.message),
        backgroundColor: _getErrorColor(error.type),
        action: error.isRetryable
            ? SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: () {
                  // Retry logic would be implemented here
                },
              )
            : null,
      ),
    );
  }

  /// Get error title based on type
  String _getErrorTitle(String type) {
    switch (type) {
      case networkError:
        return 'Connection Error';
      case serverError:
        return 'Server Error';
      case authError:
        return 'Authentication Error';
      case videoError:
        return 'Video Error';
      case uploadError:
        return 'Upload Error';
      case cacheError:
        return 'Cache Error';
      default:
        return 'Error';
    }
  }

  /// Get error color based on type
  Color _getErrorColor(String type) {
    switch (type) {
      case networkError:
        return Colors.orange;
      case serverError:
        return Colors.red;
      case authError:
        return Colors.purple;
      case videoError:
        return Colors.blue;
      case uploadError:
        return Colors.amber;
      case cacheError:
        return Colors.grey;
      default:
        return Colors.red;
    }
  }

  /// Get error history
  List<AppError> getErrorHistory() => List.from(_errorHistory);

  /// Clear error history
  void clearErrorHistory() {
    _errorHistory.clear();
  }

  /// Get error statistics
  ErrorStatistics getErrorStatistics() {
    final totalErrors = _errorHistory.length;
    final errorsByType = <String, int>{};
    final retryableErrors = _errorHistory.where((e) => e.isRetryable).length;

    for (final error in _errorHistory) {
      errorsByType[error.type] = (errorsByType[error.type] ?? 0) + 1;
    }

    return ErrorStatistics(
      totalErrors: totalErrors,
      errorsByType: errorsByType,
      retryableErrors: retryableErrors,
      isOnline: _isOnline,
    );
  }

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectivityController.close();
    _errorHistory.clear();
    _retryCounts.clear();
  }
}

/// App error data class
class AppError {
  final String type;
  final String message;
  final dynamic originalError;
  final String? context;
  final Map<String, dynamic> metadata;
  final int? statusCode;
  final bool isRetryable;
  final DateTime timestamp;

  AppError({
    required this.type,
    required this.message,
    this.originalError,
    this.context,
    this.metadata = const {},
    this.statusCode,
    this.isRetryable = false,
    required this.timestamp,
  });
}

/// Error statistics
class ErrorStatistics {
  final int totalErrors;
  final Map<String, int> errorsByType;
  final int retryableErrors;
  final bool isOnline;

  ErrorStatistics({
    required this.totalErrors,
    required this.errorsByType,
    required this.retryableErrors,
    required this.isOnline,
  });

  double get retryablePercentage =>
      totalErrors > 0 ? retryableErrors / totalErrors : 0.0;
}
