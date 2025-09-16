import 'dart:io';

/// Network Error Handler
/// 
/// This service provides utilities for handling network-related errors,
/// including SSL certificate issues and connection problems.
class NetworkErrorHandler {
  /// Check if an error is related to SSL certificate verification
  static bool isSSLError(dynamic error) {
    if (error is HandshakeException) {
      return error.toString().contains('CERTIFICATE_VERIFY_FAILED') ||
             error.toString().contains('Hostname mismatch') ||
             error.toString().contains('handshake error');
    }
    return false;
  }

  /// Check if an error is related to network connectivity
  static bool isNetworkError(dynamic error) {
    if (error is SocketException) {
      return true;
    }
    
    if (error is HttpException) {
      return true;
    }
    
    if (error is HandshakeException) {
      return true;
    }
    
    return false;
  }

  /// Get a user-friendly error message for network issues
  static String getErrorMessage(dynamic error) {
    if (isSSLError(error)) {
      return 'Network security verification failed. Please check your internet connection and try again.';
    }
    
    if (error is SocketException) {
      switch (error.osError?.errorCode) {
        case 7: // No address associated with hostname
          return 'Unable to connect to server. Please check your internet connection.';
        case 8: // Name or service not known
          return 'Server not found. Please check your internet connection.';
        case 101: // Network is unreachable
          return 'Network is unreachable. Please check your internet connection.';
        case 111: // Connection refused
          return 'Connection refused by server. Please try again later.';
        default:
          return 'Network connection failed. Please check your internet connection.';
      }
    }
    
    if (error is HttpException) {
      return 'HTTP request failed. Please try again.';
    }
    
    if (error is HandshakeException) {
      return 'Secure connection failed. Please check your internet connection.';
    }
    
    return 'Network error occurred. Please try again.';
  }

  /// Get a debug-friendly error message for logging
  static String getDebugMessage(dynamic error) {
    if (error is SocketException) {
      return 'SocketException: ${error.message} (Error Code: ${error.osError?.errorCode})';
    }
    
    if (error is HttpException) {
      return 'HttpException: ${error.message}';
    }
    
    if (error is HandshakeException) {
      return 'HandshakeException: ${error.message}';
    }
    
    return 'Network Error: ${error.toString()}';
  }

  /// Check if the error should be retried
  static bool shouldRetry(dynamic error) {
    if (isSSLError(error)) {
      return false; // SSL errors usually indicate configuration issues
    }
    
    if (error is SocketException) {
      final errorCode = error.osError?.errorCode;
      // Retry for temporary network issues
      return errorCode == 101 || // Network unreachable
             errorCode == 111 || // Connection refused
             errorCode == 110;   // Connection timed out
    }
    
    if (error is HttpException) {
      return true; // HTTP errors might be temporary
    }
    
    return false;
  }

  /// Get retry delay in seconds based on error type
  static int getRetryDelaySeconds(dynamic error) {
    if (error is SocketException) {
      final errorCode = error.osError?.errorCode;
      switch (errorCode) {
        case 101: // Network unreachable
          return 5;
        case 111: // Connection refused
          return 10;
        case 110: // Connection timed out
          return 3;
        default:
          return 2;
      }
    }
    
    if (error is HttpException) {
      return 3;
    }
    
    return 1;
  }
}
