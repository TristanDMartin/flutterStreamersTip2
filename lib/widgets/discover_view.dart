import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import '../providers/discover_provider.dart';
import '../providers/activity_provider.dart';
import '../providers/unread_messages_provider.dart';
import '../models/creator_profile_snapshot.dart';
import '../models/trending_creator.dart';
import '../utils/user_facing_error.dart';
import '../models/category.dart' as discover_models;
import 'category_card.dart';
import 'recommended_content_card.dart';
import '../services/logging_service.dart';
import '../services/caching_service.dart';
import '../services/accessibility_service.dart';
import '../services/global_playback_manager.dart';
import '../constants/playback_owners.dart';
import '../core/feature_flags.dart';
import '../core/theme/st_theme_tokens.dart';
import 'instant_response_button.dart';
import 'video_player_view_optimized.dart';
import '../models/home_video.dart';
import '../models/user.dart';
import '../providers/home_provider.dart' as hp;
import '../providers/follow_refresh_provider.dart';
import 'comments_view2.dart';
import 'enhanced_share_sheet.dart';
import '../features/academy/academy_providers.dart';
import '../routing/app_navigator.dart';
import '../features/discover/presentation/widgets/trending_creators_section.dart';
import '../utils/video_caption_resolver.dart';
import '../features/discover/domain/discover_field_mapper.dart';
import '../features/feed/domain/discover_category_card_map.dart';
import '../features/feed/domain/discover_eligible_videos.dart';
import '../features/feed/domain/discover_source_audit.dart';
import '../utils/category_schema.dart';
import '../utils/discover_category_rules.dart';
import '../utils/video_document_rules.dart';
import '../utils/video_url_resolver.dart';
// import 'video_thumbnail_view.dart'; // Removed - unused

class STDiscoverTokens {
  static const double pagePadding = 20.0;
  static const double sectionGap = 24.0;
  static const double cardRadius = 24.0;
  static const double compactCardRadius = 18.0;
  static const double creatorCardHeight = 178.0;
  static const double categoryCardHeight = 82.0;
  static const double heroHeight = 164.0;
  static const double searchHeight = 56.0;
}

class _DiscoverPageStyle {
  _DiscoverPageStyle({
    required this.isLight,
    required this.scaffold,
    required this.appBar,
    required this.onAppBar,
    required this.refreshColor,
    required this.refreshBackground,
    required this.heroGradient,
    required this.heroBorder,
    required this.searchFill,
    required this.searchBorder,
    required this.searchPlaceholder,
    required this.searchChevron,
    required this.cardFill,
    required this.cardBorder,
    required this.onCard,
    required this.muted,
  });

  final bool isLight;
  final Color scaffold;
  final Color appBar;
  final Color onAppBar;
  final Color refreshColor;
  final Color refreshBackground;
  final List<Color> heroGradient;
  final Color heroBorder;
  final Color searchFill;
  final Color searchBorder;
  final Color searchPlaceholder;
  final Color searchChevron;
  final Color cardFill;
  final Color cardBorder;
  final Color onCard;
  final Color muted;

  static _DiscoverPageStyle of(BuildContext context) {
    final ThemeData t = Theme.of(context);
    final ColorScheme c = t.colorScheme;
    if (t.brightness == Brightness.light) {
      return _DiscoverPageStyle(
        isLight: true,
        scaffold: t.scaffoldBackgroundColor,
        appBar: Colors.transparent,
        onAppBar: c.onSurface,
        refreshColor: c.primary,
        refreshBackground: t.scaffoldBackgroundColor,
        heroGradient: <Color>[
          StThemeColors.brandPurple,
          StThemeColors.brandBlue,
        ],
        heroBorder: c.outline.withValues(alpha: 0.35),
        searchFill: c.surfaceContainerHighest.withValues(alpha: 0.92),
        searchBorder: c.outline.withValues(alpha: 0.18),
        searchPlaceholder: c.onSurface.withValues(alpha: 0.55),
        searchChevron: c.onSurface.withValues(alpha: 0.35),
        cardFill: c.surface,
        cardBorder: c.outline.withValues(alpha: 0.14),
        onCard: c.onSurface,
        muted: c.onSurface.withValues(alpha: 0.62),
      );
    }
    return _DiscoverPageStyle(
      isLight: false,
      scaffold: t.scaffoldBackgroundColor,
      appBar: Colors.transparent,
      onAppBar: c.onSurface,
      refreshColor: c.primary,
      refreshBackground: t.scaffoldBackgroundColor,
      heroGradient: <Color>[
        StThemeColors.brandPurple,
        StThemeColors.brandBlue,
      ],
      heroBorder: c.outline.withValues(alpha: 0.28),
      searchFill: c.surfaceContainerHigh.withValues(alpha: 0.88),
      searchBorder: c.outline.withValues(alpha: 0.22),
      searchPlaceholder: c.onSurfaceVariant,
      searchChevron: c.onSurface.withValues(alpha: 0.4),
      cardFill: c.surfaceContainerHigh.withValues(alpha: 0.72),
      cardBorder: c.outline.withValues(alpha: 0.2),
      onCard: c.onSurface,
      muted: c.onSurfaceVariant,
    );
  }
}

class DiscoverView extends ConsumerStatefulWidget {
  const DiscoverView({
    super.key,
    this.showAppBarBackButton = true,
  });

  /// When false (e.g. main tab shell), hide the app bar back action.
  final bool showAppBarBackButton;

  /// Full-screen category swipe feed. Kept on [DiscoverView] instead of
  /// [AppNavigator] to avoid a circular import (discover already imports
  /// navigator for other routes).
  static Future<T?> openCategoryVideoSwipeFeed<T>(
    BuildContext context, {
    required List<HomeVideo> videos,
    required int startIndex,
    required String categoryId,
  }) {
    return Navigator.of(context).push<T>(
      MaterialPageRoute<T>(
        builder: (BuildContext context) => DiscoverCategoryVideoFeedPage(
          videos: videos,
          startIndex: startIndex,
          categoryId: categoryId,
        ),
      ),
    );
  }

  @override
  ConsumerState<DiscoverView> createState() => _DiscoverViewState();
}

class _DiscoverViewState extends ConsumerState<DiscoverView>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  static const int _videosPerPage = 20;
  String? _selectedCategory;
  int _categoryPageIndex = 0;
  final ScrollController _discoverScrollController = ScrollController();
  final Map<String, Future<List<Map<String, dynamic>>>> _categoryFeedFutures =
      {};

  static const Map<String, List<String>> _categoryAliases = {
    'all': ['all'],
    'general': ['general', 'uncategorized', 'other'],
    'gaming': ['gaming', 'games', 'gameplay'],
    'art': ['art', 'artist', 'creative'],
    'music': ['music', 'musician', 'songs'],
    'tech': ['tech', 'technology', 'technical', 'gadgets'],
    'sports': ['sports', 'sport', 'athletics'],
    'food': ['food', 'cooking', 'recipe'],
    'just-chatting': ['just-chatting', 'just chatting', 'chatting', 'chat'],
    'tutorials': ['tutorials', 'tutorial', 'how-to', 'how to'],
    'fitness': ['fitness', 'workout', 'health'],
    'podcasts': ['podcasts', 'podcast'],
    'fashion': ['fashion', 'style'],
    'roleplay': ['roleplay', 'role-play', 'rp'],
  };

  String _normalizeCategoryKey(String value) => normalizeCategorySlug(value);

  Iterable<String> _expandCategoryForms(String value) sync* {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;

    final normalized = _normalizeCategoryKey(trimmed);
    final spaced = normalized.replaceAll('-', ' ');
    final underscored = normalized.replaceAll('-', '_');

    yield trimmed;
    yield trimmed.toLowerCase();
    yield normalized;
    yield spaced;
    yield underscored;
    yield normalized.replaceAll('-', '');
  }

  String? _getCategoryName(String categoryId) {
    for (final category in discover_models.Category.samples) {
      if (_normalizeCategoryKey(category.id) ==
          _normalizeCategoryKey(categoryId)) {
        return category.name;
      }
    }
    return null;
  }

  List<String> _getCategoryQueryValues(String categoryId) {
    final canonicalId = _normalizeCategoryKey(categoryId);
    final aliases = _categoryAliases[canonicalId] ?? [categoryId];
    final displayName = _getCategoryName(categoryId);
    final values = <String>{};

    for (final alias in aliases) {
      values.addAll(_expandCategoryForms(alias));
    }
    if (displayName != null) {
      values.addAll(_expandCategoryForms(displayName));
    }

    return values.take(10).toList();
  }

  bool _videoMatchesCategory(Map<String, dynamic> data, String categoryId) {
    return matchesDiscoverCategory(data, categoryId);
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _fetchCategoryDocs({
    required List<String> categoryValues,
    required int limit,
    DocumentSnapshot? startAfter,
    String? rangeField,
    Object? isGreaterThan,
    String? orderByField,
    bool descending = true,
    bool allowOrderlessFallback = false,
  }) async {
    const scalarCategoryFields = ['category', 'categoryId', 'category_id'];

    Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> runQuery(
      String field, {
      required bool ordered,
    }) async {
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('videos')
          .where(field, whereIn: categoryValues);

      if (rangeField != null && isGreaterThan != null) {
        query = query.where(rangeField, isGreaterThan: isGreaterThan);
      }

      if (ordered && orderByField != null) {
        query = query.orderBy(orderByField, descending: descending);
      }

      query = query.limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      return snapshot.docs;
    }

    for (final field in scalarCategoryFields) {
      try {
        final docs = await runQuery(field, ordered: orderByField != null);
        if (docs.isNotEmpty) return docs;
      } catch (e) {
        LoggingService.instance.debug(
          'Category query failed for $field${orderByField != null ? ' with orderBy $orderByField' : ''}: $e',
          tag: 'DiscoverView',
        );
      }

      if (!allowOrderlessFallback ||
          orderByField == null ||
          rangeField != null) {
        continue;
      }

      try {
        final docs = await runQuery(field, ordered: false);
        if (docs.isNotEmpty) return docs;
      } catch (e) {
        LoggingService.instance.debug(
          'Category query failed for $field without orderBy: $e',
          tag: 'DiscoverView',
        );
      }
    }

    try {
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('videos')
          .where('categories', arrayContainsAny: categoryValues);

      if (rangeField != null && isGreaterThan != null) {
        query = query.where(rangeField, isGreaterThan: isGreaterThan);
      }

      if (orderByField != null) {
        query = query.orderBy(orderByField, descending: descending);
      }

      query = query.limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs;
      }
    } catch (e) {
      LoggingService.instance.debug(
        'Category query failed for categories array${orderByField != null ? ' with orderBy $orderByField' : ''}: $e',
        tag: 'DiscoverView',
      );
    }

    return const [];
  }

  List<Map<String, dynamic>> _mapVideoDocsToFeedItems(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String categoryId,
  ) {
    final videos = <Map<String, dynamic>>[];

    for (final doc in docs) {
      final Map<String, dynamic> data = doc.data();
      if (!isDiscoverEligibleFromFirestore(data, videoId: doc.id)) {
        continue;
      }
      if (!matchesDiscoverCategory(
        data,
        categoryId,
        enableDiagnostics: kDebugMode,
        videoId: doc.id,
      )) {
        continue;
      }

      videos.add(_fullCategoryVideoMap(
        docId: doc.id,
        data: data,
        categoryId: categoryId,
      ));
    }

    return videos;
  }

  Map<String, dynamic> _fullCategoryVideoMap({
    required String docId,
    required Map<String, dynamic> data,
    Map<String, dynamic>? userData,
    required String categoryId,
    bool isNew = false,
    double trendingScore = 0.0,
  }) {
    final muxPlaybackId = _firstString(data, const [
      'muxPlaybackId',
      'playbackId',
      'mux_playback_id',
    ]);
    final String? readyPlayback = resolveReadyPlaybackUrl(data);
    final hlsUrl = readyPlayback ??
        _firstString(data, const [
          'hlsUrl',
          'playbackUrl',
          'streamUrl',
          'hls_url',
          'playbackURL',
          'canonicalPlaybackUrl',
        ]);
    final videoUrl = readyPlayback ??
        _firstString(data, const [
          'videoUrl',
          'downloadUrl',
          'url',
          'fileUrl',
          'videoURL',
          'video_url',
        ]);
    final thumbnailUrl = _firstString(data, const [
      'thumbnailUrl',
      'thumbnail',
      'muxThumbnailUrl',
      'thumbnailURL',
    ]);
    final userId = _firstString(data, const [
      'userId',
      'creatorId',
      'creator_id',
      'uid',
      'ownerId',
    ]);
    final profile = userData ?? data;
    final durationValue = data['duration'] ??
        (data['metadata'] is Map ? data['metadata']['duration'] : null);
    final caption = DiscoverFieldMapper.safeString(
      data['caption'] ??
          data['title'] ??
          (data['metadata'] is Map ? data['metadata']['title'] : null) ??
          'Untitled',
    );
    final CanonicalCategory canonical = readCanonicalCategoryFromVideo(data);
    final String categoryValue = canonical.isPopulated
        ? canonical.categoryId
        : _firstString(data, const ['category', 'categoryId', 'category_id']);
    final String categoryIdValue = canonical.isPopulated
        ? canonical.categoryId
        : _firstString(data, const ['categoryId', 'category', 'category_id']);
    final String categoryNameValue = canonical.isPopulated
        ? canonical.categoryName
        : categoryDisplayNameForId(
            categoryIdValue.isNotEmpty ? categoryIdValue : categoryId,
          );

    return {
      'id': docId,
      'docId': docId,
      'videoId': docId,
      'userId': userId,
      'creatorId': userId,
      'caption': caption,
      'title': caption,
      'muxPlaybackId': muxPlaybackId,
      'hlsUrl': hlsUrl,
      'videoUrl': videoUrl,
      'videoURL': videoUrl,
      'canonicalPlaybackUrl': readyPlayback ?? hlsUrl,
      'thumbnailUrl': thumbnailUrl,
      'thumbnail': thumbnailUrl,
      'thumbnailURL': thumbnailUrl,
      'status': DiscoverFieldMapper.safeString(data['status']),
      'isReadyForFeed': data['isReadyForFeed'] == true,
      'isDeleted': data['isDeleted'] == true || data['deleted'] == true,
      'deleted': data['isDeleted'] == true || data['deleted'] == true,
      'deletedAt': data['deletedAt'],
      'visible': data['visible'],
      'createdAt': data['createdAt'],
      'category': categoryValue.isNotEmpty ? categoryValue : categoryId,
      'categoryId': categoryIdValue.isNotEmpty ? categoryIdValue : categoryId,
      'categoryName': categoryNameValue,
      'likeCount': DiscoverFieldMapper.safeCount(
          data, const ['likeCount', 'likesCount', 'likes']),
      'bookmarkCount': DiscoverFieldMapper.safeCount(data, const [
        'bookmarkCount',
        'bookmarksCount',
        'savesCount',
        'bookmarks',
        'favoriteCount',
        'favorites',
      ]),
      'commentCount': DiscoverFieldMapper.safeCount(
          data, const ['commentCount', 'commentsCount', 'comments']),
      'likes': DiscoverFieldMapper.safeCount(
          data, const ['likeCount', 'likesCount', 'likes']),
      'comments': DiscoverFieldMapper.safeCount(
          data, const ['commentCount', 'commentsCount', 'comments']),
      'views': DiscoverFieldMapper.safeCount(
          data, const ['viewCount', 'views', 'viewsCount']),
      'duration': DiscoverFieldMapper.safeDouble(durationValue),
      'creator': DiscoverFieldMapper.getDisplayName(profile),
      'creatorAvatar': DiscoverFieldMapper.getAvatarUrl(profile),
      'creatorUsername': DiscoverFieldMapper.safeString(profile['username']),
      'creatorDisplayName': DiscoverFieldMapper.getDisplayName(profile),
      'creatorBio': DiscoverFieldMapper.safeString(profile['bio']),
      'creatorHashtags': profile['hashtags'] ?? const [],
      'creatorFollowers': DiscoverFieldMapper.safeCount(profile, const [
        'followerCount',
        'followersCount',
        'followers',
      ]),
      'creatorFollowing': DiscoverFieldMapper.safeCount(profile, const [
        'followingCount',
        'following',
      ]),
      'creatorVideos':
          DiscoverFieldMapper.safeCount(profile, const ['postCount', 'videos']),
      'isLiked': data['isLiked'] == true,
      'isFavorited':
          data['isFavorited'] == true || data['isBookmarked'] == true,
      'trendingScore': trendingScore,
      'isNew': isNew,
      'isTrending': trendingScore > 100.0,
    };
  }

  // ✅ FIX #5: Removed unused _cachedVideos - cache implementation reserved for future
  // Cache timestamps and TTL are reserved for future implementation

  // Services
  final CachingService _cachingService = CachingService();
  final AccessibilityService _accessibilityService = AccessibilityService();

  // 🔥 FIX: Real-time subscriptions
  StreamSubscription<QuerySnapshot>? _trendingCreatorsSubscription;
  Timer? _trendingRefreshTimer;
  Timer? _trendingUploadDebounce;

  // 🔥 FIX: Consistent spacing and sizing constants
  // Note: These constants are reserved for future UI improvements

  @override
  void initState() {
    super.initState();

    // 🎯 SINGLE ACTIVE OWNER:
    // Active owner is set centrally (AppNavigationObserver) based on route changes.

    // Initialize accessibility service
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _accessibilityService.initialize(context);
      _loadInitialData();
      _setupRealtimeUpdates(); // 🔥 FIX: Add real-time updates
    });
  }

  @override
  void dispose() {
    _trendingCreatorsSubscription?.cancel();
    _trendingRefreshTimer?.cancel();
    _trendingUploadDebounce?.cancel();
    _discoverScrollController.dispose();
    super.dispose();
  }

  void _loadInitialData() {
    try {
      LoggingService.instance.debug(
        'Loading initial data',
        tag: 'DiscoverView',
      );
      final List<Map<String, dynamic>>? cachedAll =
          ref.read(discoverCategoryVideosProvider.notifier).peek('All');
      if (cachedAll != null) {
        _categoryFeedFutures['All'] = Future<List<Map<String, dynamic>>>.value(
          cachedAll,
        );
      }
      ref.read(discoverProvider);
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Error loading initial data',
        tag: 'DiscoverView',
        error: e,
        stackTrace: stackTrace,
      );
      // Safe error handling - don't call ErrorHandlerService during startup
      if (kDebugMode) {
        debugPrint('❌ DiscoverView initialization error: $e');
      }
    }
  }

  Future<void> _refreshDiscoverView() async {
    _cachingService.clearMemoryCache();
    _categoryFeedFutures.clear();
    await ref.read(discoverProvider.notifier).refreshDiscoverData();
    final selectedCategory = _selectedCategory;
    if (selectedCategory != null) {
      _primeCategoryFeed(selectedCategory);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Discover updated'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1200),
        backgroundColor: StThemeColors.darkSurface.withValues(alpha: 0.94),
      ),
    );
  }

  /// Set up trending refresh. Avoids a no-op notifications listener and
  /// debounces the "new videos" query so every upload does not thrash.
  void _setupRealtimeUpdates() {
    try {
      LoggingService.instance.debug(
        'Setting up real-time updates',
        tag: 'DiscoverView',
      );
      _setupTrendingCreatorsRefresh();
      LoggingService.instance.debug(
        'Real-time updates setup complete',
        tag: 'DiscoverView',
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Error setting up real-time updates',
        tag: 'DiscoverView',
        error: e,
        stackTrace: stackTrace,
      );
      if (kDebugMode) {
        debugPrint('❌ DiscoverView real-time setup error: $e');
      }
    }
  }

  /// Refresh trending creators periodically; debounce video upload stream.
  void _setupTrendingCreatorsRefresh() {
    _trendingRefreshTimer?.cancel();
    _trendingRefreshTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      LoggingService.instance.debug(
        '🔄 Refreshing trending creators based on video performance...',
        tag: 'DiscoverView',
      );
      ref.read(discoverProvider.notifier).loadTrendingCreators();
    });

    _trendingCreatorsSubscription?.cancel();
    _trendingCreatorsSubscription = FirebaseFirestore.instance
        .collection('videos')
        .where(
          'createdAt',
          isGreaterThan: Timestamp.fromDate(
            DateTime.now().subtract(const Duration(hours: 1)),
          ),
        )
        .limit(50)
        .snapshots()
        .listen(
      (snapshot) {
        if (!mounted || snapshot.docs.isEmpty) {
          return;
        }
        _trendingUploadDebounce?.cancel();
        _trendingUploadDebounce = Timer(const Duration(seconds: 8), () {
          if (!mounted) {
            return;
          }
          LoggingService.instance.debug(
            '🔥 New videos detected, refreshing trending creators...',
            tag: 'DiscoverView',
          );
          ref.read(discoverProvider.notifier).loadTrendingCreators();
        });
      },
      onError: (error) {
        LoggingService.instance.error(
          'Error in trending creators refresh stream',
          tag: 'DiscoverView',
          error: error,
        );
      },
    );
  }

  void _primeCategoryFeed(String categoryId) {
    _categoryFeedFutures[categoryId] = _getCategoryVideosForFeed(categoryId);
  }

  Future<void> _refreshCategoryVideosInBackground(String categoryId) async {
    final List<Map<String, dynamic>> fresh =
        await _getCategoryVideosForFeed(categoryId);
    if (!mounted) {
      return;
    }
    ref.read(discoverCategoryVideosProvider.notifier).cacheVideos(
          categoryId,
          fresh,
        );
    if (_selectedCategory != categoryId) {
      return;
    }
    setState(() {
      _categoryFeedFutures[categoryId] =
          Future<List<Map<String, dynamic>>>.value(fresh);
    });
  }

  void _onCreatorTapped(TrendingCreator creator) {
    HapticFeedback.lightImpact();
    LoggingService.instance.debug(
      'Creator tapped: ${creator.username} (ID: ${creator.id})',
      tag: 'DiscoverView',
    );
    if (creator.id.isEmpty) {
      LoggingService.instance.warning(
        'Invalid creator ID: empty',
        tag: 'DiscoverView',
      );
      return;
    }
    AppNavigator.openStreamerCard(
      context,
      userId: creator.id,
      initialCreator: CreatorProfileSnapshot.fromTrendingCreator(creator),
      currentUserId: fa.FirebaseAuth.instance.currentUser?.uid,
      onDismiss: () => Navigator.of(context).pop(),
      onMessage: (String userId) {
        HapticFeedback.lightImpact();
        LoggingService.instance.debug(
          'Message action for user: $userId',
          tag: 'DiscoverView',
        );
      },
      onNavigateToTab: (String tabName) {
        HapticFeedback.lightImpact();
      },
      onShare: (String userId) {
        HapticFeedback.lightImpact();
      },
    );
  }

  String _formatCompactCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    }
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return '$count';
  }

  Widget _buildVideoGridSkeleton(BuildContext context) {
    final _DiscoverPageStyle s = _DiscoverPageStyle.of(context);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.64,
      ),
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: s.isLight
                ? StThemeColors.darkSurface.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Container(
              width: 76,
              height: 12,
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: s.isLight
                    ? Colors.white.withValues(alpha: 0.75)
                    : Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: _accessibilityService.getAccessibleIconSize(48),
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to load creators',
            style: _accessibilityService.getAccessibleTextStyle(
              baseStyle: Theme.of(context).textTheme.headlineSmall!,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: _accessibilityService.getAccessibleTextStyle(
              baseStyle: Theme.of(context).textTheme.bodyMedium!,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _onCategorySelected(discover_models.Category category) {
    try {
      HapticFeedback.lightImpact();
      final String categoryId = category.id;
      final String? previousSelectedCategory = _selectedCategory;
      if (_selectedCategory == categoryId) {
        if (kDebugMode) {
          debugPrint(
            'Discover category deselect: selectedCategoryId=$categoryId '
            'selectedCategoryLabel=${category.name} '
            'previousSelectedCategory=$previousSelectedCategory',
          );
        }
        setState(() {
          _selectedCategory = null;
        });
        return;
      }
      if (kDebugMode) {
        debugPrint(
          'Discover category select: selectedCategoryId=$categoryId '
          'selectedCategoryLabel=${category.name} '
          'previousSelectedCategory=$previousSelectedCategory '
          'didForceRefresh=true',
        );
      }
      final List<Map<String, dynamic>>? cached =
          ref.read(discoverCategoryVideosProvider.notifier).peek(categoryId);
      setState(() {
        _selectedCategory = categoryId;
        if (cached != null) {
          _categoryFeedFutures[categoryId] =
              Future<List<Map<String, dynamic>>>.value(cached);
          unawaited(_refreshCategoryVideosInBackground(categoryId));
        } else {
          _categoryFeedFutures[categoryId] =
              _getCategoryVideosForFeed(categoryId);
        }
      });
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Error selecting category',
        tag: 'DiscoverView',
        error: e,
        stackTrace: stackTrace,
      );
      if (kDebugMode) {
        debugPrint('❌ DiscoverView category selection error: $e');
      }
    }
  }

  void _navigateToActivity(BuildContext context) {
    LoggingService.instance.debug(
      'Bell icon tapped - navigating to ActivityView',
      tag: 'DiscoverView',
    );
    try {
      // Mark-as-read happens inside ActivityView after items load so the
      // badge never clears while the list is still empty.
      AppNavigator.openActivity(context);
      LoggingService.instance.debug(
        'Navigation push completed',
        tag: 'DiscoverView',
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Navigation error',
        tag: 'DiscoverView',
        error: e,
        stackTrace: stackTrace,
      );
      // Safe error handling - don't call ErrorHandlerService during startup
      if (kDebugMode) {
        debugPrint('❌ DiscoverView navigation error: $e');
      }
    }
  }

  /// Safely cast dynamic data to a string list for hashtags.
  List<String> _safeCastToStringList(dynamic data) {
    if (data == null) return [];

    if (data is List) {
      return data.map((item) => item.toString()).toList();
    }

    if (data is String) {
      // If it's a single string, return it as a list with one item
      return [data];
    }

    // For any other type, convert to string and return as single-item list
    return [data.toString()];
  }

  /// Convert video data from DiscoverView format to HomeVideo model
  // ignore: unused_element
  HomeVideo _convertToHomeVideo(Map<String, dynamic> video) {
    final raw = _normalizedVideoData(video);
    final docId = DiscoverFieldMapper.safeString(video['docId']);
    final muxPlaybackId = _firstString(raw, const [
      'muxPlaybackId',
      'playbackId',
      'mux_playback_id',
    ]);
    final playbackUrl = _playbackUrlFor(raw);
    final thumbnailUrl = _firstString(raw, const [
      'thumbnailUrl',
      'thumbnailURL',
      'thumbnail',
      'muxThumbnailUrl',
    ]);
    final fallbackThumbnail = muxPlaybackId.isEmpty
        ? ''
        : 'https://image.mux.com/$muxPlaybackId/thumbnail.jpg?width=720&time=0';
    final creatorData = raw['creator'];
    final creatorMap =
        creatorData is Map ? Map<String, dynamic>.from(creatorData) : raw;
    final creatorId = _firstString(raw, const [
      'userId',
      'creatorId',
      'creator_id',
      'uid',
      'ownerId',
    ]);
    final creatorName = _firstString(creatorMap, const [
      'creatorUsername',
      'username',
      'displayName',
      'name',
      'creator',
    ]);
    final creatorDisplayName = _firstString(creatorMap, const [
      'creatorDisplayName',
      'displayName',
      'name',
      'creator',
      'username',
    ]);
    final caption = resolveVideoCaptionFromFirestoreData(raw);
    final overlayCaption = resolveVideoOverlayCaptionFromFirestoreData(raw);
    final id = _firstString(raw, const [
      'id',
      'videoId',
      'docId',
    ]);

    return HomeVideo(
      id: id.isNotEmpty
          ? id
          : (docId.isNotEmpty
              ? docId
              : 'discover_${DateTime.now().millisecondsSinceEpoch}'),
      videoURL: playbackUrl,
      thumbnailURL: thumbnailUrl.isNotEmpty ? thumbnailUrl : fallbackThumbnail,
      caption: caption,
      overlayCaption: overlayCaption,
      creator: User(
        id: creatorId.isNotEmpty ? creatorId : 'unknown_creator',
        username: creatorName.isNotEmpty ? creatorName : 'Unknown Creator',
        displayName: creatorDisplayName.isNotEmpty
            ? creatorDisplayName
            : 'Unknown Creator',
        avatarURL: _firstString(creatorMap, const [
          'creatorAvatar',
          'avatarUrl',
          'avatarURL',
          'profileImageUrl',
          'photoUrl',
        ]),
        bio: DiscoverFieldMapper.safeString(
            creatorMap['creatorBio'] ?? raw['bio']),
        hashtags: _safeCastToStringList(
          creatorMap['creatorHashtags'] ?? raw['hashtags'] ?? raw['tags'],
        ),
        followerCount: DiscoverFieldMapper.safeCount(creatorMap, const [
          'creatorFollowers',
          'followers',
          'followerCount',
        ]),
        followingCount: DiscoverFieldMapper.safeCount(creatorMap, const [
          'creatorFollowing',
          'following',
          'followingCount',
        ]),
        postCount: DiscoverFieldMapper.safeCount(creatorMap, const [
          'creatorVideos',
          'videos',
          'postCount',
        ]),
      ),
      likes: DiscoverFieldMapper.safeCount(
          raw, const ['likeCount', 'likesCount', 'likes']),
      comments: DiscoverFieldMapper.safeCount(
          raw, const ['commentCount', 'commentsCount', 'comments']),
      views: DiscoverFieldMapper.safeCount(raw, const ['viewCount', 'views']),
      duration: DiscoverFieldMapper.safeDouble(
        raw['duration'] ??
            (raw['metadata'] is Map
                ? (raw['metadata'] as Map)['duration']
                : null),
      ),
      isLiked: raw['isLiked'] == true,
      isFavorited: raw['isFavorited'] == true || raw['isBookmarked'] == true,
      categoryId:
          _firstString(raw, const ['categoryId', 'category', 'category_id']),
      status: _firstString(raw, const ['status']).isNotEmpty
          ? _firstString(raw, const ['status'])
          : 'ready',
      createdAt:
          raw['createdAt'] is Timestamp ? raw['createdAt'] : Timestamp.now(),
    );
  }

  Map<String, dynamic> _normalizedVideoData(Map<String, dynamic> video) {
    final Map<String, dynamic> merged = Map<String, dynamic>.from(video);
    final dynamic nested = video['data'];
    if (nested is Map) {
      final Map<String, dynamic> dataMap = Map<String, dynamic>.from(nested);
      merged
        ..addAll(dataMap)
        ..['data'] = dataMap;
    }
    const List<String> displayKeys = <String>[
      'docId',
      'id',
      'thumbnailUrl',
      'thumbnailURL',
      'thumbnail',
      'muxPlaybackId',
      'videoUrl',
      'videoURL',
      'hlsUrl',
      'creatorUsername',
      'creatorDisplayName',
      'creatorAvatar',
      'creator',
      'likes',
      'likeCount',
      'views',
      'viewCount',
      'comments',
    ];
    for (final String key in displayKeys) {
      final dynamic value = video[key];
      if (value == null) {
        continue;
      }
      if (value is String && value.trim().isEmpty) {
        continue;
      }
      merged[key] = value;
    }
    return merged;
  }

  String _discoverCardCreatorLabel(Map<String, dynamic> raw) {
    final String username = DiscoverFieldMapper.safeString(
      raw['creatorUsername'] ?? raw['creator_username'] ?? raw['username'],
    );
    if (username.isNotEmpty &&
        username.toLowerCase() != 'creator' &&
        username.toLowerCase() != 'unknown') {
      return username.startsWith('@') ? username : '@$username';
    }
    final String displayName = DiscoverFieldMapper.safeString(
      raw['creatorDisplayName'] ??
          raw['creator_display_name'] ??
          raw['displayName'] ??
          raw['creator'],
    );
    if (displayName.isNotEmpty &&
        displayName.toLowerCase() != 'creator' &&
        displayName.toLowerCase() != 'unknown') {
      return displayName.startsWith('@') ? displayName : '@$displayName';
    }
    return '';
  }

  String _firstString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  String _playbackUrlFor(Map<String, dynamic> data) {
    return resolveReadyPlaybackUrl(data) ?? '';
  }

  // ignore: unused_element
  String _playbackSourceFor(Map<String, dynamic> data) {
    if (_firstString(
            data, const ['muxPlaybackId', 'playbackId', 'mux_playback_id'])
        .isNotEmpty) {
      return 'mux';
    }
    if (_firstString(
            data, const ['hlsUrl', 'hlsURL', 'playbackUrl', 'streamUrl'])
        .isNotEmpty) {
      return 'hls';
    }
    if (_firstString(data, const [
      'videoUrl',
      'videoURL',
      'downloadUrl',
      'url',
      'fileUrl'
    ]).isNotEmpty) {
      return 'videoUrl';
    }
    return 'missing';
  }

  Widget _buildNotificationButton(BuildContext context, WidgetRef ref) {
    final unreadCountAsync = ref.watch(unreadMessagesProvider);
    final int activityUnreadCount =
        ref.watch(unreadActivityCountProvider).valueOrNull ?? 0;
    final activityState = ref.watch(activityProvider);

    // Messages + Firestore activity unread (same source as profile avatar).
    int totalUnreadCount = activityUnreadCount;
    unreadCountAsync.whenOrNull(
      data: (unreadCount) => totalUnreadCount += unreadCount,
    );

    // Ensure ActivityProvider is initialized for current user
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentUser = fa.FirebaseAuth.instance.currentUser;
      if (currentUser != null && !activityState.isLoading) {
        final notifier = ref.read(activityProvider.notifier);
        if (!notifier.isInitialized) {
          notifier.init(currentUser.uid);
          LoggingService.instance.debug(
              '🔔 ActivityProvider initialized for user: ${currentUser.uid}',
              tag: 'DiscoverView');
        }
      }
    });

    final _DiscoverPageStyle s = _DiscoverPageStyle.of(context);
    return GestureDetector(
      onTap: () {
        LoggingService.instance.debug(
          'GestureDetector onTap triggered',
          tag: 'DiscoverView',
        );
        _navigateToActivity(context);
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: s.searchFill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: s.searchBorder),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Icon(
              Icons.notifications_outlined,
              color: s.onAppBar,
              size: 24,
            ),
            // Notification badge
            if (totalUnreadCount > 0)
              Positioned(
                right: 7,
                top: 7,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    totalUnreadCount > 99 ? '99+' : totalUnreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    ref.listen<int>(followRefreshProvider, (previous, next) {
      if (previous == next) return;
      ref.read(discoverProvider.notifier).loadTrendingCreators();
    });

    final discoverState = ref.watch(discoverProvider);
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final _DiscoverPageStyle s = _DiscoverPageStyle.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? <Color>[
                    const Color(0xFF121A35),
                    StThemeColors.darkBackground,
                  ]
                : <Color>[
                    Colors.white,
                    StThemeColors.lightBackground,
                  ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -80,
              right: -60,
              child: IgnorePointer(
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: <Color>[
                        StThemeColors.brandPurple.withValues(alpha: 0.22),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: RefreshIndicator(
                color: s.refreshColor,
                backgroundColor: s.refreshBackground,
                onRefresh: _refreshDiscoverView,
                child: CustomScrollView(
                  controller: _discoverScrollController,
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    SliverAppBar(
                      expandedHeight: 108,
                      pinned: false,
                      floating: false,
                      snap: false,
                      backgroundColor: Colors.transparent,
                      surfaceTintColor: Colors.transparent,
                      elevation: 0,
                      automaticallyImplyLeading: false,
                      flexibleSpace: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          STDiscoverTokens.pagePadding,
                          8,
                          STDiscoverTokens.pagePadding,
                          12,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (widget.showAppBarBackButton) ...[
                              InstantIconButton(
                                icon: Icon(
                                  Icons.arrow_back,
                                  color: s.onAppBar,
                                ),
                                onPressed: () => Navigator.of(context).pop(),
                                hapticType: HapticFeedbackType.lightImpact,
                              ),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        'Discover',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: s.onAppBar,
                                          fontSize: 30,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.6,
                                          height: 1.05,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Find creators, clips, and growth tools',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: s.onAppBar.withValues(
                                            alpha: 0.72,
                                          ),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          height: 1.05,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            _buildNotificationButton(context, ref),
                            if (FeatureFlags.discoverFilters) ...[
                              const SizedBox(width: 10),
                              _buildDiscoverFilterButton(context),
                            ],
                          ],
                        ),
                      ),
                    ),

                    SliverToBoxAdapter(
                      child: _buildDiscoverSearchBar(context, s),
                    ),

                    SliverToBoxAdapter(
                      child: _buildDiscoverHeroCard(context, s),
                    ),

                    // Trending Creators
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          left: STDiscoverTokens.pagePadding,
                          right: STDiscoverTokens.pagePadding,
                          top: 0,
                          bottom: STDiscoverTokens.sectionGap,
                        ),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(0, 16, 0, 18),
                          decoration: BoxDecoration(
                            color: s.cardFill,
                            borderRadius: BorderRadius.circular(
                              STDiscoverTokens.cardRadius,
                            ),
                            border: Border.all(
                              color: s.cardBorder,
                            ),
                            boxShadow: _discoverShadow(context, s, heavy: true),
                          ),
                          child: TrendingCreatorsSection(
                            isDark: !s.isLight,
                            onCreatorTap: _onCreatorTapped,
                          ),
                        ),
                      ),
                    ),

                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: STDiscoverTokens.pagePadding,
                          right: STDiscoverTokens.pagePadding,
                          top: 0,
                          bottom: STDiscoverTokens.sectionGap,
                        ),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                          decoration: BoxDecoration(
                            color: s.cardFill,
                            borderRadius: BorderRadius.circular(
                                STDiscoverTokens.cardRadius),
                            border: Border.all(
                              color: s.cardBorder,
                            ),
                            boxShadow: _discoverShadow(context, s, heavy: true),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionHeading(
                                context,
                                'Categories',
                                'Swipe into creator lanes',
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                height: 196,
                                width: double.infinity,
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final pages =
                                        <List<discover_models.Category>>[];
                                    for (int i = 0;
                                        i < discoverState.categories.length;
                                        i += 6) {
                                      pages.add(
                                        discoverState.categories
                                            .skip(i)
                                            .take(6)
                                            .toList(growable: false),
                                      );
                                    }
                                    return PageView.builder(
                                      clipBehavior: Clip.none,
                                      physics: const PageScrollPhysics(
                                        parent: BouncingScrollPhysics(),
                                      ),
                                      itemCount: pages.length,
                                      onPageChanged: (index) {
                                        if (!mounted) return;
                                        setState(
                                            () => _categoryPageIndex = index);
                                      },
                                      itemBuilder: (context, pageIndex) {
                                        final page = pages[pageIndex];
                                        return Padding(
                                          padding: EdgeInsets.only(
                                            right: pageIndex == pages.length - 1
                                                ? 0
                                                : 10,
                                          ),
                                          child: GridView.builder(
                                            physics:
                                                const NeverScrollableScrollPhysics(),
                                            padding: const EdgeInsets.only(
                                                bottom: 4),
                                            gridDelegate:
                                                const SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount: 3,
                                              crossAxisSpacing: 10,
                                              mainAxisSpacing: 10,
                                              childAspectRatio: 1.22,
                                            ),
                                            itemCount: page.length,
                                            itemBuilder: (context, index) {
                                              final category = page[index];
                                              return _accessibilityService
                                                  .createAccessibleButton(
                                                semanticLabel:
                                                    'Category ${category.name}',
                                                semanticHint: _selectedCategory ==
                                                        category.id
                                                    ? 'Currently selected category. '
                                                        'Tap to deselect.'
                                                    : 'Tap to select this category',
                                                onPressed: () =>
                                                    _onCategorySelected(
                                                  category,
                                                ),
                                                hapticFeedbackType:
                                                    AccessibilityHapticFeedbackType
                                                        .light,
                                                child: CategoryCard(
                                                  key: ValueKey(category.id),
                                                  category: category,
                                                  isSelected:
                                                      _selectedCategory ==
                                                          category.id,
                                                  hasCategorySelected:
                                                      _selectedCategory != null,
                                                  onTap: () =>
                                                      _onCategorySelected(
                                                    category,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildCategoryPageDots(discoverState.categories),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Content based on category selection
                    if (_selectedCategory == null) ...[
                      // Default view - show resources
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            STDiscoverTokens.pagePadding,
                            0,
                            STDiscoverTokens.pagePadding,
                            STDiscoverTokens.sectionGap,
                          ),
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                            decoration: BoxDecoration(
                              color: s.cardFill,
                              borderRadius: BorderRadius.circular(
                                  STDiscoverTokens.cardRadius),
                              border: Border.all(
                                color: s.cardBorder,
                              ),
                              boxShadow:
                                  _discoverShadow(context, s, heavy: true),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionHeading(
                                  context,
                                  'Creator Resources',
                                  'Tools to help you grow faster',
                                ),
                                const SizedBox(height: 12),
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount:
                                      discoverState.recommendedContent.length,
                                  itemBuilder: (context, index) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: RecommendedContentCard(
                                        content: discoverState
                                            .recommendedContent[index],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      // Category selected - show 3-column video grid with tap to open swipeable feed
                      _buildCategoryVideoGridSliver(context, s, discoverState),
                    ],

                    if (discoverState.recommendedContent.isNotEmpty)
                      SliverToBoxAdapter(
                        child: _buildRecommendedForYouSection(
                          context,
                          s,
                          discoverState,
                        ),
                      ),

                    // Bottom padding for tab bar
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 92 + MediaQuery.paddingOf(context).bottom,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscoverSearchBar(BuildContext context, _DiscoverPageStyle s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        STDiscoverTokens.pagePadding,
        8,
        STDiscoverTokens.pagePadding,
        0,
      ),
      child: Semantics(
        button: true,
        label: 'Search creators, clips, games, and resources',
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            AppNavigator.openSearch(context);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            height: STDiscoverTokens.searchHeight,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: s.searchFill,
              borderRadius:
                  BorderRadius.circular(STDiscoverTokens.compactCardRadius),
              border: Border.all(color: s.searchBorder),
              boxShadow: _discoverShadow(context, s, heavy: false),
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.search_rounded,
                  color: StThemeColors.brandBlue,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Search creators, clips, games, resources...',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: s.searchPlaceholder,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  Icons.north_east_rounded,
                  color: s.searchChevron,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDiscoverHeroCard(BuildContext context, _DiscoverPageStyle s) {
    final AcademyDiscoverCardStatus status =
        ref.watch(academyDiscoverCardStatusProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        STDiscoverTokens.pagePadding,
        12,
        STDiscoverTokens.pagePadding,
        STDiscoverTokens.sectionGap,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => AppNavigator.openAcademy(context),
          borderRadius: BorderRadius.circular(26),
          child: Ink(
            height: STDiscoverTokens.heroHeight,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: s.heroGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: s.heroBorder),
              boxShadow: [
                BoxShadow(
                  color: StThemeColors.brandPurple.withValues(alpha: 0.24),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -24,
                  top: -30,
                  child: Icon(
                    Icons.school_rounded,
                    size: 150,
                    color: Colors.white.withValues(alpha: 0.13),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                        ),
                        child: const Text(
                          'Streamer Academy',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        'Master streaming, content, growth, and creator '
                        'business skills.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          height: 1.1,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              status.headline,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.88),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  status.actionLabel,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<BoxShadow> _discoverShadow(
    BuildContext context,
    _DiscoverPageStyle s, {
    required bool heavy,
  }) {
    final color = Theme.of(context).colorScheme.shadow;
    if (s.isLight) {
      return [
        BoxShadow(
          color: color.withValues(alpha: heavy ? 0.10 : 0.07),
          blurRadius: heavy ? 24 : 16,
          offset: Offset(0, heavy ? 14 : 8),
        ),
      ];
    }
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: heavy ? 0.28 : 0.18),
        blurRadius: heavy ? 24 : 16,
        offset: Offset(0, heavy ? 14 : 8),
      ),
    ];
  }

  Widget _buildDiscoverFilterButton(BuildContext context) {
    if (!FeatureFlags.discoverFilters) {
      return const SizedBox.shrink();
    }
    final _DiscoverPageStyle s = _DiscoverPageStyle.of(context);
    return Semantics(
      button: true,
      label: 'Open Discover filters',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
        },
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: s.searchFill,
            shape: BoxShape.circle,
            border: Border.all(color: s.searchBorder),
          ),
          child: Icon(
            Icons.tune_rounded,
            color: s.onAppBar,
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryPageDots(List<discover_models.Category> categories) {
    final pageCount = (categories.length / 6).ceil();
    if (pageCount <= 1) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(pageCount, (index) {
        final isActive = index == _categoryPageIndex.clamp(0, pageCount - 1);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: isActive ? 18 : 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: isActive
                ? StThemeColors.brandPurple
                : _DiscoverPageStyle.of(context).muted.withValues(alpha: 0.28),
          ),
        );
      }),
    );
  }

  Widget _buildRecommendedForYouSection(
    BuildContext context,
    _DiscoverPageStyle s,
    DiscoverState discoverState,
  ) {
    final items = discoverState.recommendedContent.take(2).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        STDiscoverTokens.pagePadding,
        0,
        STDiscoverTokens.pagePadding,
        STDiscoverTokens.sectionGap,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        decoration: BoxDecoration(
          color: s.cardFill,
          borderRadius: BorderRadius.circular(STDiscoverTokens.cardRadius),
          border: Border.all(color: s.cardBorder),
          boxShadow: _discoverShadow(context, s, heavy: true),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeading(
              context,
              'Recommended For You',
              'Based on your creator activity',
            ),
            const SizedBox(height: 12),
            ...items.map(
              (content) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: RecommendedContentCard(content: content),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeading(
      BuildContext context, String title, String subtitle,
      {String? actionLabel, VoidCallback? onAction}) {
    final _DiscoverPageStyle s = _DiscoverPageStyle.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: s.onCard,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            if (actionLabel != null && onAction != null)
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  foregroundColor: StThemeColors.brandPurple,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(
                  actionLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: s.muted,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            height: 1.3,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryVideoGridSliver(
    BuildContext context,
    _DiscoverPageStyle s,
    DiscoverState discoverState,
  ) {
    final String? selectedCategoryId = _selectedCategory;
    if (selectedCategoryId == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final discover_models.Category selectedCategory =
        discoverState.categories.firstWhere(
      (discover_models.Category cat) => cat.id == selectedCategoryId,
      orElse: () => discoverState.categories.first,
    );

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          STDiscoverTokens.pagePadding,
          0,
          STDiscoverTokens.pagePadding,
          STDiscoverTokens.sectionGap,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
          decoration: BoxDecoration(
            color: s.cardFill,
            borderRadius: BorderRadius.circular(STDiscoverTokens.cardRadius),
            border: Border.all(
              color: s.cardBorder,
            ),
            boxShadow: _discoverShadow(context, s, heavy: true),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _buildSectionHeading(
                context,
                '${selectedCategory.name} Clips',
                'Swipe into a focused feed from this category',
              ),
              const SizedBox(height: 12),
              _buildVideoGridWithTapToSwipe(
                selectedCategoryId,
                discoverState,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoGridWithTapToSwipe(
    String categoryId,
    DiscoverState discoverState,
  ) {
    final Future<List<Map<String, dynamic>>> future =
        _categoryFeedFutures[categoryId] ??=
            _getCategoryVideosForFeed(categoryId);
    return FutureBuilder<List<Map<String, dynamic>>>(
      key: ValueKey<String>('category-feed-$categoryId'),
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildVideoGridSkeleton(context);
        }

        if (snapshot.hasError) {
          return _buildErrorState(
            context,
            UserFacingError.message(snapshot.error),
          );
        }

        final List<Map<String, dynamic>> rawList = snapshot.data ?? [];
        final List<Map<String, dynamic>> categoryVideos = rawList
            .where(
              (Map<String, dynamic> v) =>
                  resolveReadyPlaybackUrl(_normalizedVideoData(v)) != null,
            )
            .toList(growable: false);
        if (kDebugMode) {
          debugPrint(
            'Discover category grid: id=$categoryId raw=${rawList.length} '
            'playable=${categoryVideos.length}',
          );
        }

        if (categoryVideos.isEmpty) {
          return _buildEmptyCategoryState();
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.64,
          ),
          itemCount: categoryVideos.length,
          itemBuilder: (context, index) {
            return _buildVideoGridItemWithTap(
              categoryVideos[index],
              categoryVideos,
              index,
            );
          },
        );
      },
    );
  }

  Widget _buildVideoGridItemWithTap(
    Map<String, dynamic> video,
    List<Map<String, dynamic>> allVideos,
    int currentIndex,
  ) {
    return Builder(
      builder: (BuildContext context) {
        final raw = _normalizedVideoData(video);
        final ColorScheme cs = Theme.of(context).colorScheme;
        final Color tileBg = cs.surfaceContainerHighest;
        final Color iconMuted = cs.onSurfaceVariant;
        final String creatorName = _discoverCardCreatorLabel(raw);
        final int engagementCount = math.max(
          0,
          DiscoverFieldMapper.safeCount(
            raw,
            const <String>['likes', 'likeCount', 'viewCount', 'views'],
          ),
        );
        return Semantics(
          button: true,
          label: 'Clip by $creatorName, $engagementCount engagements',
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              LoggingService.instance.debug(
                'Tapped video: ${raw['title'] ?? raw['caption'] ?? raw['docId']}',
                tag: 'DiscoverView',
              );
              _openSwipeableVideoFeed(allVideos, currentIndex);
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: tileBg,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.10),
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Builder(
                    builder: (BuildContext innerContext) {
                      final muxPlaybackId = _firstString(raw, const [
                        'muxPlaybackId',
                        'playbackId',
                        'mux_playback_id',
                      ]);
                      final thumbnailUrl = _firstString(raw, const [
                        'thumbnailUrl',
                        'thumbnailURL',
                        'thumbnail',
                        'muxThumbnailUrl',
                      ]);
                      final effectiveThumbnailUrl = thumbnailUrl.isNotEmpty
                          ? thumbnailUrl
                          : (muxPlaybackId.isEmpty
                              ? ''
                              : 'https://image.mux.com/$muxPlaybackId/thumbnail.jpg?width=720&time=0');

                      if (effectiveThumbnailUrl.isNotEmpty) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.network(
                            effectiveThumbnailUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) {
                                return child;
                              }
                              return Container(
                                color: tileBg,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      cs.primary,
                                    ),
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: tileBg,
                                child: Center(
                                  child: Icon(
                                    Icons.video_library_outlined,
                                    color: iconMuted,
                                    size: 32,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      }
                      return Container(
                        color: tileBg,
                        child: Center(
                          child: Icon(
                            Icons.video_library_outlined,
                            color: iconMuted,
                            size: 32,
                          ),
                        ),
                      );
                    },
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.10),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.62),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.38),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    right: 10,
                    bottom: 10,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            creatorName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.local_fire_department_rounded,
                          color: StThemeColors.warning,
                          size: 15,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          _formatCompactCount(engagementCount),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Duration badge (if available)
                  Builder(
                    builder: (context) {
                      dynamic duration = raw['duration'];
                      if (duration == null) {
                        final metadata =
                            raw['metadata'] as Map<String, dynamic>?;
                        duration = metadata?['duration'];
                      }

                      if (duration != null) {
                        return Positioned(
                          bottom: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _formatDuration(duration),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatDuration(dynamic duration) {
    if (duration == null) return '0:00';

    int seconds = 0;

    if (duration is double) {
      seconds = duration.round();
    } else if (duration is int) {
      seconds = duration;
    } else if (duration is String) {
      // Handle duration stored as string (e.g., "120" or "2:00")
      if (duration.contains(':')) {
        // Parse format like "2:00" or "1:30"
        final parts = duration.split(':');
        if (parts.length == 2) {
          final minutes = int.tryParse(parts[0]) ?? 0;
          final secs = int.tryParse(parts[1]) ?? 0;
          seconds = minutes * 60 + secs;
        }
      } else {
        // Parse as seconds string
        seconds = int.tryParse(duration) ?? 0;
      }
    } else if (duration is Duration) {
      seconds = duration.inSeconds;
    }

    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _openSwipeableVideoFeed(
    List<Map<String, dynamic>> videos,
    int startIndex,
  ) {
    final String categoryId = _selectedCategory ?? 'all';
    final List<HomeVideo> eligible =
        DiscoverEligibleVideosResolver.resolveEligible(ref);
    final List<HomeVideo> matching =
        DiscoverEligibleVideosResolver.filterByCategory(eligible, categoryId);
    String tappedId = '';
    if (startIndex >= 0 && startIndex < videos.length) {
      tappedId = DiscoverFieldMapper.safeString(
        videos[startIndex]['id'] ?? videos[startIndex]['docId'],
      );
    }
    int normalizedStartIndex = 0;
    if (tappedId.isNotEmpty) {
      final int idx = matching.indexWhere((HomeVideo v) => v.id == tappedId);
      if (idx >= 0) {
        normalizedStartIndex = idx;
      }
    } else if (matching.isNotEmpty) {
      normalizedStartIndex = startIndex.clamp(0, matching.length - 1);
    }
    if (matching.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This video is still processing.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final GlobalPlaybackManager manager = GlobalPlaybackManager.instance;
    manager.setVisibleOwner(PlaybackOwners.discoverPlayer);
    manager.bindDiscoverCategoryFeed(matching);
    final HomeVideo tappedVideo = matching[normalizedStartIndex];
    final String warmUrl = tappedVideo.videoURL.trim();
    if (warmUrl.isNotEmpty) {
      unawaited(
        manager.getOrCreateController(
          tappedVideo.id,
          warmUrl,
          owner: PlaybackOwners.discoverPlayer,
        ),
      );
    }
    if (kDebugMode) {
      debugPrint(
        '🎬 Discover category feed opening: categoryId=$categoryId '
        'tappedVideoId=${tappedVideo.id} normalizedCount=${matching.length} '
        'initialIndex=$normalizedStartIndex',
      );
    }
    unawaited(
      DiscoverView.openCategoryVideoSwipeFeed<void>(
        context,
        videos: matching,
        startIndex: normalizedStartIndex,
        categoryId: categoryId,
      ),
    );
  }

  /// Category grids: Home For You first (hydrated), then Firestore when thin —
  /// same idea as website Discover querying by categoryId/category.
  Future<List<Map<String, dynamic>>> _getCategoryVideosForFeed(
    String categoryId,
  ) async {
    try {
      LoggingService.instance.debug(
        'Loading category feed: $categoryId',
        tag: 'DiscoverView',
      );
      final List<HomeVideo> eligible =
          DiscoverEligibleVideosResolver.resolveEligible(ref);
      final List<HomeVideo> matching =
          DiscoverEligibleVideosResolver.filterByCategory(eligible, categoryId);
      DiscoverEligibleVideosResolver.logCategoryLoadAudit(
        ref: ref,
        selectedCategoryId: categoryId,
        eligible: eligible,
        matching: matching,
      );
      final List<Map<String, dynamic>> fromHome =
          await DiscoverCategoryCardMap.buildFromHomeVideos(matching);
      List<Map<String, dynamic>> videos = fromHome;
      if (!isAllCategorySlug(categoryId) &&
          fromHome.length < _videosPerPage) {
        final List<Map<String, dynamic>> fromFirestore =
            await _loadCategoryVideosFromFirestoreCanonical(categoryId);
        if (fromFirestore.isNotEmpty) {
          videos = _mergeCategoryFeedMaps(
            preferred: fromHome,
            extra: fromFirestore,
          );
        }
      }
      if (kDebugMode) {
        debugPrint(
          'Discover category feed built: id=$categoryId '
          'home=${fromHome.length} playableCount=${videos.length}',
        );
      }
      ref.read(discoverCategoryVideosProvider.notifier).cacheVideos(
            categoryId,
            videos,
          );
      return videos;
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Error loading category feed videos for $categoryId',
        tag: 'DiscoverView',
        error: e,
        stackTrace: stackTrace,
      );
      return <Map<String, dynamic>>[];
    }
  }

  List<Map<String, dynamic>> _mergeCategoryFeedMaps({
    required List<Map<String, dynamic>> preferred,
    required List<Map<String, dynamic>> extra,
  }) {
    final Map<String, Map<String, dynamic>> byId =
        <String, Map<String, dynamic>>{};
    void ingest(Map<String, dynamic> video) {
      final String id = DiscoverFieldMapper.safeString(
        video['id'] ?? video['docId'] ?? video['videoId'],
      );
      if (id.isEmpty) {
        return;
      }
      byId[id] = video;
    }

    for (final Map<String, dynamic> video in extra) {
      ingest(video);
    }
    for (final Map<String, dynamic> video in preferred) {
      ingest(video);
    }
    return byId.values.toList(growable: false);
  }

  /// Firestore category fetch mapped to grid cards (website parity).
  Future<List<Map<String, dynamic>>> _loadCategoryVideosFromFirestoreCanonical(
    String categoryId,
  ) async {
    final List<Map<String, dynamic>> candidates =
        await _fetchCategoryVideoCandidatesFromFirestore(categoryId);
    if (candidates.isEmpty) {
      return <Map<String, dynamic>>[];
    }
    final List<Map<String, dynamic>> videos = <Map<String, dynamic>>[];
    for (final Map<String, dynamic> candidate in candidates) {
      final String docId =
          DiscoverFieldMapper.safeString(candidate['docId']);
      final Object? rawData = candidate['data'];
      if (docId.isEmpty || rawData is! Map) {
        continue;
      }
      final Map<String, dynamic> data =
          Map<String, dynamic>.from(rawData);
      videos.add(
        _fullCategoryVideoMap(
          docId: docId,
          data: data,
          categoryId: categoryId,
          isNew: candidate['isNew'] == true,
          trendingScore:
              DiscoverFieldMapper.safeDouble(candidate['trendingScore']),
        ),
      );
    }
    return videos;
  }

  Widget _buildEmptyCategoryState() {
    return Builder(
      builder: (BuildContext context) {
        final _DiscoverPageStyle s = _DiscoverPageStyle.of(context);
        return SizedBox(
          height: 200,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  Icons.video_library_outlined,
                  size: 48,
                  color: s.muted,
                ),
                const SizedBox(height: 16),
                Text(
                  'No playable videos in this category yet.',
                  style: TextStyle(
                    color: s.muted,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Try another category or check back soon.',
                  style: TextStyle(
                    color: s.muted,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Direct Firestore reads by canonical / legacy category fields (no orderBy
  /// to reduce composite index requirements). Results are de-duplicated by doc id.
  Future<List<Map<String, dynamic>>> _fetchCategoryVideoCandidatesFromFirestore(
    String categoryId,
  ) async {
    if (isAllCategorySlug(categoryId)) {
      return <Map<String, dynamic>>[];
    }
    final Map<String, Map<String, dynamic>> merged =
        <String, Map<String, dynamic>>{};
    final DateTime sevenDaysAgo =
        DateTime.now().subtract(const Duration(days: 7));

    void ingest(
      QueryDocumentSnapshot<Map<String, dynamic>> doc, {
      required bool markNew,
    }) {
      final Map<String, dynamic> data = doc.data();
      if (!isDiscoverEligibleFromFirestore(data, videoId: doc.id)) {
        return;
      }
      if (!matchesDiscoverCategory(data, categoryId)) {
        return;
      }
      final DateTime? created = data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : null;
      final bool isNew =
          markNew || (created != null && created.isAfter(sevenDaysAgo));
      final double score =
          DiscoverFieldMapper.safeDouble(data['trendingScore']);
      merged[doc.id] = <String, dynamic>{
        'docId': doc.id,
        'data': data,
        'isNew': isNew,
        'trendingScore': score,
      };
    }

    Future<void> runQuery(Query<Map<String, dynamic>> query) async {
      try {
        final QuerySnapshot<Map<String, dynamic>> snap =
            await query.limit(30).get();
        for (final QueryDocumentSnapshot<Map<String, dynamic>> d in snap.docs) {
          ingest(d, markNew: false);
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
            'DiscoverView category Firestore query skipped: '
            'categoryId=$categoryId err=$e',
          );
        }
      }
    }

    final CollectionReference<Map<String, dynamic>> col =
        FirebaseFirestore.instance.collection('videos');
    final String canonicalId = normalizeCategorySlug(categoryId);
    final String displayName = categoryDisplayNameForId(canonicalId);
    final List<String> scalarValues = <String>{
      canonicalId,
      categoryId,
      displayName,
      displayName.toLowerCase(),
      ..._getCategoryQueryValues(categoryId),
    }.where((String value) => value.trim().isNotEmpty).take(10).toList();
    final List<String> feedStatuses =
        kVideoVisibleInFeedStatuses.toList(growable: false);
    final List<Future<void>> tasks = <Future<void>>[];
    for (final String value in scalarValues) {
      tasks.add(
        runQuery(
          col.where('categoryId', isEqualTo: value).where(
                'status',
                whereIn: feedStatuses,
              ),
        ),
      );
      tasks.add(
        runQuery(
          col.where('category_id', isEqualTo: value).where(
                'status',
                whereIn: feedStatuses,
              ),
        ),
      );
      tasks.add(
        runQuery(
          col.where('category', isEqualTo: value).where(
                'status',
                whereIn: feedStatuses,
              ),
        ),
      );
    }
    if (scalarValues.isNotEmpty) {
      tasks.add(
        runQuery(
          col.where('categories', arrayContainsAny: scalarValues).where(
                'status',
                whereIn: feedStatuses,
              ),
        ),
      );
    }
    await Future.wait(tasks);
    if (kDebugMode) {
      debugPrint(
        'DiscoverView category direct fetch: categoryId=$categoryId '
        'mergedCount=${merged.length}',
      );
    }
    return merged.values.toList();
  }

  /// Load mixed category videos (recent + trending)
  // ignore: unused_element
  Future<List<Map<String, dynamic>>> _loadMixedCategoryVideos(
    String categoryId,
    DocumentSnapshot? startAfter,
  ) async {
    try {
      LoggingService.instance.debug(
        'Loading mixed category videos for: $categoryId',
        tag: 'DiscoverView',
      );
      if (isAllCategorySlug(categoryId)) {
        return _loadAllVideosNoCategory(startAfter);
      }
      // Load recent videos (last 7 days)
      final recentVideos = await _loadRecentVideos(categoryId, startAfter);
      LoggingService.instance.debug(
        'Loaded ${recentVideos.length} recent videos for $categoryId',
        tag: 'DiscoverView',
      );

      // Load trending videos
      final trendingVideos = await _loadTrendingVideos(categoryId, startAfter);
      LoggingService.instance.debug(
        'Loaded ${trendingVideos.length} trending videos for $categoryId',
        tag: 'DiscoverView',
      );

      final hasEnoughCategoryMatches =
          recentVideos.length + trendingVideos.length >= (_videosPerPage ~/ 2);
      List<Map<String, dynamic>> fallbackVideos = const [];

      if (!hasEnoughCategoryMatches) {
        LoggingService.instance.debug(
          'Category-specific queries were thin for $categoryId, loading broader fallback matches',
          tag: 'DiscoverView',
        );
        fallbackVideos = await _loadAllCategoryVideos(
          categoryId,
          startAfter,
        );
        LoggingService.instance.debug(
          'Fallback query returned ${fallbackVideos.length} videos for $categoryId',
          tag: 'DiscoverView',
        );
      }

      // If we have categorized videos, combine them with fallback videos
      if (recentVideos.isNotEmpty || trendingVideos.isNotEmpty) {
        // Add fallback videos that aren't already in the categorized list
        final existingIds = <String>{};
        for (final video in recentVideos) {
          existingIds.add(video['docId'] as String);
        }
        for (final video in trendingVideos) {
          existingIds.add(video['docId'] as String);
        }

        for (final fallbackVideo in fallbackVideos) {
          final docId = fallbackVideo['docId'] as String;
          if (!existingIds.contains(docId)) {
            recentVideos.add({
              ...fallbackVideo,
              'isNew': false, // Fallback videos are not marked as new
            });
          }
        }

        LoggingService.instance.debug(
          'After combining: ${recentVideos.length} category-aligned videos for $categoryId',
          tag: 'DiscoverView',
        );
      } else if (fallbackVideos.isNotEmpty) {
        return fallbackVideos;
      } else {
        return _loadCategoryVideosInMemoryFallback(categoryId, startAfter);
      }

      // Combine and deduplicate
      final allVideos = <String, Map<String, dynamic>>{};

      // Add recent videos first
      for (final video in recentVideos) {
        final docId = video['docId'] as String;
        allVideos[docId] = {...video, 'isNew': true, 'trendingScore': 0.0};
      }

      // Add trending videos (don't override recent ones)
      for (final video in trendingVideos) {
        final docId = video['docId'] as String;
        if (!allVideos.containsKey(docId)) {
          allVideos[docId] = {
            ...video,
            'isNew': false,
            'trendingScore': video['trendingScore'] ?? 0.0,
          };
        }
      }

      final mixedVideos = allVideos.values.toList();
      LoggingService.instance.debug(
        'Combined ${mixedVideos.length} total videos for $categoryId',
        tag: 'DiscoverView',
      );

      // Apply pagination
      final paginatedVideos = _applyPagination(mixedVideos, startAfter);

      LoggingService.instance.debug(
        'Mixed feed: ${recentVideos.length} recent + ${trendingVideos.length} trending = ${paginatedVideos.length} total',
        tag: 'DiscoverView',
      );

      return paginatedVideos;
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Error loading mixed category videos for $categoryId',
        tag: 'DiscoverView',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Fallback method to load all videos for a category (no restrictions)
  Future<List<Map<String, dynamic>>> _loadAllCategoryVideos(
    String categoryId,
    DocumentSnapshot? startAfter,
  ) async {
    try {
      LoggingService.instance.debug(
        'Loading ALL videos for category: $categoryId (fallback)',
        tag: 'DiscoverView',
      );

      LoggingService.instance.debug(
        'Searching for category: "$categoryId"',
        tag: 'DiscoverView',
      );

      final categoryValues = _getCategoryQueryValues(categoryId);
      final docs = await _fetchCategoryDocs(
        categoryValues: categoryValues,
        limit: _videosPerPage,
        startAfter: startAfter,
        orderByField: 'createdAt',
        allowOrderlessFallback: true,
      );
      final videos = _mapVideoDocsToFeedItems(docs, categoryId)
          .map((video) => {
                ...video,
                'isNew': false,
                'trendingScore': 0.0,
              })
          .toList();

      LoggingService.instance.debug(
        'Processed ${videos.length} fallback videos for $categoryId',
        tag: 'DiscoverView',
      );

      return videos;
    } catch (e) {
      LoggingService.instance.error(
        'Error loading all category videos for $categoryId',
        tag: 'DiscoverView',
        error: e,
      );
      return [];
    }
  }

  /// Fallback when composite indexes missing: load all videos, filter by category in memory.
  Future<List<Map<String, dynamic>>> _loadCategoryVideosInMemoryFallback(
    String categoryId,
    DocumentSnapshot? startAfter,
  ) async {
    try {
      final allVideos = await _loadAllVideosNoCategory(startAfter);
      final filtered = allVideos.where((v) {
        final data = v['data'] as Map<String, dynamic>?;
        if (data == null) return false;
        return _videoMatchesCategory(data, categoryId);
      }).toList();
      LoggingService.instance.debug(
        'In-memory fallback: ${filtered.length} videos for $categoryId (from ${allVideos.length} total)',
        tag: 'DiscoverView',
      );
      return filtered;
    } catch (e) {
      LoggingService.instance.error(
        'In-memory category fallback failed for $categoryId',
        tag: 'DiscoverView',
        error: e,
      );
      return [];
    }
  }

  /// Load all eligible videos from Home For You (All category — no Firestore query).
  Future<List<Map<String, dynamic>>> _loadAllVideosNoCategory(
    DocumentSnapshot? startAfter,
  ) async {
    try {
      final List<HomeVideo> eligible =
          DiscoverEligibleVideosResolver.resolveEligible(ref);
      final List<Map<String, dynamic>> videos =
          await DiscoverCategoryCardMap.buildFromHomeVideos(eligible);
      final int homeFeedCount = ref.read(hp.homeProvider).forYouVideos.length;
      logDiscoverSourceAudit(
        buildDiscoverSourceAuditReport(
          selectedCategory: 'All',
          homeFeedCount: homeFeedCount,
          rawDocs: eligible.map(homeVideoToFirestoreShape).toList(),
          eligibleDocs: eligible.map(homeVideoToFirestoreShape).toList(),
          matchingDocs: eligible.map(homeVideoToFirestoreShape).toList(),
        ),
      );

      logDiscoverCategoryDiagnostic(
        selectedCategory: 'All',
        total: homeFeedCount,
        eligible: eligible.length,
        matching: videos.length,
      );

      return _applyPagination(videos, startAfter);
    } catch (e) {
      LoggingService.instance.error(
        'Error loading all videos (no category)',
        tag: 'DiscoverView',
        error: e,
      );
      return <Map<String, dynamic>>[];
    }
  }

  /// Load recent videos (last 7 days)
  Future<List<Map<String, dynamic>>> _loadRecentVideos(
    String categoryId,
    DocumentSnapshot? startAfter,
  ) async {
    try {
      LoggingService.instance.debug(
        'Loading recent videos for category: $categoryId',
        tag: 'DiscoverView',
      );

      final now = DateTime.now();
      final sevenDaysAgo = now.subtract(const Duration(days: 7));
      final categoryValues = _getCategoryQueryValues(categoryId);
      final docs = await _fetchCategoryDocs(
        categoryValues: categoryValues,
        limit: _videosPerPage,
        startAfter: startAfter,
        rangeField: 'createdAt',
        isGreaterThan: sevenDaysAgo,
        orderByField: 'createdAt',
      );
      final videos = _mapVideoDocsToFeedItems(docs, categoryId);

      LoggingService.instance.debug(
        'Processed ${videos.length} recent videos for $categoryId (after filtering deleted)',
        tag: 'DiscoverView',
      );

      return videos;
    } catch (e) {
      LoggingService.instance.error(
        'Error loading recent videos for $categoryId',
        tag: 'DiscoverView',
        error: e,
      );
      return [];
    }
  }

  /// Load trending videos
  Future<List<Map<String, dynamic>>> _loadTrendingVideos(
    String categoryId,
    DocumentSnapshot? startAfter,
  ) async {
    try {
      LoggingService.instance.debug(
        'Loading trending videos for category: $categoryId',
        tag: 'DiscoverView',
      );
      final categoryValues = _getCategoryQueryValues(categoryId);
      final docs = await _fetchCategoryDocs(
        categoryValues: categoryValues,
        limit: _videosPerPage,
        startAfter: startAfter,
        rangeField: 'trendingScore',
        isGreaterThan: 50.0,
        orderByField: 'trendingScore',
      );
      final videos = _mapVideoDocsToFeedItems(docs, categoryId);

      LoggingService.instance.debug(
        'Processed ${videos.length} trending videos for $categoryId',
        tag: 'DiscoverView',
      );

      return videos;
    } catch (e) {
      LoggingService.instance.error(
        'Error loading trending videos for $categoryId',
        tag: 'DiscoverView',
        error: e,
      );
      return [];
    }
  }

  /// ✅ FIX #3: Fetch users by IDs with chunking (Firestore whereIn limit is 10)
  // ignore: unused_element
  Future<Map<String, Map<String, dynamic>>> _fetchUsersByIds(
    Set<String> userIds,
  ) async {
    if (userIds.isEmpty) return {};

    final result = <String, Map<String, dynamic>>{};
    final idsList = userIds.toList();

    const batchSize = 10; // Firestore whereIn limit
    for (var i = 0; i < idsList.length; i += batchSize) {
      final batch = idsList.sublist(
        i,
        (i + batchSize).clamp(0, idsList.length),
      );

      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('publicUsers')
            .where(FieldPath.documentId, whereIn: batch)
            .get();

        for (final doc in snapshot.docs) {
          result[doc.id] = doc.data();
        }
      } catch (e) {
        LoggingService.instance.error(
          'Error fetching user batch: $e',
          tag: 'DiscoverView',
          error: e,
        );
      }
    }

    return result;
  }

  /// ✅ FIX #4: Simplified pagination - Firestore handles pagination via startAfterDocument
  /// This method is kept for compatibility but doesn't actually paginate
  List<Map<String, dynamic>> _applyPagination(
    List<Map<String, dynamic>> videos,
    DocumentSnapshot? startAfter,
  ) {
    // Firestore pagination is handled via startAfterDocument in queries
    // This method just returns videos as-is (no client-side pagination needed)
    return videos;
  }
}

/// Full-screen vertical swipe feed for Discover category clips.
class DiscoverCategoryVideoFeedPage extends ConsumerStatefulWidget {
  const DiscoverCategoryVideoFeedPage({
    super.key,
    required this.videos,
    required this.startIndex,
    required this.categoryId,
  });

  final List<HomeVideo> videos;
  final int startIndex;
  final String categoryId;

  @override
  ConsumerState<DiscoverCategoryVideoFeedPage> createState() =>
      _DiscoverCategoryVideoFeedPageState();
}

class _DiscoverCategoryVideoFeedPageState
    extends ConsumerState<DiscoverCategoryVideoFeedPage> {
  late PageController _pageController;
  int _currentIndex = 0;
  List<HomeVideo> _videos = [];
  final Map<String, StreamSubscription<DocumentSnapshot>> _videoListeners = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.startIndex;
    _pageController = PageController(initialPage: widget.startIndex);
    _videos = List.from(widget.videos);
    _setupRealtimeDeletionListeners();

    final GlobalPlaybackManager manager = GlobalPlaybackManager.instance;
    manager.setVisibleOwner(PlaybackOwners.discoverPlayer);
    manager.bindDiscoverCategoryFeed(_videos);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final int idx = widget.startIndex.clamp(0, _videos.length - 1);
      if (_pageController.hasClients) {
        _pageController.jumpToPage(idx);
      }
      setState(() {
        _currentIndex = idx;
      });
      GlobalPlaybackManager.instance.preloadDiscoverCategoryAround(
        idx,
        _videos,
      );
    });

    manager.unblock();
    if (kDebugMode) {
      debugPrint(
          '🔊 CategoryVideoFeed: Unblocked playback to allow video loading');
    }
  }

  @override
  void dispose() {
    // Cancel all video listeners
    for (final subscription in _videoListeners.values) {
      subscription.cancel();
    }
    _videoListeners.clear();
    _pageController.dispose();

    final GlobalPlaybackManager manager = GlobalPlaybackManager.instance;
    manager.disposeControllersForOwner(PlaybackOwners.discoverPlayer);
    manager.setVisibleOwner(PlaybackOwners.discover);
    GlobalPlaybackManager.instance.pauseAll();

    super.dispose();
  }

  /// Listen only around the current page (±2) for deletion/visibility.
  void _setupRealtimeDeletionListeners() {
    _resyncDeletionListenersAround(_currentIndex);
  }

  void _resyncDeletionListenersAround(int centerIndex) {
    if (_videos.isEmpty) {
      return;
    }
    final int start = (centerIndex - 2).clamp(0, _videos.length - 1);
    final int end = (centerIndex + 2).clamp(0, _videos.length - 1);
    final Set<String> keepIds = <String>{};
    for (int i = start; i <= end; i++) {
      keepIds.add(_videos[i].id);
    }
    final List<String> toCancel = _videoListeners.keys
        .where((String id) => !keepIds.contains(id))
        .toList(growable: false);
    for (final String id in toCancel) {
      _videoListeners[id]?.cancel();
      _videoListeners.remove(id);
    }
    for (final String id in keepIds) {
      if (_videoListeners.containsKey(id)) {
        continue;
      }
      final subscription = FirebaseFirestore.instance
          .collection('videos')
          .doc(id)
          .snapshots()
          .listen((snapshot) {
        if (!mounted) return;
        if (!snapshot.exists) {
          _removeVideoFromFeed(id);
          return;
        }
        final data = snapshot.data();
        if (data == null || !isVideoVisibleInFeed(data)) {
          _removeVideoFromFeed(id);
        }
      });
      _videoListeners[id] = subscription;
    }
  }

  /// Remove a video from the feed when it's deleted
  void _removeVideoFromFeed(String videoId) {
    if (!mounted) return;

    setState(() {
      // Remove the video from the list
      _videos.removeWhere((video) => video.id == videoId);

      // Cancel the listener for this video
      _videoListeners[videoId]?.cancel();
      _videoListeners.remove(videoId);

      // Adjust current index if needed
      if (_currentIndex >= _videos.length && _videos.isNotEmpty) {
        _currentIndex = _videos.length - 1;
      } else if (_videos.isEmpty) {
        // If no videos left, navigate back
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
        return;
      }

      // Update page controller if needed
      if (_currentIndex < _videos.length) {
        _pageController.jumpToPage(_currentIndex);
      }
    });

    _resyncDeletionListenersAround(_currentIndex);

    LoggingService.instance.debug(
      'Removed deleted video $videoId from category feed ${widget.categoryId}',
      tag: 'DiscoverView',
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) {
          // Clean up when navigating back
          LoggingService.instance.debug(
            'Category video feed closed, current index: $_currentIndex',
            tag: 'DiscoverView',
          );
          // 🔊 AUDIO FIX: Block playback when returning to DiscoverView
          // This prevents audio bleeding from category feed videos
          GlobalPlaybackManager.instance
              .block(reason: 'returnedToDiscoverView');
          GlobalPlaybackManager.instance.pauseAll();
        }
      },
      child: Material(
        color: Colors.black,
        child: Stack(
          children: [
            // Video content fills entire screen (exact HomeView pattern)
            Positioned.fill(
              child: PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                physics: const ClampingScrollPhysics(), // Same as HomeView
                onPageChanged: (index) {
                  // ✅ FIX #1: Use _videos instead of widget.videos (mutable list)
                  if (index >= 0 && index < _videos.length) {
                    LoggingService.instance.debug(
                      'Category video page changed to index: $index, video ID: ${_videos[index].id}',
                      tag: 'DiscoverView',
                    );
                    setState(() {
                      _currentIndex = index;
                    });
                    _resyncDeletionListenersAround(index);
                    GlobalPlaybackManager.instance
                        .preloadDiscoverCategoryAround(index, _videos);
                  }
                },
                itemCount: _videos.length,
                itemBuilder: (context, index) {
                  final video = _videos[index];
                  final isCurrentVideo =
                      index == _currentIndex; // HomeView pattern

                  LoggingService.instance.debug(
                    'Creating VideoPlayerViewOptimized for index: $index, isCurrent: $isCurrentVideo, video ID: ${video.id}',
                    tag: 'DiscoverView',
                  );

                  return VideoPlayerViewOptimized(
                    key: ValueKey(video.id), // Stable key like HomeView
                    video: video,
                    isCurrentVideo: isCurrentVideo, // HomeView pattern
                    isFirstVideo: index == 0,
                    deferOffscreenControllerInit: true,
                    tabId: 'discoverView_${widget.categoryId}',
                    ownerKey: PlaybackOwners.discoverPlayer,
                    homeViewModel: ref.read(hp.homeProvider.notifier),
                    showSheet: false,
                    sheetType: '',
                    showHUD: true, // Show HUD like HomeView
                    onShowProfile: () {
                      AppNavigator.openStreamerCard(
                        context,
                        userId: video.creator.id,
                        initialCreator: video.creatorSnapshot,
                        currentUserId:
                            fa.FirebaseAuth.instance.currentUser?.uid,
                        onDismiss: () => Navigator.of(context).pop(),
                      );
                    },
                    onShowComments: () {
                      showModalBottomSheet<void>(
                        context: context,
                        routeSettings: const RouteSettings(name: '/comments'),
                        backgroundColor: Colors.transparent,
                        isScrollControlled: true,
                        isDismissible: true,
                        enableDrag: true,
                        builder: (context) => CommentsView2(
                          videoId: video.id,
                          videoOwnerId: video.creator.id,
                        ),
                      );
                    },
                    onShowShare: () {
                      // ✅ FIX: Use actual EnhancedShareSheet instead of placeholder
                      HapticFeedback.lightImpact();
                      showModalBottomSheet<void>(
                        context: context,
                        routeSettings:
                            const RouteSettings(name: '/share_sheet'),
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        isDismissible: true,
                        enableDrag: true,
                        builder: (context) => EnhancedShareSheet(
                          video: video,
                          onClose: () => Navigator.pop(context),
                          onReport: (videoId, creatorId) async {
                            // Report callback for additional handling if needed
                            LoggingService.instance.debug(
                              'Report submitted for video $videoId',
                              tag: 'DiscoverView',
                            );
                          },
                        ),
                      );
                    },
                    onShowStreamerCard: () {
                      AppNavigator.openStreamerCard(
                        context,
                        userId: video.creator.id,
                        initialCreator: video.creatorSnapshot,
                        currentUserId:
                            fa.FirebaseAuth.instance.currentUser?.uid,
                        onDismiss: () => Navigator.of(context).pop(),
                      );
                    },
                    isLiked: video.isLiked,
                    isBookmarked: video.isFavorited,
                  );
                },
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16,
              child: SafeArea(
                bottom: false,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.42),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
