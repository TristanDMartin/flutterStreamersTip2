import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'logging_service.dart';
import 'error_handler_service.dart';

class SearchApiService {
  static final SearchApiService _instance = SearchApiService._internal();
  factory SearchApiService() => _instance;
  SearchApiService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Search users by username, display name, or hashtags
  Future<List<SearchResult>> searchUsers(String query, {int limit = 20, int offset = 0}) async {
    try {
      if (query.trim().isEmpty) {
        return [];
      }

      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      final searchTerm = query.trim().toLowerCase();
      final List<SearchResult> results = [];

      // Search by username
      final usernameQuery = await _firestore
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: searchTerm)
          .where('username', isLessThan: searchTerm + 'z')
          .limit(limit)
          .get();

      for (final doc in usernameQuery.docs) {
        if (doc.id != currentUserId) {
          results.add(_mapUserToSearchResult(doc, 'username'));
        }
      }

      // Search by display name
      final displayNameQuery = await _firestore
          .collection('users')
          .where('displayName', isGreaterThanOrEqualTo: searchTerm)
          .where('displayName', isLessThan: searchTerm + 'z')
          .limit(limit)
          .get();

      for (final doc in displayNameQuery.docs) {
        if (doc.id != currentUserId && !results.any((r) => r.userId == doc.id)) {
          results.add(_mapUserToSearchResult(doc, 'displayName'));
        }
      }

      // Search by hashtags in user profiles
      final hashtagQuery = await _firestore
          .collection('users')
          .where('hashtags', arrayContains: searchTerm)
          .limit(limit)
          .get();

      for (final doc in hashtagQuery.docs) {
        if (doc.id != currentUserId && !results.any((r) => r.userId == doc.id)) {
          results.add(_mapUserToSearchResult(doc, 'hashtag'));
        }
      }

      // Sort results by relevance (exact matches first, then partial matches)
      results.sort((a, b) {
        final aRelevance = _calculateRelevance(a, searchTerm);
        final bRelevance = _calculateRelevance(b, searchTerm);
        return bRelevance.compareTo(aRelevance);
      });

      // Apply pagination
      final paginatedResults = results.skip(offset).take(limit).toList();

      LoggingService.instance.debug('Found ${paginatedResults.length} users for query: "$query"', tag: 'SearchApiService');
      return paginatedResults;
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error searching users', tag: 'SearchApiService', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Search videos by title, description, or hashtags
  Future<List<SearchResult>> searchVideos(String query, {int limit = 20, int offset = 0}) async {
    try {
      if (query.trim().isEmpty) {
        return [];
      }

      final searchTerm = query.trim().toLowerCase();
      final List<SearchResult> results = [];

      // Search by video title
      final titleQuery = await _firestore
          .collection('videos')
          .where('title', isGreaterThanOrEqualTo: searchTerm)
          .where('title', isLessThan: searchTerm + 'z')
          .where('isPublic', isEqualTo: true)
          .limit(limit)
          .get();

      for (final doc in titleQuery.docs) {
        results.add(_mapVideoToSearchResult(doc, 'title'));
      }

      // Search by video description
      final descriptionQuery = await _firestore
          .collection('videos')
          .where('description', isGreaterThanOrEqualTo: searchTerm)
          .where('description', isLessThan: searchTerm + 'z')
          .where('isPublic', isEqualTo: true)
          .limit(limit)
          .get();

      for (final doc in descriptionQuery.docs) {
        if (!results.any((r) => r.videoId == doc.id)) {
          results.add(_mapVideoToSearchResult(doc, 'description'));
        }
      }

      // Search by video hashtags
      final hashtagQuery = await _firestore
          .collection('videos')
          .where('hashtags', arrayContains: searchTerm)
          .where('isPublic', isEqualTo: true)
          .limit(limit)
          .get();

      for (final doc in hashtagQuery.docs) {
        if (!results.any((r) => r.videoId == doc.id)) {
          results.add(_mapVideoToSearchResult(doc, 'hashtag'));
        }
      }

      // Sort results by relevance and view count
      results.sort((a, b) {
        final aRelevance = _calculateVideoRelevance(a, searchTerm);
        final bRelevance = _calculateVideoRelevance(b, searchTerm);
        return bRelevance.compareTo(aRelevance);
      });

      // Apply pagination
      final paginatedResults = results.skip(offset).take(limit).toList();

      LoggingService.instance.debug('Found ${paginatedResults.length} videos for query: "$query"', tag: 'SearchApiService');
      return paginatedResults;
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error searching videos', tag: 'SearchApiService', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Search hashtags
  Future<List<SearchResult>> searchHashtags(String query, {int limit = 20, int offset = 0}) async {
    try {
      if (query.trim().isEmpty) {
        return [];
      }

      final searchTerm = query.trim().toLowerCase();
      final List<SearchResult> results = [];

      // Search for hashtags in user profiles
      final userHashtagQuery = await _firestore
          .collection('users')
          .where('hashtags', arrayContains: searchTerm)
          .limit(limit)
          .get();

      final hashtagCounts = <String, int>{};
      for (final doc in userHashtagQuery.docs) {
        final hashtags = List<String>.from(doc.data()['hashtags'] ?? []);
        for (final hashtag in hashtags) {
          if (hashtag.toLowerCase().contains(searchTerm)) {
            hashtagCounts[hashtag] = (hashtagCounts[hashtag] ?? 0) + 1;
          }
        }
      }

      // Search for hashtags in videos
      final videoHashtagQuery = await _firestore
          .collection('videos')
          .where('hashtags', arrayContains: searchTerm)
          .where('isPublic', isEqualTo: true)
          .limit(limit)
          .get();

      for (final doc in videoHashtagQuery.docs) {
        final hashtags = List<String>.from(doc.data()['hashtags'] ?? []);
        for (final hashtag in hashtags) {
          if (hashtag.toLowerCase().contains(searchTerm)) {
            hashtagCounts[hashtag] = (hashtagCounts[hashtag] ?? 0) + 1;
          }
        }
      }

      // Convert to search results
      for (final entry in hashtagCounts.entries) {
        results.add(SearchResult(
          id: entry.key,
          type: SearchResultType.hashtag,
          title: entry.key,
          subtitle: '${entry.value} posts',
          metadata: {'count': entry.value},
          imageURL: null,
        ));
      }

      // Sort by count (most popular first)
      results.sort((a, b) {
        final aCount = a.metadata['count'] as int? ?? 0;
        final bCount = b.metadata['count'] as int? ?? 0;
        return bCount.compareTo(aCount);
      });

      // Apply pagination
      final paginatedResults = results.skip(offset).take(limit).toList();

      LoggingService.instance.debug('Found ${paginatedResults.length} hashtags for query: "$query"', tag: 'SearchApiService');
      return paginatedResults;
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error searching hashtags', tag: 'SearchApiService', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Get trending hashtags
  Future<List<SearchResult>> getTrendingHashtags({int limit = 10}) async {
    try {
      final List<SearchResult> results = [];

      // Get hashtags from recent videos (last 7 days)
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      final recentVideosQuery = await _firestore
          .collection('videos')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(weekAgo))
          .where('isPublic', isEqualTo: true)
          .limit(100)
          .get();

      final hashtagCounts = <String, int>{};
      for (final doc in recentVideosQuery.docs) {
        final hashtags = List<String>.from(doc.data()['hashtags'] ?? []);
        for (final hashtag in hashtags) {
          hashtagCounts[hashtag] = (hashtagCounts[hashtag] ?? 0) + 1;
        }
      }

      // Convert to search results and sort by count
      for (final entry in hashtagCounts.entries) {
        results.add(SearchResult(
          id: entry.key,
          type: SearchResultType.hashtag,
          title: entry.key,
          subtitle: '${entry.value} posts this week',
          metadata: {'count': entry.value},
          imageURL: null,
        ));
      }

      results.sort((a, b) {
        final aCount = a.metadata['count'] as int? ?? 0;
        final bCount = b.metadata['count'] as int? ?? 0;
        return bCount.compareTo(aCount);
      });

      final trendingResults = results.take(limit).toList();
      LoggingService.instance.debug('Found ${trendingResults.length} trending hashtags', tag: 'SearchApiService');
      return trendingResults;
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error getting trending hashtags', tag: 'SearchApiService', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  /// Map user document to search result
  SearchResult _mapUserToSearchResult(QueryDocumentSnapshot doc, String matchType) {
    final data = doc.data() as Map<String, dynamic>;
    return SearchResult(
      id: doc.id,
      type: SearchResultType.user,
      title: data['displayName'] ?? data['username'] ?? 'Unknown User',
      subtitle: '@${data['username'] ?? ''}',
      metadata: {
        'userId': doc.id,
        'username': data['username'] ?? '',
        'displayName': data['displayName'] ?? '',
        'avatarUrl': data['avatarUrl'],
        'followerCount': data['followerCount'] ?? 0,
        'matchType': matchType,
      },
      imageURL: data['avatarUrl'],
    );
  }

  /// Map video document to search result
  SearchResult _mapVideoToSearchResult(QueryDocumentSnapshot doc, String matchType) {
    final data = doc.data() as Map<String, dynamic>;
    return SearchResult(
      id: doc.id,
      type: SearchResultType.video,
      title: data['title'] ?? 'Untitled Video',
      subtitle: 'by @${data['creatorUsername'] ?? 'unknown'}',
      metadata: {
        'videoId': doc.id,
        'creatorId': data['creatorId'] ?? '',
        'creatorUsername': data['creatorUsername'] ?? '',
        'thumbnailUrl': data['thumbnailUrl'],
        'viewCount': data['viewCount'] ?? 0,
        'duration': data['duration'] ?? 0,
        'matchType': matchType,
      },
      imageURL: data['thumbnailUrl'],
    );
  }

  /// Calculate relevance score for user search results
  int _calculateRelevance(SearchResult result, String searchTerm) {
    final title = result.title.toLowerCase();
    final subtitle = result.subtitle.toLowerCase();
    
    int score = 0;
    
    // Exact match gets highest score
    if (title == searchTerm) score += 100;
    if (subtitle == searchTerm) score += 100;
    
    // Starts with search term gets high score
    if (title.startsWith(searchTerm)) score += 50;
    if (subtitle.startsWith(searchTerm)) score += 50;
    
    // Contains search term gets medium score
    if (title.contains(searchTerm)) score += 25;
    if (subtitle.contains(searchTerm)) score += 25;
    
    // Boost score for users with more followers
    final followerCount = result.metadata['followerCount'] as int? ?? 0;
    score += (followerCount / 100).round();
    
    return score;
  }

  /// Calculate relevance score for video search results
  int _calculateVideoRelevance(SearchResult result, String searchTerm) {
    final title = result.title.toLowerCase();
    final subtitle = result.subtitle.toLowerCase();
    
    int score = 0;
    
    // Exact match gets highest score
    if (title == searchTerm) score += 100;
    if (subtitle == searchTerm) score += 100;
    
    // Starts with search term gets high score
    if (title.startsWith(searchTerm)) score += 50;
    if (subtitle.startsWith(searchTerm)) score += 50;
    
    // Contains search term gets medium score
    if (title.contains(searchTerm)) score += 25;
    if (subtitle.contains(searchTerm)) score += 25;
    
    // Boost score for videos with more views
    final viewCount = result.metadata['viewCount'] as int? ?? 0;
    score += (viewCount / 1000).round();
    
    return score;
  }
}

/// Search result types
enum SearchResultType {
  user,
  video,
  hashtag,
}

/// Search result model
class SearchResult {
  final String id;
  final SearchResultType type;
  final String title;
  final String subtitle;
  final Map<String, dynamic> metadata;
  final String? imageURL;

  SearchResult({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.metadata,
    this.imageURL,
  });

  // Convenience getters
  String? get userId => metadata['userId'] as String?;
  String? get videoId => metadata['videoId'] as String?;
  String? get username => metadata['username'] as String?;
  String? get displayName => metadata['displayName'] as String?;
  String? get avatarUrl => metadata['avatarUrl'] as String?;
  String? get thumbnailUrl => metadata['thumbnailUrl'] as String?;
  int get followerCount => metadata['followerCount'] as int? ?? 0;
  int get viewCount => metadata['viewCount'] as int? ?? 0;
  int get duration => metadata['duration'] as int? ?? 0;
  String get matchType => metadata['matchType'] as String? ?? '';
}

// Riverpod provider
final searchApiServiceProvider = Provider((ref) => SearchApiService());
