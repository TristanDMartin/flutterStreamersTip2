import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import '../models/trending_creator.dart';
import '../models/category.dart';
import '../models/recommended_content.dart';
import '../models/home_video.dart';
import '../models/video_clip.dart';
import '../models/user.dart';
import '../services/logging_service.dart';
import '../services/real_user_data_service.dart';

part 'discover_provider.freezed.dart';

@freezed
class DiscoverState with _$DiscoverState {
  const factory DiscoverState({
    @Default([]) List<TrendingCreator> trendingCreators,
    @Default([]) List<Category> categories,
    @Default([]) List<RecommendedContent> recommendedContent,
    @Default([]) List<SearchResult> searchResults,
    @Default(false) bool isSearching,
    @Default([]) List<VideoClip> clips,
    @Default(false) bool isLoadingTrendingCreators,
    @Default({}) Map<String, int> userScrollBehavior,
    @Default({}) Map<String, double> lowViewedRatio,
  }) = _DiscoverState;
}

@freezed
class SearchResult with _$SearchResult {
  const factory SearchResult({
    required String id,
    required String title,
    required String subtitle,
    String? metadata,
    String? imageURL,
    required ResultType type,
  }) = _SearchResult;
}

enum ResultType { creator, category, content }

class DiscoverNotifier extends StateNotifier<DiscoverState> {
  final RealUserDataService _userDataService = RealUserDataService();
  
  DiscoverNotifier() : super(const DiscoverState()) {
    _loadInitialData();
  }

  void _loadInitialData() {
    // Load sample data as fallback
    state = state.copyWith(
      trendingCreators: TrendingCreator.samples,
      categories: Category.samples,
      recommendedContent: RecommendedContentExtension.samples,
      clips: ClipExtension.samples,
    );

    // Load real trending creators from Firebase
    loadTrendingCreators();
  }

  // removed duplicate placeholder implementation (replaced below)

  Future<List<HomeVideo>> fetchVideosForCategory(String categoryId) async {
    try {
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('videos')
          .where('category_id', isEqualTo: categoryId)
          .orderBy('score', descending: true)
          .limit(10);

      // Pagination: start after last doc id if provided in state.lowViewedRatio map as a temp store
      final String cursorKey = 'cursor_$categoryId';
      final String? lastId = state.lowViewedRatio[cursorKey]?.toString();
      if (lastId != null && lastId.isNotEmpty) {
        try {
          final lastDoc = await FirebaseFirestore.instance.collection('videos').doc(lastId).get();
          if (lastDoc.exists) {
            query = query.startAfterDocument(lastDoc);
          }
        } catch (_) {}
      }

      final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();
      final List<HomeVideo> videos = snapshot.docs.map((doc) {
        final Map<String, dynamic> data = doc.data();

        final User creator = User(
          id: (data['creator_id'] ?? 'unknown').toString(),
          username: (data['creator_username'] ?? 'unknown').toString(),
          displayName: (data['creator_display_name'] ?? 'Unknown').toString(),
          bio: data['creator_bio'] as String?,
          avatarURL: data['creator_avatar_url'] as String?,
          onlineStatus: (data['creator_online_status'] ?? 'online').toString(),
          hashtags: List<String>.from((data['creator_hashtags'] as List?) ?? const <String>[]),
          postCount: (data['creator_post_count'] ?? 0) as int,
          followerCount: (data['creator_follower_count'] ?? 0) as int,
          followingCount: (data['creator_following_count'] ?? 0) as int,
        );

        return HomeVideo(
          id: doc.id,
          creator: creator,
          videoURL: (data['video_url'] ?? data['videoURL'] ?? '').toString(),
          thumbnailURL: (data['thumbnail_url'] ?? data['thumbnailURL']) as String?,
          likes: (data['likes'] ?? 0) as int,
          comments: (data['comments'] ?? 0) as int,
          views: (data['views'] ?? 0) as int,
          caption: (data['caption'] ?? '').toString(),
          isLiked: (data['isLiked'] ?? false) as bool,
          isFavorited: (data['isFavorited'] ?? false) as bool,
          mlScore: ((data['score'] ?? data['mlScore'] ?? 0.0) as num).toDouble(),
          categoryId: (data['category_id'] ?? '').toString(),
        );
      }).toList();

      // Store new cursor (last doc id) in lowViewedRatio map as lightweight storage
      if (snapshot.docs.isNotEmpty) {
        final String newCursor = snapshot.docs.last.id;
        state = state.copyWith(
          lowViewedRatio: {
            ...state.lowViewedRatio,
            cursorKey: double.tryParse(newCursor) ?? 0.0,
          },
        );
      }

      return videos;
    } catch (e) {
      LoggingService.instance.error('Error fetching videos for category $categoryId', tag: 'DiscoverProvider', error: e);
      return [];
    }
  }

  Future<void> loadTrendingCreators() async {
    if (state.isLoadingTrendingCreators) return;
    state = state.copyWith(isLoadingTrendingCreators: true);
    
    try {
      LoggingService.instance.debug('Loading trending creators from real data service', tag: 'DiscoverProvider');
      
      // Use real user data service
      final trending = await _userDataService.getTrendingCreators(limit: 10);
      
      state = state.copyWith(trendingCreators: trending, isLoadingTrendingCreators: false);
      LoggingService.instance.info('Successfully loaded ${trending.length} trending creators', tag: 'DiscoverProvider');
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error loading trending creators', tag: 'DiscoverProvider', error: e, stackTrace: stackTrace);
      // Fallback to sample data
      state = state.copyWith(
        trendingCreators: TrendingCreator.samples,
        isLoadingTrendingCreators: false,
      );
    }
  }

  void clearSearch() {
    state = state.copyWith(searchResults: [], isSearching: false);
  }

  Future<void> search(String query) async {
    final String q = query.trim();
    if (q.isEmpty) {
      clearSearch();
      return;
    }

    // Track search analytics
    _trackSearchQuery(q);
    
    state = state.copyWith(isSearching: true);

    try {
      final FirebaseFirestore db = FirebaseFirestore.instance;
      final String qLower = q.toLowerCase();
      
      // Add timeout to prevent hanging queries
      const timeout = Duration(seconds: 10);

      Future<List<SearchResult>> userResults() async {
        final List<SearchResult> results = [];

        // username prefix
        try {
          final qs1 = await db
              .collection('users')
              .orderBy('username')
              .startAt([q])
              .endAt(["$q\uf8ff"])
              .limit(10)
              .get()
              .timeout(timeout);
          for (final d in qs1.docs) {
            final data = d.data();
            results.add(SearchResult(
              id: d.id,
              title: (data['displayName'] ?? data['username'] ?? 'User').toString(),
              subtitle: '@${(data['username'] ?? '').toString()}',
              metadata: data['followersCount'] != null ? '${data['followersCount']} followers' : null,
              imageURL: data['avatarURL'] as String?,
              type: ResultType.creator,
            ));
          }
        } catch (e) {
          LoggingService.instance.warning('Username search failed', tag: 'DiscoverProvider', error: e);
        }

        // displayName prefix
        try {
          final qs2 = await db
              .collection('users')
              .orderBy('displayName')
              .startAt([q])
              .endAt(["$q\uf8ff"])
              .limit(10)
              .get()
              .timeout(timeout);
          for (final d in qs2.docs) {
            final data = d.data();
            results.add(SearchResult(
              id: d.id,
              title: (data['displayName'] ?? data['username'] ?? 'User').toString(),
              subtitle: '@${(data['username'] ?? '').toString()}',
              metadata: data['followersCount'] != null ? '${data['followersCount']} followers' : null,
              imageURL: data['avatarURL'] as String?,
              type: ResultType.creator,
            ));
          }
        } catch (e) {
          LoggingService.instance.warning('DisplayName search failed', tag: 'DiscoverProvider', error: e);
        }

        return results;
      }

      Future<List<SearchResult>> videoResults() async {
        final List<SearchResult> results = [];
        // tags contains
        try {
          final qs1 = await db
              .collection('videos')
              .where('tags', arrayContains: qLower)
              .orderBy('timestamp', descending: true)
              .limit(10)
              .get()
              .timeout(timeout);
          for (final d in qs1.docs) {
            final data = d.data();
            results.add(SearchResult(
              id: d.id,
              title: (data['title'] ?? 'Video').toString(),
              subtitle: (data['creator_username'] ?? data['creator'] ?? '').toString(),
              metadata: data['views'] != null ? '${data['views']} views' : null,
              imageURL: data['thumbnail_url'] as String?,
              type: ResultType.content,
            ));
          }
        } catch (e) {
          LoggingService.instance.warning('Video tags search failed', tag: 'DiscoverProvider', error: e);
        }

        // title prefix
        try {
          final qs2 = await db
              .collection('videos')
              .orderBy('title')
              .startAt([q])
              .endAt(["$q\uf8ff"])
              .limit(10)
              .get()
              .timeout(timeout);
          for (final d in qs2.docs) {
            final data = d.data();
            results.add(SearchResult(
              id: d.id,
              title: (data['title'] ?? 'Video').toString(),
              subtitle: (data['creator_username'] ?? data['creator'] ?? '').toString(),
              metadata: data['views'] != null ? '${data['views']} views' : null,
              imageURL: data['thumbnail_url'] as String?,
              type: ResultType.content,
            ));
          }
        } catch (e) {
          LoggingService.instance.warning('Video title search failed', tag: 'DiscoverProvider', error: e);
        }

        return results;
      }

      Future<List<SearchResult>> categoryResults() async {
        final results = state.categories
            .where((c) => c.name.toLowerCase().contains(qLower))
            .take(10)
            .map((c) => SearchResult(
                  id: c.id,
                  title: c.name,
                  subtitle: 'Category',
                  metadata: null,
                  imageURL: null,
                  type: ResultType.category,
                ))
            .toList();
        return results;
      }

      // Stories not implemented yet
      Future<List<SearchResult>> hashtagResults() async {
        final List<SearchResult> results = [];
        
        // Search for hashtags in user profiles
        try {
          final qs1 = await db
              .collection('users')
              .where('hashtags', arrayContains: qLower)
              .limit(10)
              .get();
          for (final d in qs1.docs) {
            final data = d.data();
            final hashtags = List<String>.from((data['hashtags'] as List?) ?? []);
            final matchingHashtags = hashtags.where((tag) => tag.toLowerCase().contains(qLower)).toList();
            
            if (matchingHashtags.isNotEmpty) {
              results.add(SearchResult(
                id: d.id,
                title: '#${matchingHashtags.first}',
                subtitle: 'Hashtag used by @${(data['username'] ?? '').toString()}',
                metadata: '${matchingHashtags.length} hashtags',
                imageURL: data['avatarURL'] as String?,
                type: ResultType.creator,
              ));
            }
          }
        } catch (_) {}

        // Search for hashtags in videos
        try {
          final qs2 = await db
              .collection('videos')
              .where('hashtags', arrayContains: qLower)
              .orderBy('timestamp', descending: true)
              .limit(10)
              .get();
          for (final d in qs2.docs) {
            final data = d.data();
            final hashtags = List<String>.from((data['hashtags'] as List?) ?? []);
            final matchingHashtags = hashtags.where((tag) => tag.toLowerCase().contains(qLower)).toList();
            
            if (matchingHashtags.isNotEmpty) {
              results.add(SearchResult(
                id: d.id,
                title: '#${matchingHashtags.first}',
                subtitle: 'Hashtag in video by ${(data['creator_username'] ?? '').toString()}',
                metadata: '${data['views'] ?? 0} views',
                imageURL: data['thumbnail_url'] as String?,
                type: ResultType.content,
              ));
            }
          }
        } catch (_) {}

        return results;
      }

      Future<List<SearchResult>> storyResults() async => <SearchResult>[];

      // Execute all search queries in parallel with overall timeout
      final searchResults = await Future.wait([
        userResults(),
        videoResults(),
        categoryResults(),
        hashtagResults(),
        storyResults(),
      ]).timeout(timeout);

      // Deduplicate results
      final Map<String, SearchResult> dedup = {};
      for (final list in searchResults) {
        for (final r in list) {
          final key = '${r.type}-${r.id}';
          dedup[key] = r;
        }
      }

      // Limit results to prevent UI overload
      final limitedResults = dedup.values.take(50).toList();
      
      state = state.copyWith(searchResults: limitedResults, isSearching: false);
    } catch (e) {
      LoggingService.instance.error('Search failed', tag: 'DiscoverProvider', error: e);
      state = state.copyWith(searchResults: [], isSearching: false);
    }
  }

  void _trackSearchQuery(String query) {
    try {
      // Log search query for analytics
      LoggingService.instance.debug('Search query: "$query"', tag: 'DiscoverProvider');
      
      // Track search performance
      final searchStartTime = DateTime.now();
      
      // Store search metrics in state for analytics
      // This could be extended to send to Firebase Analytics
      LoggingService.instance.debug('Search started at: $searchStartTime', tag: 'DiscoverProvider');
    } catch (e) {
      LoggingService.instance.error('Error tracking search query', tag: 'DiscoverProvider', error: e);
    }
  }

  void trackUserScroll(String categoryId) {
    final currentScrolls = state.userScrollBehavior[categoryId] ?? 0;
    final newScrolls = currentScrolls + 1;
    
    state = state.copyWith(
      userScrollBehavior: {
        ...state.userScrollBehavior,
        categoryId: newScrolls,
      },
    );

    LoggingService.instance.debug('User scrolled in category $categoryId, total scrolls: $newScrolls', tag: 'DiscoverProvider');

    // Adjust low viewed ratio based on scroll behavior
    if (newScrolls > 10) {
      final currentRatio = state.lowViewedRatio[categoryId] ?? 0.5;
      final newRatio = (currentRatio + 0.1).clamp(0.0, 0.8);
      
      state = state.copyWith(
        lowViewedRatio: {
          ...state.lowViewedRatio,
          categoryId: newRatio,
        },
      );
      
      LoggingService.instance.debug('Increasing low viewed ratio for $categoryId to $newRatio', tag: 'DiscoverProvider');
    }
  }

  ({double lowViewedRatio, double highViewedRatio}) getAdaptiveBalance(String categoryId) {
    final baseRatio = state.lowViewedRatio[categoryId] ?? 0.5;
    return (lowViewedRatio: baseRatio, highViewedRatio: 1.0 - baseRatio);
  }

  void resetUserBehavior(String categoryId) {
    state = state.copyWith(
      userScrollBehavior: {
        ...state.userScrollBehavior,
        categoryId: 0,
      },
      lowViewedRatio: {
        ...state.lowViewedRatio,
        categoryId: 0.5, // Reset to default balance
      },
    );
    
    LoggingService.instance.debug('Reset user behavior for category $categoryId', tag: 'DiscoverProvider');
  }
}

final discoverProvider = StateNotifierProvider<DiscoverNotifier, DiscoverState>((ref) {
  return DiscoverNotifier();
});

// Extension for sample search results
extension SearchResultExtension on SearchResult {
  static List<SearchResult> get samples => [
    const SearchResult(
      id: '1',
      title: 'GamingPro',
      subtitle: 'Gaming Streamer',
      metadata: '150K followers',
      imageURL: null,
      type: ResultType.creator,
    ),
    const SearchResult(
      id: '2',
      title: 'Gaming',
      subtitle: 'Category',
      metadata: '1.2M videos',
      imageURL: null,
      type: ResultType.category,
    ),
    const SearchResult(
      id: '3',
      title: 'Amazing Gaming Highlights',
      subtitle: 'GamingPro',
      metadata: '15K views • 10:30',
      imageURL: null,
      type: ResultType.content,
    ),
  ];
}

// Extension for sample clips
extension ClipExtension on VideoClip {
  static List<VideoClip> get samples => [
    const VideoClip(
      id: '1',
      title: 'Epic Gaming Moment',
      creator: 'GamingPro',
      thumbnailURL: 'https://images.unsplash.com/photo-1542751371-adc38448a05e?w=300&h=400&fit=crop&crop=center',
      videoURL: 'https://example.com/video1.mp4',
      views: 15000,
      likes: 1200,
      duration: 0.5,
      categoryId: 'gaming',
      tags: ['gaming', 'highlights', 'epic'],
    ),
    const VideoClip(
      id: '2',
      title: 'Digital Art Process',
      creator: 'ArtStreamer',
      thumbnailURL: 'https://images.unsplash.com/photo-1541961017774-22349e4a1262?w=300&h=400&fit=crop&crop=center',
      videoURL: 'https://example.com/video2.mp4',
      views: 8000,
      likes: 650,
      duration: 1.25,
      categoryId: 'art',
      tags: ['art', 'digital', 'process'],
    ),
    const VideoClip(
      id: '3',
      title: 'Acoustic Cover',
      creator: 'MusicLive',
      thumbnailURL: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=300&h=400&fit=crop&crop=center',
      videoURL: 'https://example.com/video3.mp4',
      views: 25000,
      likes: 2100,
      duration: 2.75,
      categoryId: 'music',
      tags: ['music', 'acoustic', 'cover'],
    ),
    const VideoClip(
      id: '4',
      title: 'Tech Review',
      creator: 'TechReview',
      thumbnailURL: 'https://images.unsplash.com/photo-1518709268805-4e9042af2176?w=300&h=400&fit=crop&crop=center',
      videoURL: 'https://example.com/video4.mp4',
      views: 12000,
      likes: 890,
      duration: 3.33,
      categoryId: 'tech',
      tags: ['tech', 'review', 'gadgets'],
    ),
    const VideoClip(
      id: '5',
      title: 'Basketball Highlights',
      creator: 'SportsFan',
      thumbnailURL: 'https://images.unsplash.com/photo-1546519638-68e109498ffc?w=300&h=400&fit=crop&crop=center',
      videoURL: 'https://example.com/video5.mp4',
      views: 18000,
      likes: 1450,
      duration: 1.5,
      categoryId: 'sports',
      tags: ['sports', 'basketball', 'highlights'],
    ),
    const VideoClip(
      id: '6',
      title: 'Cooking Tutorial',
      creator: 'ChefMaster',
      thumbnailURL: 'https://images.unsplash.com/photo-1556909114-f6e7ad7d3136?w=300&h=400&fit=crop&crop=center',
      videoURL: 'https://example.com/video6.mp4',
      views: 9500,
      likes: 720,
      duration: 4.25,
      categoryId: 'food',
      tags: ['food', 'cooking', 'tutorial'],
    ),
  ];
}
