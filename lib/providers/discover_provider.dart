import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/trending_creator.dart';
import '../models/category.dart';
import '../models/recommended_content.dart';
import '../models/home_video.dart';
import '../models/video_clip.dart';
import '../models/video_thumbnails.dart';
import '../models/user.dart';
import '../models/user_count_fields.dart';
import '../services/creator_cache_service.dart';
import '../services/follows_service.dart';
import '../services/logging_service.dart';
import '../services/public_profile_firestore.dart';
import '../utils/swallow_non_fatal.dart';
import '../utils/discover_category_rules.dart';
import '../utils/video_document_rules.dart';
import '../utils/video_url_resolver.dart';
import '../utils/video_caption_resolver.dart';
import '../services/real_user_data_service.dart';
import '../services/image_preload_service.dart';
import '../utils/like_interaction_boundary.dart';

part 'discover_provider.freezed.dart';

@freezed
sealed class DiscoverState with _$DiscoverState {
  const factory DiscoverState({
    @Default([]) List<TrendingCreator> trendingCreators,
    @Default([]) List<Category> categories,
    @Default([]) List<RecommendedContent> recommendedContent,
    @Default([]) List<SearchResult> searchResults,
    @Default(false) bool isSearching,
    @Default([]) List<VideoClip> clips,
    @Default(false) bool isLoadingTrendingCreators,
    @Default(false) bool trendingCreatorsLoadFailed,
    @Default({}) Map<String, int> userScrollBehavior,
    @Default({}) Map<String, double> lowViewedRatio,
  }) = _DiscoverState;
}

@freezed
sealed class SearchResult with _$SearchResult {
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
  final FollowsService _followsService = FollowsService();
  final Map<String, DocumentSnapshot<Map<String, dynamic>>?>
      _categoryVideoCursors = {};
  static List<TrendingCreator> _cachedTrendingCreators =
      const <TrendingCreator>[];
  static DateTime? _cachedTrendingCreatorsAt;
  static const Duration _trendingCacheTtl = Duration(minutes: 10);
  // v2: followerCount must match users/{id} (profile UserStats), not edge aggregates.
  static const int _trendingCacheSchema = 2;
  static int _loadedTrendingCacheSchema = 0;
  static const String _trendingPrefsKey =
      'streamerstip.discover.trending_creators.v2';
  static Future<void>? _trendingLoadInFlight;

  DiscoverNotifier()
      : super(
          DiscoverState(
            trendingCreators: List<TrendingCreator>.from(
              _cachedTrendingCreators,
            ),
            isLoadingTrendingCreators: _cachedTrendingCreators.isEmpty,
            trendingCreatorsLoadFailed: false,
            categories: Category.samples,
            recommendedContent: RecommendedContentExtension.samples,
            clips: ClipExtension.samples,
          ),
        ) {
    if (_loadedTrendingCacheSchema != _trendingCacheSchema) {
      _cachedTrendingCreators = const <TrendingCreator>[];
      _cachedTrendingCreatorsAt = null;
      _loadedTrendingCacheSchema = _trendingCacheSchema;
      if (state.trendingCreators.isNotEmpty) {
        state = state.copyWith(
          trendingCreators: const <TrendingCreator>[],
          isLoadingTrendingCreators: true,
        );
      }
    }
    unawaited(_bootstrapDiscover());
  }

  Future<void> _bootstrapDiscover() async {
    await _restorePersistedTrendingCreators();
    final List<TrendingCreator> seeded = _cachedTrendingCreators.isNotEmpty
        ? _cachedTrendingCreators
        : state.trendingCreators;
    if (seeded.isNotEmpty) {
      state = state.copyWith(
        trendingCreators: seeded,
        trendingCreatorsLoadFailed: false,
        isLoadingTrendingCreators: false,
      );
      _preloadTrendingCreatorAvatars(seeded);
    }
    LikeInteractionBoundary.runAfterFirstInteraction(
      () => unawaited(loadTrendingCreators()),
      fallbackTimeout: const Duration(seconds: 20),
    );
    unawaited(loadRecommendedForYou());
  }

  void _preloadTrendingCreatorAvatars(List<TrendingCreator> creators) {
    for (final TrendingCreator creator in creators.take(10)) {
      final String? url = creator.avatarURL;
      if (url == null || url.isEmpty) {
        continue;
      }
      unawaited(ImagePreloadService.preloadImage(url));
    }
  }

  Future<void> _restorePersistedTrendingCreators() async {
    if (state.trendingCreators.isNotEmpty) {
      return;
    }
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_trendingPrefsKey);
      if (raw == null || raw.isEmpty) {
        return;
      }
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) {
        return;
      }
      final List<TrendingCreator> cached = decoded
          .whereType<Map>()
          .map((Map<dynamic, dynamic> item) {
            final Map<String, dynamic> data = item.cast<String, dynamic>();
            return TrendingCreator(
              id: (data['id'] as String?) ?? '',
              username: (data['username'] as String?) ?? 'Unknown',
              displayName: data['displayName'] as String?,
              avatarURL: data['avatarURL'] as String?,
              followerCount: (data['followerCount'] as num?)?.toInt() ?? 0,
              isActive: data['isActive'] == true,
              creatorLevel: (data['creatorLevel'] as num?)?.toInt() ?? 0,
              tierStatusLabel: data['tierStatusLabel'] as String?,
              isFollowing: data['isFollowing'] == true,
            );
          })
          .where((TrendingCreator creator) => creator.id.isNotEmpty)
          .toList(growable: false);
      if (cached.isEmpty) {
        return;
      }
      _cachedTrendingCreators = cached;
      state = state.copyWith(
        trendingCreators: cached,
        trendingCreatorsLoadFailed: false,
        isLoadingTrendingCreators: false,
      );
      _preloadTrendingCreatorAvatars(cached);
      CreatorCacheService.instance.preloadTrending(cached);
    } catch (e) {
      LoggingService.instance.debug(
        'Unable to restore cached trending creators: $e',
        tag: 'DiscoverProvider',
      );
    }
  }

  Future<void> _persistTrendingCreators(List<TrendingCreator> creators) async {
    if (creators.isEmpty) {
      return;
    }
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<Map<String, Object?>> payload = creators
          .map(
            (TrendingCreator creator) => <String, Object?>{
              'id': creator.id,
              'username': creator.username,
              'displayName': creator.displayName,
              'avatarURL': creator.avatarURL,
              'followerCount': creator.followerCount,
              'isActive': creator.isActive,
              'creatorLevel': creator.creatorLevel,
              'tierStatusLabel': creator.tierStatusLabel,
              'isFollowing': creator.isFollowing,
            },
          )
          .toList(growable: false);
      await prefs.setString(_trendingPrefsKey, jsonEncode(payload));
    } catch (e) {
      LoggingService.instance.debug(
        'Unable to persist cached trending creators: $e',
        tag: 'DiscoverProvider',
      );
    }
  }

  // removed duplicate placeholder implementation (replaced below)

  Future<List<HomeVideo>> fetchVideosForCategory(String categoryId) async {
    try {
      final CollectionReference<Map<String, dynamic>> col =
          FirebaseFirestore.instance.collection('videos');
      Query<Map<String, dynamic>> query;
      if (isAllCategorySlug(categoryId)) {
        query = col
            .where(
              'status',
              whereIn: kVideoVisibleInFeedStatuses.toList(growable: false),
            )
            .orderBy('createdAt', descending: true)
            .limit(10);
      } else {
        query = col
            .where('category_id', isEqualTo: categoryId)
            .where(
              'status',
              whereIn: kVideoVisibleInFeedStatuses.toList(growable: false),
            )
            .orderBy('score', descending: true)
            .limit(10);
      }

      final lastDoc = _categoryVideoCursors[categoryId];
      if (lastDoc != null) {
        query = query.startAfterDocument(lastDoc);
      }

      final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();
      final List<HomeVideo> videos = snapshot.docs.where((doc) {
        final Map<String, dynamic> data = doc.data();
        if (!isDiscoverEligibleFromFirestore(data, videoId: doc.id)) {
          return false;
        }
        return matchesDiscoverCategory(data, categoryId);
      }).map((doc) {
        final Map<String, dynamic> data = doc.data();
        final String playbackUrl = resolveReadyPlaybackUrl(data) ?? '';

        final User creator = User(
          id: (data['creator_id'] ?? 'unknown').toString(),
          username: (data['creator_username'] ?? 'unknown').toString(),
          displayName: (data['creator_display_name'] ?? 'Unknown').toString(),
          bio: data['creator_bio'] as String?,
          avatarURL: data['creator_avatar_url'] as String?,
          onlineStatus: (data['creator_online_status'] ?? 'online').toString(),
          hashtags: List<String>.from(
              (data['creator_hashtags'] as List?) ?? const <String>[]),
          postCount: (data['creator_post_count'] ?? 0) as int,
          followerCount: UserCountFields.readFollowersCount(<String, dynamic>{
            'followerCount': data['creator_follower_count'],
            'followersCount': data['creator_followers_count'],
          }),
          followingCount: UserCountFields.readFollowingCount(<String, dynamic>{
            'followingCount': data['creator_following_count'],
            'followingsCount': data['creator_followings_count'],
          }),
        );

        // Create thumbnails object from legacy thumbnailURL
        VideoThumbnails? thumbnails;
        final thumbnailUrl =
            (data['thumbnail_url'] ?? data['thumbnailURL']) as String?;
        if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
          thumbnails = VideoThumbnails(
            urls: {
              360: thumbnailUrl,
              540: thumbnailUrl,
              720: thumbnailUrl,
            },
            generatedAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
          );
        }

        return HomeVideo(
          id: doc.id,
          creator: creator,
          videoURL: playbackUrl,
          thumbnailURL: thumbnailUrl,
          thumbnails: thumbnails,
          likes: (data['likes'] ?? 0) as int,
          comments: (data['comments'] ?? 0) as int,
          views: (data['views'] ?? 0) as int,
          caption: resolveVideoCaptionFromFirestoreData(data),
          overlayCaption: resolveVideoOverlayCaptionFromFirestoreData(data),
          isLiked: (data['isLiked'] ?? false) as bool,
          isFavorited: (data['isFavorited'] ?? false) as bool,
          mlScore:
              ((data['score'] ?? data['mlScore'] ?? 0.0) as num).toDouble(),
          categoryId: (data['category_id'] ?? '').toString(),
          status: (data['status'] as String?) ?? 'ready',
          visibility: (data['visibility'] as String?) ?? 'public',
          isDeleted: data['isDeleted'] == true || data['deleted'] == true,
          deletedAt: data['deletedAt'] as Timestamp?,
        );
      }).toList();

      if (snapshot.docs.isNotEmpty) {
        _categoryVideoCursors[categoryId] = snapshot.docs.last;
      } else {
        _categoryVideoCursors.remove(categoryId);
      }

      return videos;
    } catch (e) {
      LoggingService.instance.error(
          'Error fetching videos for category $categoryId',
          tag: 'DiscoverProvider',
          error: e);
      return [];
    }
  }

  Future<void> loadRecommendedForYou() async {
    final uid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('userInterests')
          .doc(uid)
          .get();
      final interests = doc.data();
      if (interests == null || interests.isEmpty) return;

      final items = RecommendedContentExtension.samples.toList()
        ..sort((a, b) {
          final scoreA = _recommendedContentScore(a, interests);
          final scoreB = _recommendedContentScore(b, interests);
          return scoreB.compareTo(scoreA);
        });
      state = state.copyWith(recommendedContent: items);
    } catch (e) {
      LoggingService.instance.error(
        'Error loading personalized recommendations',
        tag: 'DiscoverProvider',
        error: e,
      );
    }
  }

  double _recommendedContentScore(
    RecommendedContent content,
    Map<String, dynamic> interests,
  ) {
    double read(String key) {
      final value = interests[key];
      return value is num ? value.toDouble() : 0.0;
    }

    switch (content.id) {
      case 'creator-tools':
        return read('creatorTools') + read('streamingTips') + read('editing');
      case 'academy':
        return read('growth') + read('gaming') + read('streamingTips');
      case 'peripherals':
        return read('streamingTips') + read('gaming') + read('esports');
      default:
        return 0;
    }
  }

  Future<void> loadTrendingCreators({bool forceRefresh = false}) async {
    if (_cachedTrendingCreators.isNotEmpty) {
      state = state.copyWith(trendingCreators: _cachedTrendingCreators);
    }
    final bool hasFreshTrendingCache = _cachedTrendingCreators.isNotEmpty &&
        _cachedTrendingCreatorsAt != null &&
        DateTime.now().difference(_cachedTrendingCreatorsAt!) <
            _trendingCacheTtl;
    if (!forceRefresh && hasFreshTrendingCache) {
      state = state.copyWith(
        isLoadingTrendingCreators: false,
        trendingCreatorsLoadFailed: false,
      );
      return;
    }
    final bool hasVisibleCreators =
        state.trendingCreators.isNotEmpty || _cachedTrendingCreators.isNotEmpty;
    if (state.isLoadingTrendingCreators && hasVisibleCreators) {
      return;
    }
    if (_trendingLoadInFlight != null) {
      await _trendingLoadInFlight;
      if (_cachedTrendingCreators.isNotEmpty) {
        state = state.copyWith(
          trendingCreators: _cachedTrendingCreators,
          isLoadingTrendingCreators: false,
          trendingCreatorsLoadFailed: false,
        );
      }
      return;
    }
    if (!hasVisibleCreators) {
      state = state.copyWith(
        isLoadingTrendingCreators: true,
        trendingCreatorsLoadFailed: false,
      );
    } else {
      state = state.copyWith(trendingCreatorsLoadFailed: false);
    }

    _trendingLoadInFlight = () async {
      LoggingService.instance.debug(
          'Loading trending creators from real data service',
          tag: 'DiscoverProvider');

      final List<TrendingCreator> trending =
          await _userDataService.getTrendingCreators(limit: 10);
      final firebase_auth.User? authUser =
          firebase_auth.FirebaseAuth.instance.currentUser;
      final List<TrendingCreator> enriched =
          await _enrichTrendingWithFollowState(trending, authUser?.uid);

      // Always apply enriched creators. Equality on IDs alone used to skip
      // updates when followerCount / isFollowing / avatar changed.
      state = state.copyWith(
        trendingCreators: enriched,
        isLoadingTrendingCreators: false,
        trendingCreatorsLoadFailed: false,
      );
      _cachedTrendingCreators = enriched;
      _cachedTrendingCreatorsAt = DateTime.now();
      CreatorCacheService.instance.preloadTrending(enriched);
      CreatorCacheService.instance.warmProfilesInBackground(
        enriched.map((TrendingCreator c) => c.id),
      );
      unawaited(_persistTrendingCreators(enriched));
      _preloadTrendingCreatorAvatars(enriched);
      LoggingService.instance.info(
          'Successfully loaded ${enriched.length} trending creators',
          tag: 'DiscoverProvider');
    }();

    try {
      await _trendingLoadInFlight;
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error loading trending creators',
          tag: 'DiscoverProvider', error: e, stackTrace: stackTrace);
      state = state.copyWith(
        isLoadingTrendingCreators: false,
        trendingCreatorsLoadFailed: true,
        trendingCreators: _cachedTrendingCreators,
      );
    } finally {
      _trendingLoadInFlight = null;
    }
  }

  Future<List<TrendingCreator>> _enrichTrendingWithFollowState(
    List<TrendingCreator> creators,
    String? currentUid,
  ) async {
    if (currentUid == null || currentUid.isEmpty) {
      return creators;
    }
    return Future.wait(creators.map((TrendingCreator c) async {
      if (c.id == currentUid) {
        return c.copyWith(isFollowing: false);
      }
      final bool following = await _followsService.isFollowing(c.id);
      return c.copyWith(isFollowing: following);
    }));
  }

  /// After follow/unfollow from Discover, patch counts and edge state.
  Future<void> patchTrendingCreatorAfterFollowAction(
    String creatorId, {
    required bool isFollowing,
  }) async {
    final int idx = state.trendingCreators
        .indexWhere((TrendingCreator c) => c.id == creatorId);
    if (idx < 0) {
      return;
    }
    final TrendingCreator current = state.trendingCreators[idx];
    int nextCount = current.followerCount;
    try {
      final Map<String, dynamic>? data =
          await PublicProfileFirestore.instance.getProfileMap(creatorId);
      if (data != null) {
        nextCount = UserCountFields.readFollowersCount(data);
      } else {
        final int delta = isFollowing ? 1 : -1;
        nextCount = (current.followerCount + delta).clamp(0, 1 << 30).toInt();
      }
    } catch (_) {
      final int delta = isFollowing ? 1 : -1;
      nextCount = (current.followerCount + delta).clamp(0, 1 << 30).toInt();
    }
    final List<TrendingCreator> next = List<TrendingCreator>.from(
      state.trendingCreators,
    );
    next[idx] = current.copyWith(
      isFollowing: isFollowing,
      followerCount: nextCount < 0 ? 0 : nextCount,
    );
    state = state.copyWith(trendingCreators: next);
  }

  void patchTrendingCreatorOptimistic(
    String creatorId, {
    required bool isFollowing,
    required int followerCount,
  }) {
    final int idx = state.trendingCreators
        .indexWhere((TrendingCreator c) => c.id == creatorId);
    if (idx < 0) {
      return;
    }
    final List<TrendingCreator> next = List<TrendingCreator>.from(
      state.trendingCreators,
    );
    next[idx] = next[idx].copyWith(
      isFollowing: isFollowing,
      followerCount: followerCount < 0 ? 0 : followerCount,
    );
    state = state.copyWith(trendingCreators: next);
  }

  Future<void> refreshDiscoverData() async {
    _categoryVideoCursors.clear();
    await loadTrendingCreators(forceRefresh: true);
  }

  /// 🔥 FIX: Update trending creators from real-time stream
  void updateTrendingCreators(List<TrendingCreator> creators) {
    state = state.copyWith(trendingCreators: creators);
    LoggingService.instance.debug(
        'Updated trending creators: ${creators.length}',
        tag: 'DiscoverProvider');
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
              .collection('publicUsers')
              .orderBy('username')
              .startAt([q])
              .endAt(["$q\uf8ff"])
              .limit(10)
              .get()
              .timeout(timeout);
          for (final d in qs1.docs) {
            final data = d.data();
            final followersCount = UserCountFields.readFollowersCount(data);
            results.add(SearchResult(
              id: d.id,
              title: (data['displayName'] ?? data['username'] ?? 'User')
                  .toString(),
              subtitle: '@${(data['username'] ?? '').toString()}',
              metadata: followersCount > 0 ? '$followersCount followers' : null,
              imageURL: data['avatarURL'] as String?,
              type: ResultType.creator,
            ));
          }
        } catch (e) {
          LoggingService.instance.warning('Username search failed',
              tag: 'DiscoverProvider', error: e);
        }

        // displayName prefix
        try {
          final qs2 = await db
              .collection('publicUsers')
              .orderBy('displayName')
              .startAt([q])
              .endAt(["$q\uf8ff"])
              .limit(10)
              .get()
              .timeout(timeout);
          for (final d in qs2.docs) {
            final data = d.data();
            final followersCount = UserCountFields.readFollowersCount(data);
            results.add(SearchResult(
              id: d.id,
              title: (data['displayName'] ?? data['username'] ?? 'User')
                  .toString(),
              subtitle: '@${(data['username'] ?? '').toString()}',
              metadata: followersCount > 0 ? '$followersCount followers' : null,
              imageURL: data['avatarURL'] as String?,
              type: ResultType.creator,
            ));
          }
        } catch (e) {
          LoggingService.instance.warning('DisplayName search failed',
              tag: 'DiscoverProvider', error: e);
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
            if (!isVideoVisibleInFeed(data)) continue;
            results.add(SearchResult(
              id: d.id,
              title: (data['title'] ?? 'Video').toString(),
              subtitle: (data['creator_username'] ?? data['creator'] ?? '')
                  .toString(),
              metadata: data['views'] != null ? '${data['views']} views' : null,
              imageURL: data['thumbnail_url'] as String?,
              type: ResultType.content,
            ));
          }
        } catch (e) {
          LoggingService.instance.warning('Video tags search failed',
              tag: 'DiscoverProvider', error: e);
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
            if (!isVideoVisibleInFeed(data)) continue;
            results.add(SearchResult(
              id: d.id,
              title: (data['title'] ?? 'Video').toString(),
              subtitle: (data['creator_username'] ?? data['creator'] ?? '')
                  .toString(),
              metadata: data['views'] != null ? '${data['views']} views' : null,
              imageURL: data['thumbnail_url'] as String?,
              type: ResultType.content,
            ));
          }
        } catch (e) {
          LoggingService.instance.warning('Video title search failed',
              tag: 'DiscoverProvider', error: e);
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
              .collection('publicUsers')
              .where('hashtags', arrayContains: qLower)
              .limit(10)
              .get();
          for (final d in qs1.docs) {
            final data = d.data();
            final hashtags =
                List<String>.from((data['hashtags'] as List?) ?? []);
            final matchingHashtags = hashtags
                .where((tag) => tag.toLowerCase().contains(qLower))
                .toList();

            if (matchingHashtags.isNotEmpty) {
              results.add(SearchResult(
                id: d.id,
                title: '#${matchingHashtags.first}',
                subtitle:
                    'Hashtag used by @${(data['username'] ?? '').toString()}',
                metadata: '${matchingHashtags.length} hashtags',
                imageURL: data['avatarURL'] as String?,
                type: ResultType.creator,
              ));
            }
          }
        } catch (e, st) {
          swallowNonFatal('DiscoverProvider.hashtagUserSearch', e, st);
        }

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
            if (!isVideoVisibleInFeed(data)) continue;
            final hashtags =
                List<String>.from((data['hashtags'] as List?) ?? []);
            final matchingHashtags = hashtags
                .where((tag) => tag.toLowerCase().contains(qLower))
                .toList();

            if (matchingHashtags.isNotEmpty) {
              results.add(SearchResult(
                id: d.id,
                title: '#${matchingHashtags.first}',
                subtitle:
                    'Hashtag in video by ${(data['creator_username'] ?? '').toString()}',
                metadata: '${data['views'] ?? 0} views',
                imageURL: data['thumbnail_url'] as String?,
                type: ResultType.content,
              ));
            }
          }
        } catch (e, st) {
          swallowNonFatal('DiscoverProvider.hashtagVideoSearch', e, st);
        }

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
      LoggingService.instance
          .error('Search failed', tag: 'DiscoverProvider', error: e);
      state = state.copyWith(searchResults: [], isSearching: false);
    }
  }

  void _trackSearchQuery(String query) {
    try {
      // Log search query for analytics
      LoggingService.instance
          .debug('Search query: "$query"', tag: 'DiscoverProvider');

      // Track search performance
      final searchStartTime = DateTime.now();

      // Store search metrics in state for analytics
      // This could be extended to send to Firebase Analytics
      LoggingService.instance.debug('Search started at: $searchStartTime',
          tag: 'DiscoverProvider');
    } catch (e) {
      LoggingService.instance.error('Error tracking search query',
          tag: 'DiscoverProvider', error: e);
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

    LoggingService.instance.debug(
        'User scrolled in category $categoryId, total scrolls: $newScrolls',
        tag: 'DiscoverProvider');

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

      LoggingService.instance.debug(
          'Increasing low viewed ratio for $categoryId to $newRatio',
          tag: 'DiscoverProvider');
    }
  }

  ({double lowViewedRatio, double highViewedRatio}) getAdaptiveBalance(
      String categoryId) {
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
    _categoryVideoCursors.remove(categoryId);

    LoggingService.instance.debug(
        'Reset user behavior for category $categoryId',
        tag: 'DiscoverProvider');
  }
}

final discoverProvider =
    StateNotifierProvider<DiscoverNotifier, DiscoverState>((ref) {
  return DiscoverNotifier();
});

class DiscoverCategoryVideosNotifier
    extends Notifier<Map<String, List<Map<String, dynamic>>>> {
  @override
  Map<String, List<Map<String, dynamic>>> build() =>
      <String, List<Map<String, dynamic>>>{};

  List<Map<String, dynamic>>? peek(String categoryId) {
    final List<Map<String, dynamic>>? cached = state[categoryId];
    if (cached == null || cached.isEmpty) {
      return null;
    }
    return cached;
  }

  void cacheVideos(String categoryId, List<Map<String, dynamic>> videos) {
    if (videos.isEmpty) {
      return;
    }
    state = <String, List<Map<String, dynamic>>>{
      ...state,
      categoryId: List<Map<String, dynamic>>.from(videos),
    };
  }
}

final NotifierProvider<DiscoverCategoryVideosNotifier,
        Map<String, List<Map<String, dynamic>>>>
    discoverCategoryVideosProvider = NotifierProvider<
        DiscoverCategoryVideosNotifier,
        Map<String, List<Map<String, dynamic>>>>(
  DiscoverCategoryVideosNotifier.new,
);

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
          thumbnailURL:
              'https://images.unsplash.com/photo-1542751371-adc38448a05e?w=300&h=400&fit=crop&crop=center',
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
          thumbnailURL:
              'https://images.unsplash.com/photo-1541961017774-22349e4a1262?w=300&h=400&fit=crop&crop=center',
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
          thumbnailURL:
              'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=300&h=400&fit=crop&crop=center',
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
          thumbnailURL:
              'https://images.unsplash.com/photo-1518709268805-4e9042af2176?w=300&h=400&fit=crop&crop=center',
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
          thumbnailURL:
              'https://images.unsplash.com/photo-1546519638-68e109498ffc?w=300&h=400&fit=crop&crop=center',
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
          thumbnailURL:
              'https://images.unsplash.com/photo-1556909114-f6e7ad7d3136?w=300&h=400&fit=crop&crop=center',
          videoURL: 'https://example.com/video6.mp4',
          views: 9500,
          likes: 720,
          duration: 4.25,
          categoryId: 'food',
          tags: ['food', 'cooking', 'tutorial'],
        ),
      ];
}
