import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import '../utils/sensitive_data_redactor.dart';

class StorageDiagnosticService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final firebase_auth.FirebaseAuth _auth =
      firebase_auth.FirebaseAuth.instance;

  /// Test Firebase Storage connectivity and configuration
  static Future<Map<String, dynamic>> runDiagnostics() async {
    final results = <String, dynamic>{};

    try {
      debugPrint('🔍 Starting Firebase Storage diagnostics...');

      // Test 1: Check Firebase Storage instance
      results['storage_instance'] = _storage.app.name;
      results['storage_bucket'] = _storage.bucket;
      debugPrint('✅ Storage instance: ${_storage.app.name}');
      debugPrint('✅ Storage bucket: ${_storage.bucket}');

      // Test 2: Check authentication
      final user = _auth.currentUser;
      results['user_authenticated'] = user != null;
      if (kDebugMode && user != null) {
        results['user_id'] = user.uid;
      }
      if (user != null) {
        debugPrint('✅ User authenticated: ${user.uid}');
      } else {
        debugPrint('❌ User not authenticated');
      }

      // Test 3: Test basic Storage access
      try {
        final testRef = _storage.ref().child('diagnostic_test');
        await testRef.getMetadata();
        results['storage_access'] = 'success';
        debugPrint('✅ Storage access test passed');
      } catch (e) {
        if (e.toString().contains('object-not-found')) {
          results['storage_access'] =
              'success'; // This is expected for a test file
          debugPrint(
              '✅ Storage access test passed (object-not-found is expected)');
        } else {
          results['storage_access'] = 'failed';
          results['storage_access_error'] = e.toString();
          debugPrint('❌ Storage access test failed: $e');
        }
      }

      // Test 4: Test write permissions
      try {
        final testRef = _storage.ref().child('diagnostic_test_write');
        final testData = 'Firebase Storage diagnostic test';
        final uploadTask = testRef.putString(testData);
        await uploadTask;
        results['storage_write'] = 'success';
        debugPrint('✅ Storage write test passed');

        // Clean up test file
        try {
          await testRef.delete();
          debugPrint('✅ Test file cleaned up');
        } catch (e) {
          debugPrint('⚠️ Could not clean up test file: $e');
        }
      } catch (e) {
        results['storage_write'] = 'failed';
        results['storage_write_error'] = e.toString();
        debugPrint('❌ Storage write test failed: $e');
      }

      // Test 5: Check Storage rules
      try {
        final testRef = _storage.ref().child('avatars/test');
        await testRef.getMetadata();
        results['storage_rules'] = 'permissive';
        debugPrint('✅ Storage rules test passed');
      } catch (e) {
        if (e.toString().contains('storage/object-not-found')) {
          results['storage_rules'] = 'restrictive';
          debugPrint(
              '⚠️ Storage rules are restrictive (expected for test file)');
        } else {
          results['storage_rules'] = 'error';
          results['storage_rules_error'] = e.toString();
          debugPrint('❌ Storage rules test failed: $e');
        }
      }

      results['overall_status'] = 'completed';
      debugPrint('🎉 Firebase Storage diagnostics completed');
    } catch (e) {
      results['overall_status'] = 'failed';
      results['diagnostic_error'] = e.toString();
      debugPrint('❌ Diagnostics failed: $e');
    }

    return results;
  }

  /// Get detailed error recommendations
  static String getRecommendations(Map<String, dynamic> results) {
    final recommendations = <String>[];

    if (results['user_authenticated'] == false) {
      recommendations.add('• User is not authenticated. Please sign in first.');
    }

    if (results['storage_access'] == 'failed') {
      final error = results['storage_access_error'] ?? '';
      if (error.contains('bucket-not-found')) {
        recommendations.add(
            '• Firebase Storage bucket not found. Please set up Storage in Firebase Console.');
      } else if (error.contains('project-not-found')) {
        recommendations.add(
            '• Firebase project not found. Please check your Firebase configuration.');
      } else if (error.contains('unauthorized')) {
        recommendations.add(
            '• Storage access unauthorized. Please check your Firebase Storage rules.');
      } else if (error.contains('object-not-found')) {
        // This is actually expected for the test file
        recommendations.add('• Storage access is working correctly.');
      } else {
        recommendations.add(
          '• Storage access failed: '
          '${SensitiveDataRedactor.redact(error)}',
        );
      }
    }

    if (results['storage_write'] == 'failed') {
      final error = results['storage_write_error'] ?? '';
      if (error.contains('unauthorized')) {
        recommendations.add(
            '• Storage write unauthorized. Please check your Firebase Storage rules.');
      } else if (error.contains('quota-exceeded')) {
        recommendations.add(
            '• Storage quota exceeded. Please check your Firebase project limits.');
      } else {
        recommendations.add(
          '• Storage write failed: '
          '${SensitiveDataRedactor.redact(error)}',
        );
      }
    }

    if (results['storage_rules'] == 'error') {
      recommendations.add(
          '• Storage rules configuration error. Please check your storage.rules file.');
    }

    if (recommendations.isEmpty) {
      recommendations.add(
          '• All diagnostics passed! Firebase Storage should be working correctly.');
    }

    return recommendations.join('\n');
  }
}
