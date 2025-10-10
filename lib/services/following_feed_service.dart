import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/home_video.dart';
import '../models/user.dart';

/// Service to fetch Following feed videos from Connections list
/// This ensures Following tab pulls from NetworkView Connections data
class FollowingFeedService {
  static FollowingFeedService? _instance;
  static FollowingFeedService get instance =>
      _instance ??= FollowingFeedService._();

  FollowingFeedService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetch Following videos from user's Connections list
  /// Uses the same data source as NetworkView Connections tab
  Future<List<HomeVideo>> fetchFollowingVideos({
    required String viewerId,
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      log('👥 FollowingFeedService: Fetching videos for viewer $viewerId');

      // 1) Get user's connections from the same source as NetworkView
      final connections = await _getUserConnections(viewerId);

      if (connections.isEmpty) {
        log('👥 FollowingFeedService: No connections found for user $viewerId');
        return [];
      }

      // 2) Extract author IDs from connections
      log('👥 FollowingFeedService: Processing ${connections.length} total connections');
      final authorIds = connections
          .where((conn) =>
              conn.followState == 'mutual' || conn.followState == 'following')
          .map((conn) => conn.connectionId)
          .toList();

      if (authorIds.isEmpty) {
        log('👥 FollowingFeedService: No valid connections for videos (connections: ${connections.length})');
        for (final conn in connections) {
          log('   - Connection ${conn.connectionId}: followState=${conn.followState}');
        }
        return [];
      }

      log('👥 FollowingFeedService: Found ${authorIds.length} connections to fetch videos from');
      log('👥 FollowingFeedService: Author IDs: $authorIds');

      // 3) Fetch videos from these authors using chunked queries
      final videos =
          await _fetchVideosFromAuthors(authorIds, limit, startAfter);

      log('👥 FollowingFeedService: Fetched ${videos.length} videos');
      return videos;
    } catch (e) {
      log('❌ FollowingFeedService: Error fetching following videos: $e');
      return [];
    }
  }

  /// Get user's connections (same as NetworkView Connections tab)
  Future<List<Connection>> _getUserConnections(String viewerId) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(viewerId)
          .collection('connections')
          .get();

      return querySnapshot.docs
          .map((doc) => _connectionFromFirestore(doc))
          .toList();
    } catch (e) {
      log('❌ FollowingFeedService: Error fetching connections: $e');
      return [];
    }
  }

  /// Fetch videos from multiple authors using chunked whereIn queries
  /// Firestore has a limit of 10 items in whereIn, so we chunk the IDs
  Future<List<HomeVideo>> _fetchVideosFromAuthors(
    List<String> authorIds,
    int limit,
    DocumentSnapshot? startAfter,
  ) async {
    final allVideos = <HomeVideo>[];

    // Chunk author IDs into groups of 10 (Firestore whereIn limit)
    for (int i = 0; i < authorIds.length; i += 10) {
      final chunk = authorIds.skip(i).take(10).toList();

      try {
        // Try querying by creatorId (the field name in the video document)
        Query query = _firestore
            .collection('videos')
            .where('creatorId', whereIn: chunk)
            .orderBy('createdAt', descending: true);

        // Add pagination if needed
        if (startAfter != null && i == 0) {
          query = query.startAfterDocument(startAfter);
        }

        // Limit per chunk to avoid overwhelming the query
        query = query.limit(limit ~/ (authorIds.length / 10).ceil() + 5);

        final querySnapshot = await query.get();

        log('👥 FollowingFeedService: Query returned ${querySnapshot.docs.length} documents for chunk: $chunk');

        final chunkVideos = querySnapshot.docs
            .map((doc) => _homeVideoFromFirestore(doc))
            .toList();

        allVideos.addAll(chunkVideos);

        log('👥 FollowingFeedService: Fetched ${chunkVideos.length} videos from ${chunk.length} authors (chunk: $chunk)');
      } catch (e) {
        log('❌ FollowingFeedService: Error fetching videos from chunk: $e');
        // Continue with next chunk instead of failing completely
      }
    }

    // Sort all videos by creation date (since we got them from multiple queries)
    allVideos.sort((a, b) {
      final aTime = a.createdAt ?? Timestamp.now();
      final bTime = b.createdAt ?? Timestamp.now();
      return bTime.compareTo(aTime);
    });

    // Return only the requested limit
    return allVideos.take(limit).toList();
  }

  /// Check if user has any connections to show Following feed
  Future<bool> hasConnections(String viewerId) async {
    try {
      final connections = await _getUserConnections(viewerId);
      return connections.any((conn) =>
          conn.followState == 'mutual' || conn.followState == 'following');
    } catch (e) {
      log('❌ FollowingFeedService: Error checking connections: $e');
      return false;
    }
  }

  /// Get count of connections for Following feed
  Future<int> getConnectionsCount(String viewerId) async {
    try {
      final connections = await _getUserConnections(viewerId);
      return connections
          .where((conn) =>
              conn.followState == 'mutual' || conn.followState == 'following')
          .length;
    } catch (e) {
      log('❌ FollowingFeedService: Error getting connections count: $e');
      return 0;
    }
  }

  /// Helper method to create Connection from Firestore document
  Connection _connectionFromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Connection(
      connectionId: doc.id,
      followState: data['followState'] ?? 'follower',
      canDM: data['canDM'] ?? false,
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  /// Helper method to create HomeVideo from Firestore document
  HomeVideo _homeVideoFromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Create the creator/user object
    final creator = User(
      id: data['creatorId'] ?? '',
      username: data['creatorUsername'] ?? '',
      displayName: data['creatorDisplayName'] ?? '',
      bio: data['creatorBio'],
      avatarURL: data['creatorProfileImageURL'] ?? data['creatorAvatarURL'],
    );

    return HomeVideo(
      id: doc.id,
      creator: creator,
      videoURL: data['videoURL'] ?? '',
      thumbnailURL: data['thumbnailURL'],
      likes: data['likesCount'] ?? 0,
      comments: data['commentsCount'] ?? 0,
      views: data['viewsCount'] ?? 0,
      caption: data['caption'] ?? data['description'] ?? '',
      isLiked: data['isLiked'] ?? false,
      isFavorited: data['isFavorited'] ?? false,
      isDraft: data['isDraft'] ?? false,
      mlScore: data['mlScore']?.toDouble() ?? 0.0,
      categoryId: data['categoryId'] ?? '',
      duration: data['duration']?.toDouble() ?? 0.0,
      createdAt: data['createdAt'] as Timestamp?,
    );
  }
}

/// Connection model for Following feed
class Connection {
  final String connectionId;
  final String followState; // 'mutual', 'following', 'follower'
  final bool canDM;
  final DateTime updatedAt;

  Connection({
    required this.connectionId,
    required this.followState,
    required this.canDM,
    required this.updatedAt,
  });
}
