import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/video_url_resolver.dart';
import '../models/home_video.dart';
import '../models/user.dart' as app_user;
import 'video_cache_service.dart';
import 'video_prefetch_service.dart';
import 'network_policy_service.dart';
import 'package:streamers_tip/utils/secure_log.dart';

/// Service responsible for warm/cold start handling and feed initialization
class FeedBootstrapService {
  static final FeedBootstrapService _instance =
      FeedBootstrapService._internal();
  factory FeedBootstrapService() => _instance;
  FeedBootstrapService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final VideoCacheService _cacheService = VideoCacheService();
  final VideoPrefetchService _prefetchService = VideoPrefetchService();
  final NetworkPolicyService _networkPolicy = NetworkPolicyService();

  /// Bootstrap the feed for instant play (OPTIMIZED)
  /// Returns cached data immediately, then fetches fresh data
  Future<BootstrapResult> bootstrap() async {
    final startTime = DateTime.now();
    secureLog('🚀 Starting optimized feed bootstrap...');

    try {
      // Initialize only critical services
      await _cacheService.initialize();

      // Initialize network policy in background (non-blocking)
      _networkPolicy.initialize().catchError((e) {
        secureLog('⚠️ Network policy init failed (non-critical): $e');
      });

      // Try to load cached feed first (warm start)
      final cachedFeed = await _loadCachedFeed();

      if (cachedFeed != null && cachedFeed.items.isNotEmpty) {
        secureLog('✅ Warm start: Found ${cachedFeed.items.length} cached items');

        // Prime the first video in background (non-blocking)
        _primeWarmStartCandidate(cachedFeed.items.first).catchError((e) {
          secureLog('⚠️ Failed to prime warm start candidate: $e');
        });

        // Return cached data immediately
        final result = BootstrapResult(
          items: cachedFeed.items,
          cursor: cachedFeed.cursor,
          etag: cachedFeed.etag,
          isWarmStart: true,
          bootstrapTimeMs: DateTime.now().difference(startTime).inMilliseconds,
        );

        // Fetch fresh data in background
        _fetchFreshFeedInBackground(cachedFeed.etag);

        return result;
      } else {
        secureLog('❄️ Cold start: No cached feed found');
        return await _coldStart();
      }
    } catch (e) {
      secureLog('❌ Bootstrap error: $e');
      return await _coldStart();
    }
  }

  /// Load cached feed from disk
  Future<CachedFeed?> _loadCachedFeed() async {
    try {
      // This would integrate with your existing cache service
      // For now, return null to simulate cold start
      return null;
    } catch (e) {
      secureLog('Error loading cached feed: $e');
      return null;
    }
  }

  /// Prime the warm start candidate for instant play
  Future<void> _primeWarmStartCandidate(HomeVideo video) async {
    try {
      // Prefetch poster and first segment
      await _prefetchService.prime(
        videoId: video.id,
        posterUrl: video.thumbnailURL ?? '',
        videoUrl: video.videoURL,
      );

      secureLog('✅ Primed warm start candidate: ${video.id}');
    } catch (e) {
      secureLog('❌ Error priming warm start candidate: $e');
    }
  }

  /// Handle cold start scenario
  Future<BootstrapResult> _coldStart() async {
    try {
      // Fetch fresh feed data
      final freshFeed = await _fetchFreshFeed();

      if (freshFeed.items.isNotEmpty) {
        // Prime the first video
        await _primeWarmStartCandidate(freshFeed.items.first);
      }

      return BootstrapResult(
        items: freshFeed.items,
        cursor: freshFeed.cursor,
        etag: freshFeed.etag,
        isWarmStart: false,
        bootstrapTimeMs:
            DateTime.now().difference(DateTime.now()).inMilliseconds,
      );
    } catch (e) {
      secureLog('❌ Cold start error: $e');
      return BootstrapResult(
        items: [],
        cursor: null,
        etag: null,
        isWarmStart: false,
        bootstrapTimeMs: 0,
      );
    }
  }

  /// Fetch fresh feed data from server
  Future<FeedData> _fetchFreshFeed() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Fetch from Firestore with proper indexing
      final query = _firestore
          .collection('videos')
          .where('isPublished', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(20);

      final snapshot = await query.get();

      final videos = snapshot.docs.map((doc) {
        final data = doc.data();
        return HomeVideo(
          id: doc.id,
          creator: app_user.User(
            id: data['creatorId'] ?? '',
            username: data['creatorUsername'] ?? '',
            displayName: data['creatorDisplayName'] ?? '',
            avatarURL: data['creatorAvatarURL'],
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
          mlScore: (data['mlScore'] ?? 0.0).toDouble(),
          categoryId: data['categoryId'] ?? '',
        );
      }).toList();

      // Generate ETag for caching
      final etag = _generateETag(videos);

      return FeedData(
        items: videos,
        cursor: snapshot.docs.isNotEmpty ? snapshot.docs.last.id : null,
        etag: etag,
      );
    } catch (e) {
      secureLog('❌ Error fetching fresh feed: $e');
      rethrow;
    }
  }

  /// Fetch fresh feed in background (for warm start updates)
  Future<void> _fetchFreshFeedInBackground(String? currentETag) async {
    try {
      final freshFeed = await _fetchFreshFeed();

      // Only update if ETag changed
      if (freshFeed.etag != currentETag) {
        secureLog('🔄 Fresh feed available, ETag changed');
        // This would trigger a state update in your provider
        // await _updateFeedState(freshFeed);
      }
    } catch (e) {
      secureLog('❌ Background fetch error: $e');
    }
  }

  /// Generate ETag for feed data
  String _generateETag(List<HomeVideo> videos) {
    final videoIds = videos.map((v) => v.id).join(',');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${videoIds.hashCode}_$timestamp';
  }
}

/// Result of bootstrap operation
class BootstrapResult {
  final List<HomeVideo> items;
  final String? cursor;
  final String? etag;
  final bool isWarmStart;
  final int bootstrapTimeMs;

  BootstrapResult({
    required this.items,
    required this.cursor,
    required this.etag,
    required this.isWarmStart,
    required this.bootstrapTimeMs,
  });
}

/// Cached feed data
class CachedFeed {
  final List<HomeVideo> items;
  final String? cursor;
  final String? etag;
  final DateTime cachedAt;

  CachedFeed({
    required this.items,
    required this.cursor,
    required this.etag,
    required this.cachedAt,
  });
}

/// Fresh feed data
class FeedData {
  final List<HomeVideo> items;
  final String? cursor;
  final String? etag;

  FeedData({
    required this.items,
    required this.cursor,
    required this.etag,
  });
}
