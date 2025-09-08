import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../services/content_moderation_service.dart';

/// Service for server-side content validation
class ServerValidationService {
  static final ServerValidationService _instance = ServerValidationService._internal();
  factory ServerValidationService() => _instance;
  ServerValidationService._internal();

  // TODO: Replace with your actual API endpoint
  static const String _baseUrl = 'https://your-api-domain.com/api';
  static const String _validationEndpoint = '/validate-content';

  /// Validate content on the server
  Future<ModerationResult> validateContent(String content) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final token = await user.getIdToken();
      
      final response = await http.post(
        Uri.parse('$_baseUrl$_validationEndpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'content': content,
          'userId': user.uid,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ModerationResult(
          isAllowed: data['isAllowed'] ?? true,
          reason: data['reason'],
          matchedTerms: List<String>.from(data['matchedTerms'] ?? []),
          ruleId: data['ruleId'],
          severity: _parseSeverity(data['severity']),
        );
      } else {
        // If server validation fails, fall back to client-side validation
        return await ContentModerationService().checkContent(content);
      }
    } catch (e) {
      print('Server validation error: $e');
      // Fall back to client-side validation
      return await ContentModerationService().checkContent(content);
    }
  }

  /// Submit content for manual review
  Future<bool> submitForReview({
    required String content,
    required String reason,
    String? additionalNotes,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final token = await user.getIdToken();
      
      final response = await http.post(
        Uri.parse('$_baseUrl/submit-review'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'content': content,
          'reason': reason,
          'additionalNotes': additionalNotes,
          'userId': user.uid,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error submitting for review: $e');
      return false;
    }
  }

  /// Get moderation rules from server
  Future<Map<String, dynamic>> getModerationRules() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final token = await user.getIdToken();
      
      final response = await http.get(
        Uri.parse('$_baseUrl/moderation-rules'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to fetch moderation rules');
      }
    } catch (e) {
      print('Error fetching moderation rules: $e');
      return {};
    }
  }

  /// Report false positive
  Future<bool> reportFalsePositive({
    required String content,
    required String ruleId,
    required String explanation,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final token = await user.getIdToken();
      
      final response = await http.post(
        Uri.parse('$_baseUrl/report-false-positive'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'content': content,
          'ruleId': ruleId,
          'explanation': explanation,
          'userId': user.uid,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error reporting false positive: $e');
      return false;
    }
  }

  ModerationSeverity _parseSeverity(String? severity) {
    switch (severity?.toLowerCase()) {
      case 'low':
        return ModerationSeverity.low;
      case 'medium':
        return ModerationSeverity.medium;
      case 'high':
        return ModerationSeverity.high;
      case 'critical':
        return ModerationSeverity.critical;
      default:
        return ModerationSeverity.low;
    }
  }
}
