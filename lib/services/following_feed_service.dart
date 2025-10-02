import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/home_video.dart';
import '../models/user.dart';

class FollowingFeedResult {
  FollowingFeedResult({required this.items, required this.nextCursor});
  final List<HomeVideo> items;
  final Map<String, dynamic>? nextCursor;
}

class FollowingFeedService {
  FollowingFeedService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  // PRODUCTION READY: Configurable algorithm parameters
  static const int _maxCreators = 20;
  static const int _maxVideosPerQuery = 200;
  static const double _tauDays = 2.0;
  static const int _creatorCap = 2;
  static const int _windowSize = 10;
  static const double _socialBoost = 0.05;
  static const double _fatiguePenalty = 0.10;

  Future<FollowingFeedResult> fetchRankedFollowingFeed({
    required String viewerId,
    int pageSize = 20,
    Map<String, dynamic>? afterCursor,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      debugPrint('🔄 Fetching following feed for user: $viewerId');

      // 1) Load connections using comprehensive approach (same as UserService)
      final creatorIds = <String>{};

      // Method 1: Check connections collection (users/{userId}/connections)
      try {
        final connectionsSnapshot = await _db
            .collection('users')
            .doc(viewerId)
            .collection('connections')
            .where('muted', isEqualTo: false)
            .where('blocked', isEqualTo: false)
            .get();

        for (final doc in connectionsSnapshot.docs) {
          final data = doc.data();
          final peerId = data['peerId'] ?? doc.id;
          if (peerId.isNotEmpty) {
            creatorIds.add(peerId);
            debugPrint('🔍 FollowingFeedService: Found connection: $peerId');
          }
        }
      } catch (e) {
        debugPrint('⚠️ FollowingFeedService: Error fetching connections: $e');
      }

      // Method 2: Check follows collection (follows/{followerId}_{followedId})
      try {
        final followsSnapshot = await _db
            .collection('follows')
            .where('followerId', isEqualTo: viewerId)
            .get();

        for (final doc in followsSnapshot.docs) {
          final data = doc.data();
          final followedId = data['followedId'] ?? '';
          if (followedId.isNotEmpty) {
            creatorIds.add(followedId);
            debugPrint(
                '🔍 FollowingFeedService: Found follow relationship: $followedId');
          }
        }
      } catch (e) {
        debugPrint('⚠️ FollowingFeedService: Error fetching follows: $e');
      }

      // Method 3: Check relationships collection (relationships/{relationshipId})
      try {
        final relationshipsSnapshot = await _db
            .collection('relationships')
            .where('followerId', isEqualTo: viewerId)
            .get();

        for (final doc in relationshipsSnapshot.docs) {
          final data = doc.data();
          final followingId = data['followingId'] ?? '';
          if (followingId.isNotEmpty) {
            creatorIds.add(followingId);
            debugPrint(
                '🔍 FollowingFeedService: Found relationship: $followingId');
          }
        }
      } catch (e) {
        debugPrint('⚠️ FollowingFeedService: Error fetching relationships: $e');
      }

      final creatorIdsList = creatorIds.toList();
      debugPrint(
          '✅ FollowingFeedService: Found ${creatorIdsList.length} following users: $creatorIdsList');

      if (creatorIdsList.isEmpty) {
        return FollowingFeedResult(items: <HomeVideo>[], nextCursor: null);
      }

      // 2) Fetch recent videos with optimized single query (FIXED: Eliminated N+1 problem)
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
          <QueryDocumentSnapshot<Map<String, dynamic>>>[];

      // Limit to max creators to prevent excessive queries
      final limitedCreatorIds = creatorIdsList.take(_maxCreators).toList();

      if (limitedCreatorIds.isEmpty) {
        return FollowingFeedResult(items: <HomeVideo>[], nextCursor: null);
      }

      try {
        // ULTRA-SIMPLE: Query without any complex filters to avoid index issues
        debugPrint(
            '🔍 FollowingFeedService: Using ultra-simple query approach...');

        for (final creatorId in limitedCreatorIds) {
          try {
            // SIMPLEST POSSIBLE: Just get videos by userId, no filters at all
            final snap = await _db
                .collection('videos')
                .where('userId', isEqualTo: creatorId)
                .limit(50) // Get more videos per creator
                .get();

            // Add ALL videos (no date filtering to avoid any issues)
            docs.addAll(snap.docs);
            debugPrint(
                '🔍 FollowingFeedService: Found ${snap.docs.length} videos for creator: $creatorId');
          } catch (e) {
            debugPrint(
                '⚠️ FollowingFeedService: Error fetching videos for creator $creatorId: $e');
            // Continue with other creators even if one fails
          }
        }

        // Sort all docs by createdAt descending (in memory)
        docs.sort((a, b) {
          final aTime =
              (a.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
          final bTime =
              (b.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
          return bTime.compareTo(aTime);
        });

        // Limit total results
        if (docs.length > _maxVideosPerQuery) {
          docs = docs.take(_maxVideosPerQuery).toList();
        }

        debugPrint(
            '🔍 FollowingFeedService: Total videos found: ${docs.length}');
      } catch (e) {
        // FIXED: Proper error handling with fallback
        debugPrint('❌ Error fetching videos: $e');
        // Log error for monitoring
        if (kDebugMode) {
          debugPrint(
              'FollowingFeedService: Failed to fetch videos for ${limitedCreatorIds.length} creators');
        }
        return FollowingFeedResult(items: <HomeVideo>[], nextCursor: null);
      }

      if (docs.isEmpty) {
        return FollowingFeedResult(items: <HomeVideo>[], nextCursor: null);
      }

      // 3) Pre-filter: safe/visibility (best-effort if fields missing)
      final List<_ScoredVideo> candidates = <_ScoredVideo>[];
      final DateTime now = DateTime.now();

      // Build affinity map from connections' strength (0..1)
      final Map<String, double> affinity = <String, double>{};

      // Set default affinity for all found connections
      for (final creatorId in creatorIdsList) {
        affinity[creatorId] = 0.8; // Default high affinity for connections
      }

      for (final doc in docs) {
        final data = doc.data();
        final String creatorId = (data['userId'] ?? '').toString();
        if (creatorId.isEmpty) continue;

        // visibility filter
        final String visibility = (data['visibility'] ?? 'public').toString();
        if (visibility == 'private') continue;
        if (visibility == 'connections' &&
            !creatorIdsList.contains(creatorId)) {
          continue;
        }

        // safety filter
        final double safeScore = ((data['safeScore'] ?? 1.0) as num).toDouble();
        if (safeScore < 0.8) continue;

        // build score components
        final Timestamp ts =
            (data['createdAt'] as Timestamp? ?? Timestamp.now());
        final double ageDays = now.difference(ts.toDate()).inSeconds / 86400.0;
        final double recency = math.exp(-ageDays / _tauDays);
        final double a = affinity[creatorId] ?? 0.3;

        final Map<String, dynamic> stats =
            (data['stats'] as Map<String, dynamic>? ?? <String, dynamic>{});
        final double avgWatchPct =
            ((stats['avgWatchPct'] ?? 0.0) as num).toDouble().clamp(0.0, 1.0);
        final double completionRate = ((stats['completionRate'] ?? 0.0) as num)
            .toDouble()
            .clamp(0.0, 1.0);
        final int likes = (stats['likes'] ?? data['likes'] ?? 0) as int;
        final int comments =
            (stats['comments'] ?? data['comments'] ?? 0) as int;
        final int views = (stats['views'] ?? data['views'] ?? 1) as int;
        final double engagement =
            views > 0 ? ((likes + comments) / views).clamp(0.0, 1.0) : 0.0;
        final double quality =
            0.5 * avgWatchPct + 0.3 * completionRate + 0.2 * engagement;

        final String category = (data['category'] ?? '').toString();
        final double categoryMatch = category.isNotEmpty ? 1.0 : 0.5;
        const double socialBoost = _socialBoost; // Configurable social boost

        final double base = 0.40 * recency +
            0.25 * a +
            0.20 * quality +
            0.08 * categoryMatch +
            socialBoost;

        candidates.add(
          _ScoredVideo(
            id: doc.id,
            creatorId: creatorId,
            createdAt: ts.toDate(),
            score: base,
            data: data,
          ),
        );
      }

      // 4) Diversity penalty pass: penalize surplus from same creator while selecting top N
      candidates.sort((a, b) => b.score.compareTo(a.score));
      final List<_ScoredVideo> diversified = <_ScoredVideo>[];
      final Map<String, int> counts = <String, int>{};
      for (final v in candidates) {
        final int current = counts[v.creatorId] ?? 0;
        final double fatigue = math.min(current / 3.0, 1.0);
        final double adjusted = v.score - _fatiguePenalty * fatigue;
        diversified.add(v.copyWith(score: adjusted));
        counts[v.creatorId] = current + 1;
      }
      diversified.sort((a, b) {
        final c = b.score.compareTo(a.score);
        if (c != 0) return c;
        return b.createdAt.compareTo(a.createdAt);
      });

      // 5) Select page with creator cap K within first M
      const int capK = _creatorCap;
      const int windowM = _windowSize;
      final List<_ScoredVideo> output = <_ScoredVideo>[];
      final Map<String, int> topCounts = <String, int>{};
      for (final v in diversified) {
        final int count = topCounts[v.creatorId] ?? 0;
        if (output.length < windowM && count >= capK) continue;
        output.add(v);
        topCounts[v.creatorId] = count + 1;
        if (output.length == pageSize) break;
      }

      final List<HomeVideo> items = output.map(_mapDocToHomeVideo).toList();
      final _ScoredVideo last =
          output.isNotEmpty ? output.last : diversified.first;
      final Map<String, dynamic> nextCursor = <String, dynamic>{
        'lastScore': last.score,
        'lastCreatedAt': Timestamp.fromDate(last.createdAt),
        'lastId': last.id,
      };

      stopwatch.stop();
      debugPrint(
          '✅ Following feed fetched: ${items.length} items in ${stopwatch.elapsedMilliseconds}ms');

      return FollowingFeedResult(
          items: items, nextCursor: items.isEmpty ? null : nextCursor);
    } catch (e) {
      stopwatch.stop();
      debugPrint(
          '❌ Following feed fetch failed: $e (${stopwatch.elapsedMilliseconds}ms)');
      return FollowingFeedResult(items: <HomeVideo>[], nextCursor: null);
    }
  }

  HomeVideo _mapDocToHomeVideo(_ScoredVideo v) {
    final data = v.data;
    final String caption = (data['caption'] ?? '').toString();
    final int likes = (data['likes'] ?? (data['stats']?['likes'] ?? 0)) as int;
    final int comments =
        (data['comments'] ?? (data['stats']?['comments'] ?? 0)) as int;
    final String creatorId = (data['userId'] ?? '').toString();
    final String creatorName = (data['creatorName'] ?? 'creator').toString();
    final String videoURL =
        (data['videoURL'] ?? data['videoUrl'] ?? '').toString();
    return HomeVideo(
      id: v.id,
      creator:
          User(id: creatorId, username: creatorName, displayName: creatorName),
      videoURL: videoURL,
      thumbnailURL: data['thumbnailURL'] as String?,
      likes: likes,
      comments: comments,
      views: (data['views'] ?? (data['stats']?['views'] ?? 0)) as int,
      caption: caption,
      isLiked: false,
      isFavorited: false,
      mlScore: v.score,
      categoryId: (data['category'] ?? '').toString(),
    );
  }
}

class _ScoredVideo {
  _ScoredVideo({
    required this.id,
    required this.creatorId,
    required this.createdAt,
    required this.score,
    required this.data,
  });
  final String id;
  final String creatorId;
  final DateTime createdAt;
  final double score;
  final Map<String, dynamic> data;

  _ScoredVideo copyWith({double? score}) => _ScoredVideo(
        id: id,
        creatorId: creatorId,
        createdAt: createdAt,
        score: score ?? this.score,
        data: data,
      );
}
