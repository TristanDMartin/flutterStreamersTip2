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
      final authorIds = await _collectAuthorIds(viewerId);
      if (authorIds.isEmpty) {
        log('👥 FollowingFeedService: No valid author IDs for viewer $viewerId');
        return [];
      }
      log('👥 FollowingFeedService: Fetching videos for ${authorIds.length} authors');
      final videos = await _fetchVideosFromAuthors(authorIds, limit, startAfter);
      log('👥 FollowingFeedService: Fetched ${videos.length} videos');
      return videos;
    } catch (e) {
      log('❌ FollowingFeedService: Error fetching following videos: $e');
      return [];
    }
  }

  Future<List<String>> _collectAuthorIds(String viewerId) async {
    final Set<String> rawIds = <String>{};
    try {
      final connections = await _getUserConnections(viewerId);
      if (connections.isNotEmpty) {
        log('👥 FollowingFeedService: Processing ${connections.length} connections');
        for (final connection in connections) {
          final String peerId = connection.peerId.isNotEmpty
              ? connection.peerId
              : connection.connectionId;
          if ((connection.followState == 'mutual' ||
                  connection.followState == 'following') &&
              peerId.isNotEmpty) {
            rawIds.add(peerId);
            log('   - Connection ${connection.connectionId} resolved to peer $peerId');
          }
        }
      } else {
        log('👥 FollowingFeedService: No connections documents for $viewerId');
      }
    } catch (e) {
      log('❌ FollowingFeedService: Error reading connections: $e');
    }
    await _collectFromRelationships(viewerId, rawIds);
    await _collectFromFollows(viewerId, rawIds);
    rawIds.remove(viewerId);
    final List<String> filteredIds =
        await _filterExistingUserIds(rawIds.toList());
    log('👥 FollowingFeedService: Collected ${filteredIds.length} verified author IDs');
    if (filteredIds.length != rawIds.length) {
      log('👥 FollowingFeedService: Filtered out ${rawIds.length - filteredIds.length} invalid IDs');
    }
    return filteredIds;
  }

  Future<void> _collectFromRelationships(
      String viewerId, Set<String> rawIds) async {
    try {
      final querySnapshot = await _firestore
          .collection('relationships')
          .where('followerId', isEqualTo: viewerId)
          .get();
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final String followingId = data['followingId'] ?? '';
        if (followingId.isNotEmpty) {
          rawIds.add(followingId);
          log('   - Relationship ${doc.id} -> $followingId');
        }
      }
    } catch (e) {
      log('❌ FollowingFeedService: Error collecting relationships: $e');
    }
  }

  Future<void> _collectFromFollows(String viewerId, Set<String> rawIds) async {
    try {
      final querySnapshot = await _firestore
          .collection('follows')
          .where('followerId', isEqualTo: viewerId)
          .get();
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final String followedId = data['followedId'] ?? '';
        if (followedId.isNotEmpty) {
          rawIds.add(followedId);
          log('   - Follows ${doc.id} -> $followedId');
        }
      }
    } catch (e) {
      log('❌ FollowingFeedService: Error collecting follows: $e');
    }
  }

  Future<List<String>> _filterExistingUserIds(List<String> ids) async {
    final Set<String> validIds = <String>{};
    final List<String> cleaned = ids
        .where((id) => id.isNotEmpty)
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList();
    for (int i = 0; i < cleaned.length; i += 10) {
      final chunk = cleaned.skip(i).take(10).toList();
      try {
        final snapshot = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final doc in snapshot.docs) {
          validIds.add(doc.id);
        }
      } catch (e) {
        log('❌ FollowingFeedService: Error validating user IDs chunk: $e');
      }
    }
    return validIds.toList();
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
          .where((connection) => connection.peerId.isNotEmpty)
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
        // Query by userId field (primary field used by mobile app)
        log('👥 FollowingFeedService: Querying videos for chunk: $chunk');
        Query query = _firestore
            .collection('videos')
            .where('userId', whereIn: chunk)
            .orderBy('createdAt', descending: true);

        // Add pagination if needed
        if (startAfter != null && i == 0) {
          query = query.startAfterDocument(startAfter);
        }

        // Limit per chunk to avoid overwhelming the query
        query = query.limit(limit ~/ (authorIds.length / 10).ceil() + 5);

        final querySnapshot = await query.get();

        log('👥 FollowingFeedService: Query returned ${querySnapshot.docs.length} documents for chunk: $chunk');

        // If no results with userId field, try creatorId field as fallback
        if (querySnapshot.docs.isEmpty) {
          log('👥 FollowingFeedService: No videos found with userId field, trying creatorId field...');
          final fallbackQuery = _firestore
              .collection('videos')
              .where('creatorId', whereIn: chunk)
              .orderBy('createdAt', descending: true);

          if (startAfter != null && i == 0) {
            query = fallbackQuery.startAfterDocument(startAfter);
          } else {
            query = fallbackQuery;
          }

          final fallbackSnapshot = await query.get();
          log('👥 FollowingFeedService: Fallback query returned ${fallbackSnapshot.docs.length} documents');

          final chunkVideos = fallbackSnapshot.docs
              .map((doc) => _homeVideoFromFirestore(doc))
              .toList();

          allVideos.addAll(chunkVideos);
          log('👥 FollowingFeedService: Fetched ${chunkVideos.length} videos from ${chunk.length} authors (chunk: $chunk) using creatorId field');
        } else {
          final chunkVideos = querySnapshot.docs
              .map((doc) => _homeVideoFromFirestore(doc))
              .toList();

          allVideos.addAll(chunkVideos);
          log('👥 FollowingFeedService: Fetched ${chunkVideos.length} videos from ${chunk.length} authors (chunk: $chunk) using userId field');
        }
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
    final Timestamp? updatedAt = data['updatedAt'] as Timestamp?;
    final String peerId = (data['peerId'] ?? data['userId'] ?? data['connectionId'] ?? doc.id) as String;
    return Connection(
      connectionId: doc.id,
      peerId: peerId,
      followState: data['followState'] ?? 'follower',
      canDM: data['canDM'] ?? false,
      updatedAt: updatedAt?.toDate(),
    );
  }

  /// Helper method to create HomeVideo from Firestore document
  HomeVideo _homeVideoFromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Support all field name variants for cross-platform compatibility
    final userId = (data['userId'] ?? data['creatorId'] ?? data['creator_id'])
            as String? ??
        '';

    // Create the creator/user object
    final creator = User(
      id: userId,
      username: data['creatorUsername'] ?? data['username'] ?? '',
      displayName: data['creatorDisplayName'] ?? data['displayName'] ?? '',
      bio: data['creatorBio'] ?? data['bio'],
      avatarURL: data['creatorProfileImageURL'] ??
          data['creatorAvatarURL'] ??
          data['avatarURL'],
    );

    return HomeVideo(
      id: doc.id,
      creator: creator,
      videoURL: data['videoUrl'] ?? data['videoURL'] ?? '',
      thumbnailURL: data['thumbnailUrl'] ?? data['thumbnailURL'],
      likes: data['likes'] ?? data['likesCount'] ?? 0,
      comments: data['comments'] ?? data['commentsCount'] ?? 0,
      views: data['views'] ?? data['viewsCount'] ?? 0,
      caption: data['caption'] ?? data['description'] ?? '',
      isLiked: data['isLiked'] ?? false,
      isFavorited: data['isFavorited'] ?? false,
      isDraft: data['isDraft'] ?? false,
      mlScore: data['mlScore']?.toDouble() ?? 0.0,
      categoryId: data['categoryId'] ?? data['category'] ?? '',
      duration: data['duration']?.toDouble() ?? 0.0,
      createdAt: data['createdAt'] as Timestamp?,
    );
  }
}

/// Connection model for Following feed
class Connection {
  final String connectionId;
  final String peerId;
  final String followState; // 'mutual', 'following', 'follower'
  final bool canDM;
  final DateTime? updatedAt;

  Connection({
    required this.connectionId,
    required this.peerId,
    required this.followState,
    required this.canDM,
    required this.updatedAt,
  });
}
