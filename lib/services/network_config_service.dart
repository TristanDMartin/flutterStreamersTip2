import 'dart:io';
import 'package:flutter/foundation.dart';

/// Network Configuration Service
/// 
/// This service handles network configuration issues including SSL certificate
/// verification problems that commonly occur in development environments.
class NetworkConfigService {
  static bool _isInitialized = false;

  /// Initialize network configuration for development
  /// This should be called early in the app lifecycle
  static void initialize() {
    if (_isInitialized) return;
    
    if (kDebugMode) {
      _configureForDevelopment();
    }
    
    _isInitialized = true;
  }

  /// Configure network settings for development environment
  static void _configureForDevelopment() {
    try {
      // Override certificate verification for development
      // WARNING: This should NEVER be used in production
      HttpOverrides.global = _DevelopmentHttpOverrides();
      
      debugPrint('🔧 NetworkConfigService: Development SSL configuration applied');
    } catch (e) {
      debugPrint('❌ NetworkConfigService: Failed to configure SSL: $e');
    }
  }

  /// Reset to default network configuration
  static void reset() {
    HttpOverrides.global = null;
    _isInitialized = false;
    debugPrint('🔧 NetworkConfigService: Network configuration reset');
  }
}

/// Custom HttpOverrides for development environment
/// This bypasses SSL certificate verification for development only
class _DevelopmentHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    
    // Only apply in debug mode
    if (kDebugMode) {
      // Bypass certificate verification for development
      client.badCertificateCallback = (X509Certificate cert, String host, int port) {
        debugPrint('🔧 DevelopmentHttpOverrides: Bypassing certificate verification for $host:$port');
        return true; // Accept all certificates in development
      };
    }
    
    return client;
  }
}
