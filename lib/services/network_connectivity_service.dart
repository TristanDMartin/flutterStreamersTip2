import 'dart:io';
import 'package:flutter/foundation.dart';

class NetworkConnectivityService {
  static final NetworkConnectivityService _instance =
      NetworkConnectivityService._internal();
  factory NetworkConnectivityService() => _instance;
  NetworkConnectivityService._internal();

  bool _isConnected = true;
  bool get isConnected => _isConnected;

  /// Check if the device has internet connectivity
  Future<bool> checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      _isConnected = result.isNotEmpty && result[0].rawAddress.isNotEmpty;

      if (!_isConnected) {
        debugPrint(
            '🌐 NetworkConnectivityService: No internet connection detected');
      } else {
        debugPrint(
            '🌐 NetworkConnectivityService: Internet connection confirmed');
      }

      return _isConnected;
    } catch (e) {
      debugPrint(
          '🌐 NetworkConnectivityService: Connectivity check failed: $e');
      _isConnected = false;
      return false;
    }
  }

  /// Check Firebase connectivity specifically
  Future<bool> checkFirebaseConnectivity() async {
    try {
      final result = await InternetAddress.lookup('firestore.googleapis.com');
      final isFirebaseConnected =
          result.isNotEmpty && result[0].rawAddress.isNotEmpty;

      if (!isFirebaseConnected) {
        debugPrint(
            '🔥 NetworkConnectivityService: Firebase connectivity failed');
      } else {
        debugPrint(
            '🔥 NetworkConnectivityService: Firebase connectivity confirmed');
      }

      return isFirebaseConnected;
    } catch (e) {
      debugPrint(
          '🔥 NetworkConnectivityService: Firebase connectivity check failed: $e');
      return false;
    }
  }

  /// Retry mechanism for network operations
  Future<T> retryOperation<T>(
    Future<T> Function() operation, {
    int maxRetries = 3,
    Duration delay = const Duration(seconds: 2),
  }) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        // Check connectivity before attempting operation
        if (!await checkConnectivity()) {
          throw Exception('No internet connection');
        }

        return await operation();
      } catch (e) {
        debugPrint(
            '🔄 NetworkConnectivityService: Attempt $attempt failed: $e');

        if (attempt == maxRetries) {
          rethrow;
        }

        // Wait before retrying
        await Future.delayed(delay * attempt);
      }
    }

    throw Exception('All retry attempts failed');
  }
}
