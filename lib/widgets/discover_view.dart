import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/discover_provider.dart';
import '../providers/activity_provider.dart';
import '../providers/unread_messages_provider.dart';
import '../models/trending_creator.dart';
import '../models/category.dart' as discover_models;
import 'category_card.dart';
import 'recommended_content_card.dart';
import '../services/logging_service.dart';
import '../services/caching_service.dart';
import '../services/offline_storage_service.dart';
import '../services/accessibility_service.dart';
import '../services/global_playback_manager.dart';
import '../utils/avatar_url_resolver.dart';
import '../constants/playback_owners.dart';
import '../constants/app_colors.dart';
import 'instant_response_button.dart';
import 'lazy_loading_list.dart';
import 'video_player_view_optimized.dart';
import '../models/home_video.dart';
import '../models/user.dart';
import '../providers/home_provider.dart' as hp;
import '../providers/follow_refresh_provider.dart';
import 'comments_view2.dart';
import 'enhanced_share_sheet.dart';
import '../routing/app_navigator.dart';
// import 'video_thumbnail_view.dart'; // Removed - unused

/// 🔥 FIX: Field mapping utility for data model consistency
class FieldMapper {
  static String getUserId(Map<String, dynamic> data) {
    return data['userId'] ?? data['creatorId'] ?? data['creator_id'] ?? '';
  }

  static String getDisplayName(Map<String, dynamic> data) {
    return data['displayName'] ?? data['username'] ?? 'Unknown';
  }

  static String getAvatarUrl(Map<String, dynamic> data) {
    return resolveAvatarUrl(data) ?? '';
  }

  static String getThumbnailUrl(Map<String, dynamic> data) {
    return data['thumbnailUrl'] ?? data['thumbnailURL'] ?? '';
  }

  static String getVideoUrl(Map<String, dynamic> data) {
    return data['videoUrl'] ?? data['videoURL'] ?? '';
  }

  static int safeInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double safeDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static String safeString(dynamic value) {
    return value?.toString() ?? '';
  }
}

class DiscoverView extends ConsumerStatefulWidget {
  const DiscoverView({super.key});

  @override
  ConsumerState<DiscoverView> createState() => _DiscoverViewState();
}

class _DiscoverViewState extends ConsumerState<DiscoverView> {
  static const int _videosPerPage = 20;
  static const List<String> _allowedVideoStatuses = [
    'published',
    'ready',
    'active',
  ];
  String? _selectedCategory;
  int _currentCategoryPage = 0;
  final Map<String, Future<List<Map<String, dynamic>>>> _categoryFeedFutures =
      {};

  static const Map<String, List<String>> _categoryAliases = {
    'all': ['all'],
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

  String _normalizeCategoryKey(String value) {
    final trimmed = value.trim().toLowerCase();
    final normalizedWhitespace = trimmed.replaceAll(RegExp(r'[\s_]+'), '-');
    return normalizedWhitespace.replaceAll(RegExp(r'[^a-z0-9-]'), '');
  }

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
      if (_normalizeCategoryKey(category.id) == _normalizeCategoryKey(categoryId)) {
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

  bool _matchesCategory(String? stored, String categoryId) {
    if (stored == null || stored.isEmpty) return false;
    final storedNormalized = _normalizeCategoryKey(stored);
    final values = _getCategoryQueryValues(categoryId);
    return values.any((v) => storedNormalized == _normalizeCategoryKey(v));
  }

  bool _matchesCategoryValue(dynamic stored, String categoryId) {
    if (stored == null) return false;
    if (stored is Iterable) {
      for (final value in stored) {
        if (_matchesCategory(value?.toString(), categoryId)) {
          return true;
        }
      }
      return false;
    }
    return _matchesCategory(stored.toString(), categoryId);
  }

  bool _videoMatchesCategory(Map<String, dynamic> data, String categoryId) {
    return _matchesCategoryValue(data['categories'], categoryId) ||
        _matchesCategoryValue(
          data['category'] ?? data['categoryId'] ?? data['category_id'],
          categoryId,
        );
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
          .where(field, whereIn: categoryValues)
          .where('status', whereIn: _allowedVideoStatuses);

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

      if (!allowOrderlessFallback || orderByField == null || rangeField != null) {
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
          .where('categories', arrayContainsAny: categoryValues)
          .where('status', whereIn: _allowedVideoStatuses);

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
      final data = doc.data();
      final status = data['status'] as String? ?? '';
      if (!_allowedVideoStatuses.contains(status)) {
        continue;
      }

      if (!_videoMatchesCategory(data, categoryId)) {
        continue;
      }

      videos.add({
        'docId': doc.id,
        'data': data,
      });
    }

    return videos;
  }

  // ✅ FIX #5: Removed unused _cachedVideos - cache implementation reserved for future
  // Cache timestamps and TTL are reserved for future implementation

  // Services
  final CachingService _cachingService = CachingService();
  final OfflineStorageService _offlineStorage = OfflineStorageService();
  final AccessibilityService _accessibilityService = AccessibilityService();

  // 🔥 FIX: Real-time subscriptions
  StreamSubscription<QuerySnapshot>? _trendingCreatorsSubscription;
  StreamSubscription<QuerySnapshot>? _notificationsSubscription;
  Timer? _trendingRefreshTimer; // ✅ FIX #2: Store timer to cancel in dispose

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
    // 🔥 FIX: Cancel real-time subscriptions
    _trendingCreatorsSubscription?.cancel();
    _notificationsSubscription?.cancel();

    // ✅ FIX #2: Cancel timer to prevent leaks
    _trendingRefreshTimer?.cancel();

    // Cache cleared (removed unused _cachedVideos)

    // 🔊 AUDIO FIX: Don't pause here - NavigationObserver will call setActiveOwner
    // when navigating away, which handles pausing/muting non-active owners
    // Pausing here would be redundant and could interfere with reactivation

    super.dispose();
  }

  void _loadInitialData() {
    try {
      LoggingService.instance.debug(
        'Loading initial data',
        tag: 'DiscoverView',
      );
      ref.read(discoverProvider.notifier).loadTrendingCreators();
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
  }

  /// 🔥 FIX: Set up real-time updates for trending creators and notifications
  void _setupRealtimeUpdates() {
    try {
      LoggingService.instance.debug(
        'Setting up real-time updates',
        tag: 'DiscoverView',
      );

      // 🔥 ENHANCED: Real-time trending creators updates based on video performance
      // Note: We'll refresh trending creators periodically instead of using a simple user stream
      // This ensures we always show creators whose videos are actually trending
      _setupTrendingCreatorsRefresh();

      // Real-time notifications updates
      final currentUser = fa.FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        _notificationsSubscription = FirebaseFirestore.instance
            .collection('notifications')
            .doc(currentUser.uid)
            .collection('items')
            .where('status', isEqualTo: 'pending')
            .snapshots()
            .listen(
          (snapshot) {
            if (mounted) {
              LoggingService.instance.debug(
                'Real-time notifications update: ${snapshot.docs.length} pending',
                tag: 'DiscoverView',
              );

              // Update notification count in real-time
              // Note: unreadMessagesProvider is a StreamProvider, so we don't need to update it manually
              // The provider will automatically update when the stream changes
            }
          },
          onError: (error) {
            LoggingService.instance.error(
              'Error in notifications stream',
              tag: 'DiscoverView',
              error: error,
            );
          },
        );
      }

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
      // Safe error handling - don't call ErrorHandlerService during startup
      if (kDebugMode) {
        debugPrint('❌ DiscoverView real-time setup error: $e');
      }
    }
  }

  /// 🔥 ENHANCED: Set up periodic refresh of trending creators based on video performance
  /// ✅ FIX #2: Store timer and cancel previous to prevent duplicates
  void _setupTrendingCreatorsRefresh() {
    // Cancel previous timer if exists to avoid duplicates
    _trendingRefreshTimer?.cancel();

    // Refresh trending creators every 5 minutes to catch new trending videos
    _trendingRefreshTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      LoggingService.instance.debug(
        '🔄 Refreshing trending creators based on video performance...',
        tag: 'DiscoverView',
      );

      // Use the enhanced algorithm to get trending creators
      ref.read(discoverProvider.notifier).loadTrendingCreators();
    });

    // Refresh when new videos uploaded (scoped: limit 50, last hour)
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
        if (mounted && snapshot.docs.isNotEmpty) {
          LoggingService.instance.debug(
            '🔥 New videos detected, refreshing trending creators...',
            tag: 'DiscoverView',
          );

          // Refresh trending creators when new videos are uploaded
          ref.read(discoverProvider.notifier).loadTrendingCreators();
        }
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

  // Lazy loading methods
  Future<List<TrendingCreator>> _loadTrendingCreators(
    int page,
    int limit,
  ) async {
    try {
      // Check cache first
      final cacheKey = 'trending_creators_${page}_$limit';
      final cachedData = _cachingService.getMemoryCache<List<TrendingCreator>>(
        cacheKey,
      );
      if (cachedData != null) {
        return cachedData;
      }

      // Load from offline storage if available
      final offlineCreators = await _offlineStorage.getTrendingCreators();
      if (offlineCreators.isNotEmpty) {
        final startIndex = page * limit;
        final endIndex = (startIndex + limit).clamp(0, offlineCreators.length);
        final pageData = offlineCreators.sublist(startIndex, endIndex);

        // Cache the result
        _cachingService.setMemoryCache(cacheKey, pageData);
        return pageData;
      }

      // Fallback to provider
      final discoverState = ref.read(discoverProvider);
      final startIndex = page * limit;
      final endIndex = (startIndex + limit).clamp(
        0,
        discoverState.trendingCreators.length,
      );
      final pageData = discoverState.trendingCreators.sublist(
        startIndex,
        endIndex,
      );

      // Cache the result
      _cachingService.setMemoryCache(cacheKey, pageData);
      return pageData;
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to load trending creators',
        tag: 'DiscoverView',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  Widget _buildTrendingCreatorCard(
    BuildContext context,
    TrendingCreator creator,
    int index,
  ) {
    return KeyedSubtree(
      key: ValueKey('trending_creator_${creator.id}_$index'),
      child: _accessibilityService.createAccessibleListItem(
        semanticLabel:
            'Trending creator ${creator.displayName ?? creator.username}',
        semanticHint: 'Tap to view profile',
        onTap: () => _onCreatorTapped(creator),
        hapticFeedbackType: AccessibilityHapticFeedbackType.light,
        child: _buildTrendingCreatorItem(creator),
      ),
    );
  }

  bool _isSampleCreatorId(String id) {
    return ['1', '2', '3', '4', '5', '6'].contains(id);
  }

  void _onCreatorTapped(TrendingCreator creator) {
    HapticFeedback.lightImpact();
    LoggingService.instance.debug(
      'Creator tapped: ${creator.username} (ID: ${creator.id})',
      tag: 'DiscoverView',
    );

    // Prevent navigation for sample data with fake IDs
    if (_isSampleCreatorId(creator.id)) {
      LoggingService.instance.warning(
        'Cannot navigate to sample creator with fake ID: ${creator.id}',
        tag: 'DiscoverView',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'This is sample data. Real profiles will be available when creators are trending.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Validate that the creator ID is a valid Firebase user ID format
    if (creator.id.isEmpty || creator.id.length < 20) {
      LoggingService.instance.warning(
        'Invalid creator ID format: ${creator.id}',
        tag: 'DiscoverView',
      );
      return;
    }

    AppNavigator.openStreamerCard(
      context,
      userId: creator.id,
      currentUserId: fa.FirebaseAuth.instance.currentUser?.uid,
      onDismiss: () => Navigator.of(context).pop(),
      onMessage: (userId) {
        HapticFeedback.lightImpact();
        LoggingService.instance.debug(
          'Message action for user: $userId',
          tag: 'DiscoverView',
        );
      },
      onNavigateToTab: (tabName) {
        HapticFeedback.lightImpact();
      },
      onShare: (userId) {
        HapticFeedback.lightImpact();
      },
    );
  }

  Widget _buildTrendingCreatorItem(TrendingCreator creator) {
    return Container(
      width: 80,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildLiveAvatar(creator.id, creator.avatarURL, creator.username),
          const SizedBox(height: 8),
          Flexible(
            child: Text(
              creator.displayName ?? creator.username,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _buildLiveFollowerCount(creator.id, creator.followerCount),
        ],
      ),
    );
  }

  Widget _buildLiveAvatar(
      String userId, String? initialAvatarURL, String username) {
    final avatarURL = initialAvatarURL;
    if (avatarURL == null || avatarURL.isEmpty) {
      return CircleAvatar(
        radius: 30,
        backgroundColor: Colors.grey.withValues(alpha: 0.3),
        child: Text(
          username[0].toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: avatarURL,
        width: 60,
        height: 60,
        fit: BoxFit.cover,
        placeholder: (context, url) => CircleAvatar(
          radius: 30,
          backgroundColor: Colors.grey.withValues(alpha: 0.3),
          child: Text(
            username[0].toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        errorWidget: (context, url, error) {
          debugPrint('❌ Avatar load error for $username: $error');
          return CircleAvatar(
            radius: 30,
            backgroundColor: Colors.grey.withValues(alpha: 0.3),
            child: Text(
              username[0].toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        },
        memCacheWidth: 120,
        memCacheHeight: 120,
        maxWidthDiskCache: 200,
        maxHeightDiskCache: 200,
      ),
    );
  }

  Widget _buildLiveFollowerCount(String userId, int initialCount) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final liveCount = FieldMapper.safeInt(
          data?['followerCount'] ?? data?['followersCount'] ?? initialCount,
        );
        return Text(
          _formatFollowerCount(liveCount),
          style: const TextStyle(color: Colors.white70, fontSize: 10),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }

  String _formatFollowerCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M followers';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(0)}K followers';
    } else {
      return '$count followers';
    }
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

  void _onCategorySelected(String? categoryId) {
    try {
      // Add haptic feedback
      HapticFeedback.lightImpact();

      setState(() {
        _selectedCategory = categoryId;
        _currentCategoryPage = 0; // Reset pagination
      });
      if (categoryId != null) {
        _primeCategoryFeed(categoryId);
        final discoverState = ref.read(discoverProvider);
        final category = discoverState.categories.firstWhere(
          (cat) => cat.id == categoryId,
          orElse: () => discoverState.categories.first,
        );

        LoggingService.instance.debug(
          'Category selected: ${category.name}',
          tag: 'DiscoverView',
        );
      }
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Error selecting category',
        tag: 'DiscoverView',
        error: e,
        stackTrace: stackTrace,
      );
      // Safe error handling - don't call ErrorHandlerService during startup
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
      // Mark all notifications as read when opening ActivityView
      final currentUser = fa.FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final activityNotifier = ref.read(activityProvider.notifier);
        activityNotifier.markAllDelivered(currentUser.uid);
        LoggingService.instance.debug(
          'Marked all notifications as read',
          tag: 'DiscoverView',
        );
      }

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
  HomeVideo _convertToHomeVideo(Map<String, dynamic> video) {
    return HomeVideo(
      id: video['id'] ?? 'discover_${DateTime.now().millisecondsSinceEpoch}',
      videoURL: video['videoUrl'] ?? video['videoURL'] ?? '',
      thumbnailURL: video['thumbnailUrl'] ?? video['thumbnailURL'] ?? '',
      caption: video['title'] ?? 'Discover Video',
      creator: User(
        id: video['creatorId'] ?? 'unknown_creator',
        username: video['creator'] ?? 'Unknown Creator',
        displayName: video['creatorDisplayName'] ??
            video['creator'] ??
            'Unknown Creator',
        avatarURL: video['creatorAvatar'] ?? '',
        bio: video['creatorBio'] ?? '',
        hashtags: _safeCastToStringList(video['creatorHashtags']),
        followerCount: FieldMapper.safeInt(video['creatorFollowers']),
        followingCount: FieldMapper.safeInt(video['creatorFollowing']),
        postCount: FieldMapper.safeInt(video['creatorVideos']),
      ),
      likes: FieldMapper.safeInt(video['likes']),
      comments: FieldMapper.safeInt(video['comments']),
      views: FieldMapper.safeInt(video['views']),
      duration: FieldMapper.safeDouble(video['duration']),
      isLiked: video['isLiked'] ?? false,
      isFavorited: video['isFavorited'] ?? false,
      createdAt: video['createdAt'] ?? Timestamp.now(),
    );
  }

  Widget _buildNotificationButton(BuildContext context, WidgetRef ref) {
    final unreadCountAsync = ref.watch(unreadMessagesProvider);
    final activityState = ref.watch(activityProvider);

    // Calculate total unread count (messages + activity notifications)
    int totalUnreadCount = 0;
    unreadCountAsync.whenOrNull(
      data: (unreadCount) => totalUnreadCount += unreadCount,
    );

    // Add activity notification count
    int pendingCount = 0;
    for (final notifications in activityState.grouped.values) {
      for (final notification in notifications) {
        if (notification.status == 'pending') {
          pendingCount++;
          totalUnreadCount++;
        }
      }
    }

    // Debug badge calculation
    if (pendingCount > 0 || totalUnreadCount > 0) {
      LoggingService.instance.debug(
          '🔔 DiscoverView Badge: total=$totalUnreadCount, pending=$pendingCount, sections=${activityState.grouped.length}',
          tag: 'DiscoverView');
    }

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

    return GestureDetector(
      onTap: () {
        LoggingService.instance.debug(
          'GestureDetector onTap triggered',
          tag: 'DiscoverView',
        );
        _navigateToActivity(context);
      },
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        padding: const EdgeInsets.all(8),
        child: Stack(
          children: [
            const Icon(
              Icons.notifications_outlined,
              color: Colors.white,
              size: 24,
            ),
            // Notification badge
            if (totalUnreadCount > 0)
              Positioned(
                right: 0,
                top: 0,
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

  Widget _buildHeroChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.supportAccent, size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(followRefreshProvider, (previous, next) {
      if (previous == next) return;
      ref.read(discoverProvider.notifier).loadTrendingCreators();
    });

    final discoverState = ref.watch(discoverProvider);
    final selectedCategory = _selectedCategory == null
        ? null
        : discoverState.categories.firstWhere(
            (cat) => cat.id == _selectedCategory,
            orElse: () => discoverState.categories.first,
          );

    return Scaffold(
      backgroundColor: AppColors.supportBackground,
      body: Container(
        decoration: const BoxDecoration(color: AppColors.supportBackground),
        child: RefreshIndicator(
          color: AppColors.supportAccent,
          backgroundColor: AppColors.supportBackground,
          onRefresh: _refreshDiscoverView,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
            // App Bar
            SliverAppBar(
              backgroundColor: AppColors.supportBackground,
              elevation: 0,
              leading: InstantIconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
                hapticType: HapticFeedbackType.lightImpact,
              ),
              title: const Text(
                'Discover',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              centerTitle: true,
              actions: [_buildNotificationButton(context, ref)],
            ),

            // Search Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: AppColors.supportSurfaceGradient,
                        ),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 24,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selectedCategory == null
                                ? 'Find your next rabbit hole'
                                : 'Locked into ${selectedCategory.name}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            selectedCategory == null
                                ? 'Creators, categories, and short-form inspiration in one place.'
                                : 'Swipe into a deeper feed when something grabs you, or pull to refresh for a fresh set.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.74),
                              fontSize: 14,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildHeroChip(
                                Icons.whatshot_rounded,
                                '${discoverState.trendingCreators.length} trending',
                              ),
                              _buildHeroChip(
                                Icons.grid_view_rounded,
                                '${discoverState.categories.length} categories',
                              ),
                              _buildHeroChip(
                                Icons.explore_rounded,
                                selectedCategory?.name ?? 'Browse all',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: () {
                        AppNavigator.openSearch(context);
                      },
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.16),
                              blurRadius: 18,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.search,
                              color: AppColors.supportAccent,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                'Search creators, videos, hashtags…',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.65),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.white.withValues(alpha: 0.4),
                              size: 14,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Trending Creators Section with Lazy Loading
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 12,
                  bottom: 16,
                ),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeading(
                        'Trending Creators',
                        'People gaining momentum right now',
                      ),
                      const SizedBox(height: 16),
                      if (discoverState.isLoadingTrendingCreators &&
                          discoverState.trendingCreators.isEmpty)
                        _buildLoadingState()
                      else
                        SizedBox(
                          height: 200,
                          child: LazyLoadingList<TrendingCreator>(
                            loadData: _loadTrendingCreators,
                            itemBuilder: _buildTrendingCreatorCard,
                            itemsPerPage: 10,
                            emptyBuilder: (context) =>
                                _buildEmptyTrendingCreatorsState(),
                            loadingBuilder: (context) => _buildLoadingState(),
                            errorBuilder: _buildErrorState,
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 0,
                  bottom: 16,
                ),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeading(
                        'Categories',
                        'Jump into the corner of the app that fits your mood',
                      ),

                      // Categories PageView with proper spacing
                      SizedBox(
                        height: 288,
                        child: PageView.builder(
                          onPageChanged: (page) {
                            setState(() {
                              _currentCategoryPage = page;
                            });
                          },
                          itemCount:
                              (discoverState.categories.length / 6).ceil(),
                          itemBuilder: (context, pageIndex) {
                            final startIndex = pageIndex * 6;
                            final endIndex = (startIndex + 6).clamp(
                              0,
                              discoverState.categories.length,
                            );
                            final pageCategories = discoverState.categories
                                .sublist(startIndex, endIndex);

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: GridView.builder(
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                ),
                                itemCount: pageCategories.length,
                                itemBuilder: (context, index) {
                                  final category = pageCategories[index];
                                  return _accessibilityService
                                      .createAccessibleButton(
                                    semanticLabel: 'Category ${category.name}',
                                    semanticHint: _selectedCategory ==
                                            category.id
                                        ? 'Currently selected category. Tap to deselect.'
                                        : 'Tap to select this category',
                                    onPressed: () => _onCategorySelected(
                                      _selectedCategory == category.id
                                          ? null
                                          : category.id,
                                    ),
                                    hapticFeedbackType:
                                        AccessibilityHapticFeedbackType.light,
                                    child: CategoryCard(
                                      key: ValueKey(category.id),
                                      category: category,
                                      isSelected:
                                          _selectedCategory == category.id,
                                      hasCategorySelected:
                                          _selectedCategory != null,
                                      onTap: () => _onCategorySelected(
                                        _selectedCategory == category.id
                                            ? null
                                            : category.id,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),

                      // Reduced spacing between categories and dots
                      SizedBox(
                        height: 8,
                      ),

                      // Page indicator with proper safe area handling
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(
                              (discoverState.categories.length / 6).ceil(),
                              (index) => Container(
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: index == _currentCategoryPage
                                      ? const Color(0xFF40DCD1)
                                      : const Color(
                                          0xFF6B5AE0,
                                        ).withValues(alpha: 0.4),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
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
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.10),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeading(
                          'Resources',
                          'Helpful picks, tools, and ideas to explore next',
                        ),
                        const SizedBox(height: 12),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: discoverState.recommendedContent.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: RecommendedContentCard(
                                content: discoverState.recommendedContent[index],
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
              _buildCategoryVideoGridSliver(discoverState),
            ],

            // Bottom padding for tab bar
            const SliverToBoxAdapter(child: SizedBox(height: 60)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeading(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.68),
            fontSize: 13,
            height: 1.3,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryVideoGridSliver(
    DiscoverState discoverState,
  ) {
    if (_selectedCategory == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    // Get the selected category
    final selectedCategory = discoverState.categories.firstWhere(
      (cat) => cat.id == _selectedCategory,
      orElse: () => discoverState.categories.first,
    );

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.10),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeading(
                selectedCategory.name,
                'Swipe into a focused feed from this category',
              ),
              const SizedBox(height: 12),
              _buildVideoGridWithTapToSwipe(selectedCategory.id, discoverState),
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
    final future = _categoryFeedFutures.putIfAbsent(
      categoryId,
      () => _getCategoryVideosForFeed(categoryId),
    );
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9248D2)),
            ),
          );
        }

        if (snapshot.hasError) {
          return _buildErrorState(context, snapshot.error.toString());
        }

        final categoryVideos = snapshot.data ?? [];

        if (categoryVideos.isEmpty) {
          return _buildEmptyCategoryState();
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 1,
            mainAxisSpacing: 1,
            childAspectRatio: 9 / 16, // 9:16 aspect ratio for portrait videos
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
    return GestureDetector(
      onTap: () {
        LoggingService.instance.debug(
          'Tapped video: ${video['title']}',
          tag: 'DiscoverView',
        );
        _openSwipeableVideoFeed(allVideos, currentIndex);
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey[800],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video thumbnail
            Builder(
              builder: (context) {
                final thumbnailUrl = video['thumbnailUrl'] ??
                    video['thumbnailURL'] ??
                    video['thumbnail'] ??
                    '';

                if (thumbnailUrl.isNotEmpty) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      thumbnailUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: Colors.grey[800],
                          child: const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[800],
                          child: const Center(
                            child: Icon(
                              Icons.video_library_outlined,
                              color: Colors.white54,
                              size: 32,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                } else {
                  return Container(
                    color: Colors.grey[800],
                    child: const Center(
                      child: Icon(
                        Icons.video_library_outlined,
                        color: Colors.white54,
                        size: 32,
                      ),
                    ),
                  );
                }
              },
            ),
            // Duration badge (if available)
            Builder(
              builder: (context) {
                // Check both direct duration field and metadata.duration field
                dynamic duration = video['duration'];
                if (duration == null) {
                  final metadata = video['metadata'] as Map<String, dynamic>?;
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
    // Convert to HomeVideo objects for VideoPlayerViewOptimized
    final homeVideos =
        videos.map((video) => _convertToHomeVideo(video)).toList();

    // Navigate to full-screen swipeable video feed using HomeView pattern
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _buildCategoryVideoFeed(
          videos: homeVideos,
          startIndex: startIndex,
          categoryId: _selectedCategory ?? 'unknown',
        ),
      ),
    );
  }

  /// Category video feed widget that follows HomeView's audio management pattern exactly
  Widget _buildCategoryVideoFeed({
    required List<HomeVideo> videos,
    required int startIndex,
    required String categoryId,
  }) {
    return _CategoryVideoFeedStateful(
      videos: videos,
      startIndex: startIndex,
      categoryId: categoryId,
    );
  }

  /// Get videos for the category feed with proper ordering (new videos first, then shuffle)
  Future<List<Map<String, dynamic>>> _getCategoryVideosForFeed(
    String categoryId,
  ) async {
    try {
      LoggingService.instance.debug(
        'Loading category feed videos for: $categoryId',
        tag: 'DiscoverView',
      );

      // Load mixed videos (new + trending)
      final mixedVideos = await _loadMixedCategoryVideos(categoryId, null);

      LoggingService.instance.debug(
        'Raw mixed videos loaded: ${mixedVideos.length} for $categoryId',
        tag: 'DiscoverView',
      );

      if (mixedVideos.isEmpty) {
        LoggingService.instance.debug(
          'No mixed videos found for $categoryId',
          tag: 'DiscoverView',
        );
        return [];
      }

      // Sort videos: new videos first, then by trending score
      mixedVideos.sort((a, b) {
        final aIsNew = a['isNew'] as bool;
        final bIsNew = b['isNew'] as bool;
        final aScore = a['trendingScore'] as double;
        final bScore = b['trendingScore'] as double;

        // New videos always appear first
        if (aIsNew && !bIsNew) return -1;
        if (!aIsNew && bIsNew) return 1;

        // Then sort by trending score (highest first)
        return bScore.compareTo(aScore);
      });

      // Convert to the format expected by the UI
      final videos = <Map<String, dynamic>>[];
      final userIds = <String>{};

      for (final videoData in mixedVideos) {
        final data = videoData['data'] as Map<String, dynamic>?;
        if (data == null) {
          LoggingService.instance.debug(
            'Skipping video with null data: ${videoData['docId']}',
            tag: 'DiscoverView',
          );
          continue;
        }

        final status = data['status'] as String? ?? '';
        final isValidStatus =
            status == 'published' || status == 'ready' || status == 'active';
        if (!isValidStatus) {
          final videoId =
              videoData['docId'] as String? ?? data['id'] as String?;
          if (videoId != null) {
            LoggingService.instance.debug(
              'Skipping deleted video: $videoId',
              tag: 'DiscoverView',
            );
          }
          continue;
        }

        final userId = (data['userId'] ??
            data['creatorId'] ??
            data['creator_id']) as String?;
        if (userId != null) {
          userIds.add(userId);
        }
      }

      LoggingService.instance.debug(
        'Found ${userIds.length} unique user IDs for $categoryId',
        tag: 'DiscoverView',
      );

      // ✅ FIX #3: Batch fetch user data with chunking (Firestore whereIn limit is 10)
      final userMap = await _fetchUsersByIds(userIds);

      LoggingService.instance.debug(
        'Fetched ${userMap.length} user documents for $categoryId',
        tag: 'DiscoverView',
      );

      // Build final video list
      for (final videoData in mixedVideos) {
        final data = videoData['data'] as Map<String, dynamic>;
        final userId = (data['userId'] ??
            data['creatorId'] ??
            data['creator_id']) as String?;

        if (userId == null) {
          LoggingService.instance.debug(
            'Skipping video with null userId: ${videoData['docId']}',
            tag: 'DiscoverView',
          );
          continue;
        }

        final userData = userMap[userId];
        if (userData == null) {
          LoggingService.instance.debug(
            'Skipping video with missing user data: ${videoData['docId']}, userId: $userId',
            tag: 'DiscoverView',
          );
          continue;
        }

        final thumbnailUrl = FieldMapper.getThumbnailUrl(data);

        final durationValue = data['duration'] ?? data['metadata']?['duration'];
        videos.add({
          'id': videoData['docId'],
          'title': FieldMapper.safeString(
            data['caption'] ?? data['title'] ?? data['metadata']?['title'] ??
                'Untitled',
          ),
          'creator': FieldMapper.getDisplayName(userData),
          'thumbnail': thumbnailUrl,
          'thumbnailUrl': thumbnailUrl,
          'thumbnailURL': thumbnailUrl,
          'views': FieldMapper.safeInt(data['views'] ?? data['viewsCount']),
          'duration': FieldMapper.safeDouble(durationValue),
          'videoUrl': FieldMapper.getVideoUrl(data),
          'creatorId': userId,
          'creatorAvatar': FieldMapper.getAvatarUrl(userData),
          'creatorUsername': FieldMapper.safeString(userData['username']),
          'creatorDisplayName': FieldMapper.getDisplayName(userData),
          'creatorBio': FieldMapper.safeString(userData['bio']),
          'creatorHashtags': userData['hashtags'] ?? [],
          'creatorFollowers': FieldMapper.safeInt(userData['followerCount']),
          'creatorFollowing': FieldMapper.safeInt(userData['followingCount']),
          'creatorVideos': FieldMapper.safeInt(userData['postCount']),
          'likes': FieldMapper.safeInt(data['likes'] ?? data['likesCount']),
          'comments': FieldMapper.safeInt(
            data['comments'] ?? data['commentsCount'],
          ),
          'createdAt': data['createdAt'],
          'isLiked': data['isLiked'] ?? false,
          'isFavorited': data['isFavorited'] ?? false,
          'trendingScore': videoData['trendingScore'] ?? 0.0,
          'isNew': videoData['isNew'] ?? false,
          'isTrending': (videoData['trendingScore'] ?? 0.0) > 100.0,
        });
      }

      LoggingService.instance.debug(
        'Category feed prepared ${videos.length} videos for $categoryId',
        tag: 'DiscoverView',
      );

      return videos;
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Error loading category feed videos for $categoryId',
        tag: 'DiscoverView',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  Widget _buildLoadingState() {
    return const SizedBox(
      height: 120,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            SizedBox(height: 12),
            Text(
              'Loading trending creators...',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyTrendingCreatorsState() {
    return SizedBox(
      height: 120,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people, size: 32, color: Colors.white70),
            const SizedBox(height: 12),
            Text(
              'No trending creators yet',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCategoryState() {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.video_library_outlined,
              size: 48,
              color: Colors.white70,
            ),
            const SizedBox(height: 16),
            Text(
              'No videos found for this category',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first to upload a video!',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  /// Load mixed category videos (recent + trending)
  Future<List<Map<String, dynamic>>> _loadMixedCategoryVideos(
    String categoryId,
    DocumentSnapshot? startAfter,
  ) async {
    try {
      LoggingService.instance.debug(
        'Loading mixed category videos for: $categoryId',
        tag: 'DiscoverView',
      );
      if (_normalizeCategoryKey(categoryId) == 'all') {
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

  /// Load all videos without category filter (All category)
  Future<List<Map<String, dynamic>>> _loadAllVideosNoCategory(
    DocumentSnapshot? startAfter,
  ) async {
    try {
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('videos')
          .where('status', whereIn: _allowedVideoStatuses)
          .orderBy('createdAt', descending: true)
          .limit(_videosPerPage * 2);
      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      final videos = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        videos.add({
          'docId': doc.id,
          'data': data,
          'isNew': false,
          'trendingScore': 0.0,
        });
      }

      videos.sort((a, b) {
        final aTs = a['data']['createdAt'] as Timestamp?;
        final bTs = b['data']['createdAt'] as Timestamp?;
        if (aTs == null || bTs == null) return 0;
        return bTs.compareTo(aTs);
      });
      return videos.take(_videosPerPage).toList();
    } catch (e) {
      LoggingService.instance.error(
        'Error loading all videos (no category)',
        tag: 'DiscoverView',
        error: e,
      );
      return [];
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
            .collection('users')
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

/// Stateful widget for category video feed that follows HomeView's pattern exactly
class _CategoryVideoFeedStateful extends ConsumerStatefulWidget {
  final List<HomeVideo> videos;
  final int startIndex;
  final String categoryId;

  const _CategoryVideoFeedStateful({
    required this.videos,
    required this.startIndex,
    required this.categoryId,
  });

  @override
  ConsumerState<_CategoryVideoFeedStateful> createState() =>
      _CategoryVideoFeedStatefulState();
}

class _CategoryVideoFeedStatefulState
    extends ConsumerState<_CategoryVideoFeedStateful> {
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

    // 🔊 CRITICAL FIX: Unblock playback when category feed opens
    // DiscoverView blocks playback, but category feed needs videos to play
    // This allows VideoPlayerViewOptimized to initialize and play videos
    final manager = GlobalPlaybackManager.instance;
    manager.unblock(); // Unblock to allow video initialization
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

    // 🔥 CRITICAL MEMORY FIX: Dispose all controllers for this category feed
    // This prevents MediaCodec NO_MEMORY errors by freeing resources immediately
    final tabId = 'discoverView_${widget.categoryId}';
    GlobalPlaybackManager.instance.disposeControllersForOwner(tabId);

    // 🔊 AUDIO FIX: Pause all videos when category feed closes
    GlobalPlaybackManager.instance.pauseAll();

    super.dispose();
  }

  /// Set up real-time listeners to detect when videos are deleted (first 15)
  void _setupRealtimeDeletionListeners() {
    final videosToListen = _videos.take(15).toList();
    for (final video in videosToListen) {
      final subscription = FirebaseFirestore.instance
          .collection('videos')
          .doc(video.id)
          .snapshots()
          .listen((snapshot) {
        if (!mounted) return;

        if (!snapshot.exists) {
          _removeVideoFromFeed(video.id);
          return;
        }

        final data = snapshot.data();
        final status = data?['status'] as String? ?? '';

        if (status == 'deleted') {
          _removeVideoFromFeed(video.id);
        }
      });

      _videoListeners[video.id] = subscription;
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
                    tabId: 'discoverView_${widget.categoryId}',
                    ownerKey: PlaybackOwners.discover,
                    homeViewModel: ref.read(hp.homeProvider.notifier),
                    showSheet: false,
                    sheetType: '',
                    showHUD: true, // Show HUD like HomeView
                    onShowProfile: () {
                      AppNavigator.openStreamerCard(
                        context,
                        userId: video.creator.id,
                        currentUserId: fa.FirebaseAuth.instance.currentUser?.uid,
                        onDismiss: () => Navigator.of(context).pop(),
                      );
                    },
                    onShowComments: () {
                      // ✅ FIX: Use actual CommentsView2 instead of placeholder
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          fullscreenDialog: true,
                          builder: (context) => CommentsView2(
                            videoId: video.id,
                            videoOwnerId: video.creator.id,
                          ),
                        ),
                      );
                    },
                    onShowShare: () {
                      // ✅ FIX: Use actual EnhancedShareSheet instead of placeholder
                      HapticFeedback.lightImpact();
                      showModalBottomSheet<void>(
                        context: context,
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
                        currentUserId: fa.FirebaseAuth.instance.currentUser?.uid,
                        onDismiss: () => Navigator.of(context).pop(),
                      );
                    },
                    isLiked: video.isLiked,
                    isBookmarked: video.isFavorited,
                  );
                },
              ),
            ),
            // Back button overlay (HomeView pattern)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              child: SafeArea(
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.arrow_back_ios,
                    color: Colors.white,
                    size: 24,
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
