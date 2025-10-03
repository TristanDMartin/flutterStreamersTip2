import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/scheduled_post.dart';

class ScheduledPostService {
  // Mock implementation for development - replace with real API when ready
  static const bool _useMockData = true;
  static const String _baseUrl = 'https://your-api-endpoint.com/api';
  String? _authToken;

  void setAuthToken(String token) {
    _authToken = token;
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_authToken != null) 'Authorization': 'Bearer $_authToken',
      };

  // Create a new scheduled post
  Future<ScheduledPost> createScheduledPost({
    required String caption,
    required List<String> tags,
    required PostVisibility visibility,
    required List<PostMedia> media,
    required List<PlatformConfig> platforms,
    required PostSchedule schedule,
    Map<String, dynamic>? analyticsHints,
  }) async {
    if (_useMockData) {
      await Future.delayed(
          const Duration(milliseconds: 800)); // Simulate network delay
      return ScheduledPost(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        authorId: 'user123',
        status: PostStatus.scheduled,
        caption: caption,
        tags: tags,
        visibility: visibility,
        media: media,
        platforms: platforms,
        schedule: schedule,
        analyticsHints: analyticsHints ?? {},
        idempotencyKey: DateTime.now().millisecondsSinceEpoch.toString(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/posts'),
      headers: _headers,
      body: jsonEncode({
        'caption': caption,
        'tags': tags,
        'visibility': visibility.name,
        'media': media.map((m) => m.toJson()).toList(),
        'platforms': platforms.map((p) => p.toJson()).toList(),
        'schedule': schedule.toJson(),
        'analyticsHints': analyticsHints ?? {},
        'idempotencyKey': DateTime.now().millisecondsSinceEpoch.toString(),
      }),
    );

    if (response.statusCode == 201) {
      return ScheduledPost.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to create scheduled post: ${response.body}');
    }
  }

  // Get scheduled posts with optional filters
  Future<List<ScheduledPost>> getScheduledPosts({
    PostStatus? status,
    PlatformKey? platform,
    String? searchQuery,
    int? limit,
    int? offset,
  }) async {
    if (_useMockData) {
      // Return mock data for development
      await Future.delayed(
          const Duration(milliseconds: 500)); // Simulate network delay
      return _getMockScheduledPosts(status, platform, searchQuery);
    }

    final queryParams = <String, String>{};

    if (status != null) queryParams['status'] = status.name;
    if (platform != null) queryParams['platform'] = platform.name;
    if (searchQuery != null) queryParams['search'] = searchQuery;
    if (limit != null) queryParams['limit'] = limit.toString();
    if (offset != null) queryParams['offset'] = offset.toString();

    final uri =
        Uri.parse('$_baseUrl/posts').replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body)['posts'];
      return data.map((json) => ScheduledPost.fromJson(json)).toList();
    } else {
      throw Exception('Failed to fetch scheduled posts: ${response.body}');
    }
  }

  // Get a specific post by ID
  Future<ScheduledPost> getPost(String postId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/posts/$postId'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      return ScheduledPost.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to fetch post: ${response.body}');
    }
  }

  // Update a scheduled post
  Future<ScheduledPost> updatePost(
    String postId, {
    String? caption,
    List<String>? tags,
    PostVisibility? visibility,
    List<PostMedia>? media,
    List<PlatformConfig>? platforms,
    PostSchedule? schedule,
  }) async {
    final updateData = <String, dynamic>{};

    if (caption != null) updateData['caption'] = caption;
    if (tags != null) updateData['tags'] = tags;
    if (visibility != null) updateData['visibility'] = visibility.name;
    if (media != null) {
      updateData['media'] = media.map((m) => m.toJson()).toList();
    }
    if (platforms != null) {
      updateData['platforms'] = platforms.map((p) => p.toJson()).toList();
    }
    if (schedule != null) updateData['schedule'] = schedule.toJson();

    final response = await http.patch(
      Uri.parse('$_baseUrl/posts/$postId'),
      headers: _headers,
      body: jsonEncode(updateData),
    );

    if (response.statusCode == 200) {
      return ScheduledPost.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to update post: ${response.body}');
    }
  }

  // Schedule a post
  Future<ScheduledPost> schedulePost(String postId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/posts/$postId/schedule'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      return ScheduledPost.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to schedule post: ${response.body}');
    }
  }

  // Reschedule a post
  Future<ScheduledPost> reschedulePost(
      String postId, PostSchedule newSchedule) async {
    final response = await http.patch(
      Uri.parse('$_baseUrl/posts/$postId/reschedule'),
      headers: _headers,
      body: jsonEncode({'schedule': newSchedule.toJson()}),
    );

    if (response.statusCode == 200) {
      return ScheduledPost.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to reschedule post: ${response.body}');
    }
  }

  // Publish a post immediately
  Future<ScheduledPost> publishNow(String postId) async {
    if (_useMockData) {
      await Future.delayed(
          const Duration(milliseconds: 1000)); // Simulate publishing delay
      // Return a mock published post
      return ScheduledPost(
        id: postId,
        authorId: 'user123',
        status: PostStatus.published,
        caption: 'Mock published post',
        tags: ['published'],
        visibility: PostVisibility.public,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        media: [],
        platforms: [],
        schedule: PostSchedule(
          scheduledAtUtc: DateTime.now(),
          timezone: 'UTC',
          perPlatform: {},
          createdAtUtc: DateTime.now(),
          updatedAtUtc: DateTime.now(),
        ),
        analyticsHints: {},
        idempotencyKey: postId,
      );
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/posts/$postId/publishNow'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      return ScheduledPost.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to publish post: ${response.body}');
    }
  }

  // Cancel a scheduled post
  Future<ScheduledPost> cancelPost(String postId) async {
    if (_useMockData) {
      await Future.delayed(const Duration(milliseconds: 500));
      // Return a mock canceled post
      return ScheduledPost(
        id: postId,
        authorId: 'user123',
        status: PostStatus.canceled,
        caption: 'Mock canceled post',
        tags: ['canceled'],
        visibility: PostVisibility.public,
        media: [],
        platforms: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        schedule: PostSchedule(
          scheduledAtUtc: DateTime.now(),
          timezone: 'UTC',
          perPlatform: {},
          createdAtUtc: DateTime.now(),
          updatedAtUtc: DateTime.now(),
        ),
        analyticsHints: {},
        idempotencyKey: postId,
      );
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/posts/$postId/cancel'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      return ScheduledPost.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to cancel post: ${response.body}');
    }
  }

  // Retry a failed post
  Future<ScheduledPost> retryPost(String postId) async {
    if (_useMockData) {
      await Future.delayed(const Duration(milliseconds: 800));
      // Return a mock retry post
      return ScheduledPost(
        id: postId,
        authorId: 'user123',
        status: PostStatus.scheduled,
        caption: 'Mock retry post',
        tags: ['retry'],
        visibility: PostVisibility.public,
        media: [],
        platforms: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        schedule: PostSchedule(
          scheduledAtUtc: DateTime.now().add(const Duration(hours: 1)),
          timezone: 'UTC',
          perPlatform: {},
          createdAtUtc: DateTime.now(),
          updatedAtUtc: DateTime.now(),
        ),
        analyticsHints: {},
        idempotencyKey: postId,
      );
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/posts/$postId/retry'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      return ScheduledPost.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to retry post: ${response.body}');
    }
  }

  // Get post analytics
  Future<Map<String, dynamic>> getPostAnalytics(String postId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/posts/$postId/analytics'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch analytics: ${response.body}');
    }
  }

  // Get best posting times based on analytics
  Future<List<DateTime>> getBestPostingTimes({
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
      final List<dynamic> data = jsonDecode(response.body)['times'];
      return data
          .map((timestamp) => DateTime.fromMillisecondsSinceEpoch(timestamp))
          .toList();
    } else {
      throw Exception('Failed to fetch best posting times: ${response.body}');
    }
  }

  // Validate scheduling constraints
  Future<Map<String, dynamic>> validateSchedule({
    required DateTime scheduledAt,
    required List<PlatformKey> platforms,
    required String timezone,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/posts/validate-schedule'),
      headers: _headers,
      body: jsonEncode({
        'scheduledAt': scheduledAt.toIso8601String(),
        'platforms': platforms.map((p) => p.name).toList(),
        'timezone': timezone,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to validate schedule: ${response.body}');
    }
  }

  // Get platform connection status
  Future<Map<String, bool>> getPlatformConnections() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/platforms/connections'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      return data.map((key, value) => MapEntry(key, value as bool));
    } else {
      throw Exception('Failed to fetch platform connections: ${response.body}');
    }
  }

  // Reconnect a platform
  Future<void> reconnectPlatform(PlatformKey platform) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/platforms/${platform.name}/reconnect'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to reconnect platform: ${response.body}');
    }
  }

  // Delete a post
  Future<void> deletePost(String postId) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/posts/$postId'),
      headers: _headers,
    );

    if (response.statusCode != 204) {
      throw Exception('Failed to delete post: ${response.body}');
    }
  }

  // Get post publishing history
  Future<List<Map<String, dynamic>>> getPublishingHistory(String postId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/posts/$postId/history'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body)['history'];
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to fetch publishing history: ${response.body}');
    }
  }

  // Mock data for development
  List<ScheduledPost> _getMockScheduledPosts(
      PostStatus? status, PlatformKey? platform, String? searchQuery) {
    final mockPosts = [
      ScheduledPost(
        id: '1',
        authorId: 'user123',
        status: PostStatus.scheduled,
        caption: 'Excited to share my latest video! 🎥✨',
        tags: ['video', 'content', 'creator'],
        visibility: PostVisibility.public,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
        media: [
          PostMedia(
            id: 'media1',
            type: MediaType.video,
            src: 'https://example.com/video1.mp4',
            aspectRatio: 9.0 / 16.0,
            durationMs: 30000,
            variants: [],
          ),
        ],
        platforms: [
          PlatformConfig(
            key: PlatformKey.youtube.name,
            enabled: true,
            status: PlatformStatus.pending,
            payload: {'title': 'My Amazing Video'},
          ),
          PlatformConfig(
            key: PlatformKey.tiktok.name,
            enabled: true,
            status: PlatformStatus.pending,
            payload: {'description': 'Check this out!'},
          ),
        ],
        schedule: PostSchedule(
          scheduledAtUtc: DateTime.now().add(const Duration(hours: 2)),
          timezone: 'America/New_York',
          perPlatform: {},
          createdAtUtc: DateTime.now().subtract(const Duration(hours: 1)),
          updatedAtUtc: DateTime.now().subtract(const Duration(minutes: 30)),
        ),
        analyticsHints: {'bestTime': 'evening'},
        idempotencyKey: 'key1',
      ),
      ScheduledPost(
        id: '2',
        authorId: 'user123',
        status: PostStatus.publishing,
        caption: 'Behind the scenes content coming up! 📸',
        tags: ['behind_the_scenes', 'exclusive'],
        visibility: PostVisibility.public,
        createdAt: DateTime.now().subtract(const Duration(hours: 6)),
        updatedAt: DateTime.now().subtract(const Duration(minutes: 30)),
        media: [
          PostMedia(
            id: 'media2',
            type: MediaType.image,
            src: 'https://example.com/image1.jpg',
            aspectRatio: 1.0,
            durationMs: null,
            variants: [],
          ),
        ],
        platforms: [
          PlatformConfig(
            key: PlatformKey.instagram.name,
            enabled: true,
            status: PlatformStatus.publishing,
            payload: {'caption': 'Behind the scenes!'},
          ),
        ],
        schedule: PostSchedule(
          scheduledAtUtc: DateTime.now().subtract(const Duration(minutes: 5)),
          timezone: 'America/New_York',
          perPlatform: {},
          createdAtUtc: DateTime.now().subtract(const Duration(hours: 2)),
          updatedAtUtc: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
        analyticsHints: {},
        idempotencyKey: 'key2',
      ),
      ScheduledPost(
        id: '3',
        authorId: 'user123',
        status: PostStatus.published,
        caption: 'Just published my latest tutorial! Check it out 👀',
        tags: ['tutorial', 'education', 'tech'],
        visibility: PostVisibility.public,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
        media: [
          PostMedia(
            id: 'media3',
            type: MediaType.video,
            src: 'https://example.com/video2.mp4',
            aspectRatio: 16.0 / 9.0,
            durationMs: 120000,
            variants: [],
          ),
        ],
        platforms: [
          PlatformConfig(
            key: PlatformKey.youtube.name,
            enabled: true,
            status: PlatformStatus.published,
            payload: {'url': 'https://youtube.com/watch?v=abc123'},
          ),
          PlatformConfig(
            key: PlatformKey.x.name,
            enabled: true,
            status: PlatformStatus.published,
            payload: {'url': 'https://x.com/status/123456'},
          ),
        ],
        schedule: PostSchedule(
          scheduledAtUtc: DateTime.now().subtract(const Duration(hours: 1)),
          timezone: 'America/New_York',
          perPlatform: {},
          createdAtUtc: DateTime.now().subtract(const Duration(days: 1)),
          updatedAtUtc: DateTime.now().subtract(const Duration(hours: 1)),
        ),
        analyticsHints: {},
        idempotencyKey: 'key3',
      ),
    ];

    // Apply filters
    var filteredPosts = mockPosts;

    if (status != null) {
      filteredPosts =
          filteredPosts.where((post) => post.status == status).toList();
    }

    if (platform != null) {
      filteredPosts = filteredPosts
          .where((post) => post.platforms.any((p) => p.key == platform.name))
          .toList();
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      filteredPosts = filteredPosts
          .where((post) =>
              post.caption.toLowerCase().contains(searchQuery.toLowerCase()) ||
              post.tags.any((tag) =>
                  tag.toLowerCase().contains(searchQuery.toLowerCase())))
          .toList();
    }

    return filteredPosts;
  }
}
