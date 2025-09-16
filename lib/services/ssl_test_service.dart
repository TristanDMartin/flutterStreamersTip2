import 'dart:io';
import 'package:flutter/foundation.dart';

/// SSL Test Service
/// 
/// This service provides utilities for testing SSL connections
/// and verifying that the SSL configuration is working properly.
class SSLTestService {
  /// Test SSL connection to a known HTTPS endpoint
  static Future<bool> testSSLConnection({String url = 'https://www.google.com'}) async {
    try {
      debugPrint('🔒 SSLTestService: Testing SSL connection to $url');
      
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      
      debugPrint('✅ SSLTestService: SSL connection successful (Status: ${response.statusCode})');
      client.close();
      return true;
    } catch (e) {
      debugPrint('❌ SSLTestService: SSL connection failed: $e');
      return false;
    }
  }

  /// Test Firebase SSL connection
  static Future<bool> testFirebaseSSL() async {
    try {
      debugPrint('🔒 SSLTestService: Testing Firebase SSL connection');
      
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse('https://firebase.googleapis.com'));
      final response = await request.close();
      
      debugPrint('✅ SSLTestService: Firebase SSL connection successful (Status: ${response.statusCode})');
      client.close();
      return true;
    } catch (e) {
      debugPrint('❌ SSLTestService: Firebase SSL connection failed: $e');
      return false;
    }
  }

  /// Run comprehensive SSL tests
  static Future<Map<String, bool>> runAllTests() async {
    debugPrint('🔒 SSLTestService: Running comprehensive SSL tests');
    
    final results = <String, bool>{};
    
    // Test basic HTTPS connection
    results['basic_https'] = await testSSLConnection();
    
    // Test Firebase connection
    results['firebase'] = await testFirebaseSSL();
    
    // Test Google APIs
    results['google_apis'] = await testSSLConnection(url: 'https://www.googleapis.com');
    
    debugPrint('🔒 SSLTestService: Test results: $results');
    return results;
  }
}
