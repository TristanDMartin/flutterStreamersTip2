import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/home_video.dart';
import '../models/user.dart';
import '../utils/video_url_resolver.dart';

/// Production-ready caching service for recommendation algorithm
class AlgorithmCacheService {
  static final AlgorithmCacheService _instance =
      AlgorithmCacheService._internal();
  factory AlgorithmCacheService() => _instance;
  AlgorithmCacheService._internal();

  // Cache keys
  static const String _followingFeedKey = 'following_feed_cache';
  static const String _forYouFeedKey = 'for_you_feed_cache';
  static const String _userProfileKey = 'user_profile_cache';
  static const String _algorithmConfigKey = 'algorithm_config_cache';

  // Cache TTL (Time To Live) in minutes
  static const int _feedCacheTTL = 15; // 15 minutes
  static const int _profileCacheTTL = 60; // 1 hour
  static const int _configCacheTTL = 1440; // 24 hours

  // Cache size limits
  static const int _maxCacheEntries = 100;

  /// Cache following feed results
  Future<void> cacheFollowingFeed({
    required String userId,
    required List<HomeVideo> videos,
    Map<String, dynamic>? nextCursor,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = {
        'userId': userId,
        'videos': videos.map((v) => _videoToMap(v)).toList(),
        'nextCursor': nextCursor,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'ttl': _feedCacheTTL,
      };

      final cacheKey = '$_followingFeedKey:$userId';
      await prefs.setString(cacheKey, json.encode(cacheData));

      // Clean old cache entries
      await _cleanOldCacheEntries(prefs, _followingFeedKey);

      debugPrint(
          '✅ Cached following feed for user $userId (${videos.length} videos)');
    } catch (e) {
      debugPrint('❌ Error caching following feed: $e');
    }
  }

  /// Get cached following feed
  Future<CachedFeedResult?> getCachedFollowingFeed(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_followingFeedKey:$userId';
      final cacheData = prefs.getString(cacheKey);

      if (cacheData == null) return null;

      final data = json.decode(cacheData) as Map<String, dynamic>;
      final timestamp = data['timestamp'] as int;
      final ttl = data['ttl'] as int;

      // Check if cache is expired
      final age = DateTime.now().millisecondsSinceEpoch - timestamp;
      if (age > ttl * 60 * 1000) {
        await prefs.remove(cacheKey);
        return null;
      }

      final videos =
          (data['videos'] as List).map((v) => _videoFromMap(v)).toList();
      final nextCursor = data['nextCursor'] as Map<String, dynamic>?;

      debugPrint(
          '✅ Retrieved cached following feed for user $userId (${videos.length} videos)');
      return CachedFeedResult(videos: videos, nextCursor: nextCursor);
    } catch (e) {
      debugPrint('❌ Error retrieving cached following feed: $e');
      return null;
    }
  }

  /// Cache For You feed results
  Future<void> cacheForYouFeed({
    required String userId,
    required List<HomeVideo> videos,
    Map<String, dynamic>? nextCursor,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = {
        'userId': userId,
        'videos': videos.map((v) => _videoToMap(v)).toList(),
        'nextCursor': nextCursor,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'ttl': _feedCacheTTL,
      };

      final cacheKey = '$_forYouFeedKey:$userId';
      await prefs.setString(cacheKey, json.encode(cacheData));

      // Clean old cache entries
      await _cleanOldCacheEntries(prefs, _forYouFeedKey);

      debugPrint(
          '✅ Cached For You feed for user $userId (${videos.length} videos)');
    } catch (e) {
      debugPrint('❌ Error caching For You feed: $e');
    }
  }

  /// Get cached For You feed
  Future<CachedFeedResult?> getCachedForYouFeed(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_forYouFeedKey:$userId';
      final cacheData = prefs.getString(cacheKey);

      if (cacheData == null) return null;

      final data = json.decode(cacheData) as Map<String, dynamic>;
      final timestamp = data['timestamp'] as int;
      final ttl = data['ttl'] as int;

      // Check if cache is expired
      final age = DateTime.now().millisecondsSinceEpoch - timestamp;
      if (age > ttl * 60 * 1000) {
        await prefs.remove(cacheKey);
        return null;
      }

      final videos =
          (data['videos'] as List).map((v) => _videoFromMap(v)).toList();
      final nextCursor = data['nextCursor'] as Map<String, dynamic>?;

      debugPrint(
          '✅ Retrieved cached For You feed for user $userId (${videos.length} videos)');
      return CachedFeedResult(videos: videos, nextCursor: nextCursor);
    } catch (e) {
      debugPrint('❌ Error retrieving cached For You feed: $e');
      return null;
    }
  }

  /// Cache user profile data
  Future<void> cacheUserProfile({
    required String userId,
    required Map<String, dynamic> profileData,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = {
        'userId': userId,
        'data': profileData,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'ttl': _profileCacheTTL,
      };

      final cacheKey = '$_userProfileKey:$userId';
      await prefs.setString(cacheKey, json.encode(cacheData));

      debugPrint('✅ Cached user profile for user $userId');
    } catch (e) {
      debugPrint('❌ Error caching user profile: $e');
    }
  }

  /// Get cached user profile
  Future<Map<String, dynamic>?> getCachedUserProfile(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_userProfileKey:$userId';
      final cacheData = prefs.getString(cacheKey);

      if (cacheData == null) return null;

      final data = json.decode(cacheData) as Map<String, dynamic>;
      final timestamp = data['timestamp'] as int;
      final ttl = data['ttl'] as int;

      // Check if cache is expired
      final age = DateTime.now().millisecondsSinceEpoch - timestamp;
      if (age > ttl * 60 * 1000) {
        await prefs.remove(cacheKey);
        return null;
      }

      debugPrint('✅ Retrieved cached user profile for user $userId');
      return data['data'] as Map<String, dynamic>;
    } catch (e) {
      debugPrint('❌ Error retrieving cached user profile: $e');
      return null;
    }
  }

  /// Cache algorithm configuration
  Future<void> cacheAlgorithmConfig(Map<String, dynamic> config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = {
        'config': config,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'ttl': _configCacheTTL,
      };

      await prefs.setString(_algorithmConfigKey, json.encode(cacheData));

      debugPrint('✅ Cached algorithm configuration');
    } catch (e) {
      debugPrint('❌ Error caching algorithm configuration: $e');
    }
  }

  /// Get cached algorithm configuration
  Future<Map<String, dynamic>?> getCachedAlgorithmConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = prefs.getString(_algorithmConfigKey);

      if (cacheData == null) return null;

      final data = json.decode(cacheData) as Map<String, dynamic>;
      final timestamp = data['timestamp'] as int;
      final ttl = data['ttl'] as int;

      // Check if cache is expired
      final age = DateTime.now().millisecondsSinceEpoch - timestamp;
      if (age > ttl * 60 * 1000) {
        await prefs.remove(_algorithmConfigKey);
        return null;
      }

      debugPrint('✅ Retrieved cached algorithm configuration');
      return data['config'] as Map<String, dynamic>;
    } catch (e) {
      debugPrint('❌ Error retrieving cached algorithm configuration: $e');
      return null;
    }
  }

  /// Clear all cache
  Future<void> clearAllCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();

      for (final key in keys) {
        if (key.startsWith(_followingFeedKey) ||
            key.startsWith(_forYouFeedKey) ||
            key.startsWith(_userProfileKey) ||
            key == _algorithmConfigKey) {
          await prefs.remove(key);
        }
      }

      debugPrint('✅ Cleared all algorithm cache');
    } catch (e) {
      debugPrint('❌ Error clearing cache: $e');
    }
  }

  /// Clear cache for specific user
  Future<void> clearUserCache(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = [
        '$_followingFeedKey:$userId',
        '$_forYouFeedKey:$userId',
        '$_userProfileKey:$userId',
      ];

      for (final key in keys) {
        await prefs.remove(key);
      }

      debugPrint('✅ Cleared cache for user $userId');
    } catch (e) {
      debugPrint('❌ Error clearing user cache: $e');
    }
  }

  /// Clean old cache entries
  Future<void> _cleanOldCacheEntries(
      SharedPreferences prefs, String keyPrefix) async {
    try {
      final keys = prefs.getKeys();
      final cacheEntries = <String, int>{};

      // Find all cache entries with timestamps
      for (final key in keys) {
        if (key.startsWith(keyPrefix)) {
          final data = prefs.getString(key);
          if (data != null) {
            try {
              final decoded = json.decode(data) as Map<String, dynamic>;
              final timestamp = decoded['timestamp'] as int?;
              if (timestamp != null) {
                cacheEntries[key] = timestamp;
              }
            } catch (e) {
              // Invalid cache entry, remove it
              await prefs.remove(key);
            }
          }
        }
      }

      // Sort by timestamp and remove oldest entries
      if (cacheEntries.length > _maxCacheEntries) {
        final sortedEntries = cacheEntries.entries.toList()
          ..sort((a, b) => a.value.compareTo(b.value));

        final entriesToRemove = sortedEntries
            .take(cacheEntries.length - _maxCacheEntries)
            .map((e) => e.key)
            .toList();

        for (final key in entriesToRemove) {
          await prefs.remove(key);
        }

        debugPrint('🧹 Cleaned ${entriesToRemove.length} old cache entries');
      }
    } catch (e) {
      debugPrint('❌ Error cleaning old cache entries: $e');
    }
  }

  /// Convert HomeVideo to Map for caching
  Map<String, dynamic> _videoToMap(HomeVideo video) {
    return {
      'id': video.id,
      'creator': {
        'id': video.creator.id,
        'username': video.creator.username,
        'displayName': video.creator.displayName,
        'avatarURL': video.creator.avatarURL,
        'isVerified': false, // User model doesn't have isVerified field
      },
      'videoURL': video.videoURL,
      'thumbnailURL': video.thumbnailURL,
      'likes': video.likes,
      'comments': video.comments,
      'views': video.views,
      'caption': video.caption,
      'isLiked': video.isLiked,
      'isFavorited': video.isFavorited,
      'isDraft': video.isDraft,
      'mlScore': video.mlScore,
      'categoryId': video.categoryId,
      'createdAt': DateTime.now()
          .millisecondsSinceEpoch, // HomeVideo doesn't have createdAt field
    };
  }

  /// Convert Map to HomeVideo from cache
  HomeVideo _videoFromMap(Map<String, dynamic> data) {
    return HomeVideo(
      id: data['id'] ?? '',
      creator: User(
        id: data['creator']['id'] ?? '',
        username: data['creator']['username'] ?? '',
        displayName: data['creator']['displayName'] ?? '',
        avatarURL: data['creator']['avatarURL'],
      ),
      videoURL: resolveVideoUrl(data),
      thumbnailURL: data['thumbnailURL'],
      likes: data['likes'] ?? 0,
      comments: data['comments'] ?? 0,
      views: data['views'] ?? 0,
      caption: data['caption'] ?? '',
      isLiked: data['isLiked'] ?? false,
      isFavorited: data['isFavorited'] ?? false,
      isDraft: data['isDraft'] ?? false,
      mlScore: data['mlScore'] ?? 0.0,
      categoryId: data['categoryId'] ?? '',
      // createdAt field not available in HomeVideo model
    );
  }
}

/// Cached feed result
class CachedFeedResult {
  final List<HomeVideo> videos;
  final Map<String, dynamic>? nextCursor;

  CachedFeedResult({
    required this.videos,
    this.nextCursor,
  });
}
