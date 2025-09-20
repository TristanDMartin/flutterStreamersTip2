import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
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

  Future<FollowingFeedResult> fetchRankedFollowingFeed({
    required String viewerId,
    int pageSize = 20,
    Map<String, dynamic>? afterCursor,
  }) async {
    // 1) Load connections (unmuted/unblocked)
    final peersSnap = await _db
        .collection('users')
        .doc(viewerId)
        .collection('connections')
        .where('muted', isEqualTo: false)
        .where('blocked', isEqualTo: false)
        .get();

    final List<String> creatorIds = <String>[
      for (final d in peersSnap.docs) (d.data()['peerId'] ?? '').toString()
    ].where((e) => e.isNotEmpty).toList();

    if (creatorIds.isEmpty) {
      return FollowingFeedResult(items: <HomeVideo>[], nextCursor: null);
    }

    // 2) Fetch recent videos in optimized batches (reduced from 10 to 5 for better performance)
    final DateTime windowStart = DateTime.now().subtract(const Duration(days: 7)); // Reduced from 30 to 7 days
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    
    // Limit to top 20 creators to prevent excessive queries
    final limitedCreatorIds = creatorIds.take(20).toList();
    
    for (int i = 0; i < limitedCreatorIds.length; i += 5) { // Reduced batch size from 10 to 5
      final chunk = limitedCreatorIds.sublist(i, math.min(i + 5, limitedCreatorIds.length));
      if (chunk.isEmpty) continue;
      
      try {
        final snap = await _db
            .collection('videos')
            .where('creatorId', whereIn: chunk)
            .where('createdAt', isGreaterThan: Timestamp.fromDate(windowStart))
            .orderBy('createdAt', descending: true)
            .limit(50) // Reduced from 200 to 50
            .get();
        docs.addAll(snap.docs);
      } catch (e) {
        // Skip failed batches to prevent total failure
        continue;
      }
    }

    if (docs.isEmpty) {
      return FollowingFeedResult(items: <HomeVideo>[], nextCursor: null);
    }

    // 3) Pre-filter: safe/visibility (best-effort if fields missing)
    final List<_ScoredVideo> candidates = <_ScoredVideo>[];
    const double tauDays = 2.0;
    final DateTime now = DateTime.now();

    // Build affinity map from connections' strength (0..1)
    final Map<String, double> affinity = <String, double>{
      for (final d in peersSnap.docs)
        (d.data()['peerId'] ?? '').toString():
            ((d.data()['strength'] ?? 0.3) as num).toDouble().clamp(0.0, 1.0),
    };

    for (final doc in docs) {
      final data = doc.data();
      final String creatorId = (data['creatorId'] ?? '').toString();
      if (creatorId.isEmpty) continue;

      // visibility filter
      final String visibility = (data['visibility'] ?? 'public').toString();
      if (visibility == 'private') continue;
      if (visibility == 'connections' && !creatorIds.contains(creatorId)) continue;

      // safety filter
      final double safeScore = ((data['safeScore'] ?? 1.0) as num).toDouble();
      if (safeScore < 0.8) continue;

      // build score components
      final Timestamp ts = (data['createdAt'] as Timestamp? ?? Timestamp.now());
      final double ageDays = now.difference(ts.toDate()).inSeconds / 86400.0;
      final double recency = math.exp(-ageDays / tauDays);
      final double a = affinity[creatorId] ?? 0.3;

      final Map<String, dynamic> stats = (data['stats'] as Map<String, dynamic>? ?? <String, dynamic>{});
      final double avgWatchPct = ((stats['avgWatchPct'] ?? 0.0) as num).toDouble().clamp(0.0, 1.0);
      final double completionRate = ((stats['completionRate'] ?? 0.0) as num).toDouble().clamp(0.0, 1.0);
      final int likes = (stats['likes'] ?? data['likes'] ?? 0) as int;
      final int comments = (stats['comments'] ?? data['comments'] ?? 0) as int;
      final int views = (stats['views'] ?? data['views'] ?? 1) as int;
      final double engagement = views > 0 ? ((likes + comments) / views).clamp(0.0, 1.0) : 0.0;
      final double quality = 0.5 * avgWatchPct + 0.3 * completionRate + 0.2 * engagement;

      final String category = (data['category'] ?? '').toString();
      final double categoryMatch = category.isNotEmpty ? 1.0 : 0.5;
      const double socialBoost = 0.05; // small constant lift by default

      final double base = 0.40 * recency + 0.25 * a + 0.20 * quality + 0.08 * categoryMatch + 0.05 * socialBoost;

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
      final double adjusted = v.score - 0.10 * fatigue;
      diversified.add(v.copyWith(score: adjusted));
      counts[v.creatorId] = current + 1;
    }
    diversified.sort((a, b) {
      final c = b.score.compareTo(a.score);
      if (c != 0) return c;
      return b.createdAt.compareTo(a.createdAt);
    });

    // 5) Select page with creator cap K within first M
    const int capK = 2;
    const int windowM = 10;
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
    final _ScoredVideo last = output.isNotEmpty ? output.last : diversified.first;
    final Map<String, dynamic> nextCursor = <String, dynamic>{
      'lastScore': last.score,
      'lastCreatedAt': Timestamp.fromDate(last.createdAt),
      'lastId': last.id,
    };
    return FollowingFeedResult(items: items, nextCursor: items.isEmpty ? null : nextCursor);
  }

  HomeVideo _mapDocToHomeVideo(_ScoredVideo v) {
    final data = v.data;
    final String caption = (data['caption'] ?? '').toString();
    final int likes = (data['likes'] ?? (data['stats']?['likes'] ?? 0)) as int;
    final int comments = (data['comments'] ?? (data['stats']?['comments'] ?? 0)) as int;
    final String creatorId = (data['creatorId'] ?? '').toString();
    final String creatorName = (data['creatorName'] ?? 'creator').toString();
    final String videoURL = (data['videoURL'] ?? data['videoUrl'] ?? '').toString();
    return HomeVideo(
      id: v.id,
      creator: User(id: creatorId, username: creatorName, displayName: creatorName),
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


