import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/scheduled_post.dart';

class SchedulingBackendService {
  static const String _baseUrl = 'https://your-backend-endpoint.com/api';
  String? _authToken;
  Timer? _pollingTimer;
  final StreamController<ScheduledPost> _postStatusController =
      StreamController<ScheduledPost>.broadcast();

  Stream<ScheduledPost> get postStatusStream => _postStatusController.stream;

  void setAuthToken(String token) {
    _authToken = token;
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_authToken != null) 'Authorization': 'Bearer $_authToken',
      };

  // Start polling for post status updates
  void startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _pollForUpdates();
    });
  }

  // Stop polling
  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  // Poll for post status updates
  Future<void> _pollForUpdates() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/posts/status-updates'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> updates = jsonDecode(response.body)['updates'];
        for (final update in updates) {
          final post = ScheduledPost.fromJson(update);
          _postStatusController.add(post);
        }
      }
    } catch (e) {
      // Handle polling errors silently to avoid disrupting the app
      debugPrint('Polling error: $e');
    }
  }

  // Process scheduled posts (called by backend cron job)
  Future<void> processScheduledPosts() async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/scheduler/process'),
        headers: _headers,
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to process scheduled posts: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error processing scheduled posts: $e');
    }
  }

  // Upload media to platform-specific storage
  Future<Map<String, String>> uploadMediaToPlatforms({
    required String postId,
    required List<PostMedia> media,
    required List<PlatformKey> platforms,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/media/upload-to-platforms'),
      headers: _headers,
      body: jsonEncode({
        'postId': postId,
        'media': media.map((m) => m.toJson()).toList(),
        'platforms': platforms.map((p) => p.name).toList(),
      }),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      return data.map((key, value) => MapEntry(key, value as String));
    } else {
      throw Exception('Failed to upload media: ${response.body}');
    }
  }

  // Generate platform-specific media variants
  Future<List<MediaVariant>> generateMediaVariants({
    required PostMedia media,
    required List<PlatformKey> platforms,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/media/generate-variants'),
      headers: _headers,
      body: jsonEncode({
        'media': media.toJson(),
        'platforms': platforms.map((p) => p.name).toList(),
      }),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body)['variants'];
      return data.map((json) => MediaVariant.fromJson(json)).toList();
    } else {
      throw Exception('Failed to generate media variants: ${response.body}');
    }
  }

  // Publish to a specific platform
  Future<Map<String, dynamic>> publishToPlatform({
    required String postId,
    required PlatformKey platform,
    required Map<String, dynamic> platformData,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/publish/$platform'),
      headers: _headers,
      body: jsonEncode({
        'postId': postId,
        'platformData': platformData,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to publish to $platform: ${response.body}');
    }
  }

  // Get platform-specific publishing status
  Future<Map<String, dynamic>> getPlatformPublishingStatus({
    required String postId,
    required PlatformKey platform,
  }) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/publish/$platform/$postId/status'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get publishing status: ${response.body}');
    }
  }

  // Retry failed platform publishing
  Future<void> retryPlatformPublishing({
    required String postId,
    required PlatformKey platform,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/publish/$platform/$postId/retry'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to retry publishing: ${response.body}');
    }
  }

  // Validate platform tokens and scopes
  Future<Map<String, bool>> validatePlatformTokens() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/platforms/validate-tokens'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      return data.map((key, value) => MapEntry(key, value as bool));
    } else {
      throw Exception('Failed to validate platform tokens: ${response.body}');
    }
  }

  // Refresh platform tokens
  Future<void> refreshPlatformToken(PlatformKey platform) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/platforms/$platform/refresh-token'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to refresh token: ${response.body}');
    }
  }

  // Get content moderation results
  Future<Map<String, dynamic>> getContentModerationResults({
    required String postId,
  }) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/moderation/$postId'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get moderation results: ${response.body}');
    }
  }

  // Submit content for moderation
  Future<void> submitForModeration({
    required String postId,
    required String caption,
    required List<PostMedia> media,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/moderation/submit'),
      headers: _headers,
      body: jsonEncode({
        'postId': postId,
        'caption': caption,
        'media': media.map((m) => m.toJson()).toList(),
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to submit for moderation: ${response.body}');
    }
  }

  // Get analytics data for best posting times
  Future<Map<String, dynamic>> getBestPostingTimesAnalytics({
    required List<PlatformKey> platforms,
    int? daysAhead,
  }) async {
    final queryParams = <String, String>{
      'platforms': platforms.map((p) => p.name).join(','),
    };

    if (daysAhead != null) queryParams['daysAhead'] = daysAhead.toString();

    final uri = Uri.parse('$_baseUrl/analytics/best-times')
        .replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get analytics: ${response.body}');
    }
  }

  // Send push notification
  Future<void> sendPushNotification({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/notifications/send'),
      headers: _headers,
      body: jsonEncode({
        'userId': userId,
        'title': title,
        'body': body,
        'data': data ?? {},
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to send notification: ${response.body}');
    }
  }

  // Log analytics event
  Future<void> logAnalyticsEvent({
    required String eventName,
    required Map<String, dynamic> properties,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/analytics/log'),
      headers: _headers,
      body: jsonEncode({
        'eventName': eventName,
        'properties': properties,
        'timestamp': DateTime.now().toIso8601String(),
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to log analytics: ${response.body}');
    }
  }

  // Get system health status
  Future<Map<String, dynamic>> getSystemHealth() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/health'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get system health: ${response.body}');
    }
  }

  // Cleanup old posts and logs
  Future<void> cleanupOldData({
    int? daysToKeep,
  }) async {
    final queryParams = <String, String>{};
    if (daysToKeep != null) queryParams['daysToKeep'] = daysToKeep.toString();

    final uri =
        Uri.parse('$_baseUrl/cleanup').replace(queryParameters: queryParams);
    final response = await http.post(uri, headers: _headers);

    if (response.statusCode != 200) {
      throw Exception('Failed to cleanup data: ${response.body}');
    }
  }

  void dispose() {
    _pollingTimer?.cancel();
    _postStatusController.close();
  }
}
