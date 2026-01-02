import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/video_url_resolver.dart';
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
      print('👥 FollowingFeedService: Fetching videos for viewer $viewerId');
      log('👥 FollowingFeedService: Fetching videos for viewer $viewerId');
      final authorIds = await _collectAuthorIds(viewerId);
      print('👥 FollowingFeedService: Collected ${authorIds.length} author IDs');
      log('👥 FollowingFeedService: Collected ${authorIds.length} author IDs');
      if (authorIds.isEmpty) {
        print('👥 FollowingFeedService: No valid author IDs for viewer $viewerId');
        log('👥 FollowingFeedService: No valid author IDs for viewer $viewerId');
        return [];
      }
      print('👥 FollowingFeedService: Fetching videos for ${authorIds.length} authors');
      log('👥 FollowingFeedService: Fetching videos for ${authorIds.length} authors');
      final videos =
          await _fetchVideosFromAuthors(authorIds, limit, startAfter);
      print('👥 FollowingFeedService: Fetched ${videos.length} videos');
      log('👥 FollowingFeedService: Fetched ${videos.length} videos');
      return videos;
    } catch (e, stackTrace) {
      print('❌ FollowingFeedService: Error fetching following videos: $e');
      print('📍 Stack trace: $stackTrace');
      log('❌ FollowingFeedService: Error fetching following videos: $e');
      log('📍 Stack trace: $stackTrace');
      return [];
    }
  }

  Future<List<String>> _collectAuthorIds(String viewerId) async {
    print('👥 FollowingFeedService: Starting _collectAuthorIds for viewer $viewerId');
    log('👥 FollowingFeedService: Starting _collectAuthorIds for viewer $viewerId');
    final Set<String> rawIds = <String>{};
    try {
      print('👥 FollowingFeedService: Fetching user connections...');
      log('👥 FollowingFeedService: Fetching user connections...');
      final connections = await _getUserConnections(viewerId);
      print('👥 FollowingFeedService: Got ${connections.length} connections');
      log('👥 FollowingFeedService: Got ${connections.length} connections');
      if (connections.isNotEmpty) {
        print('👥 FollowingFeedService: Processing ${connections.length} connections');
        log('👥 FollowingFeedService: Processing ${connections.length} connections');
        for (final connection in connections) {
          final String peerId = connection.peerId.isNotEmpty
              ? connection.peerId
              : connection.connectionId;
          if ((connection.followState == 'mutual' ||
                  connection.followState == 'following') &&
              peerId.isNotEmpty) {
            rawIds.add(peerId);
            print('   - Connection ${connection.connectionId} resolved to peer $peerId');
            log('   - Connection ${connection.connectionId} resolved to peer $peerId');
          }
        }
      } else {
        print('👥 FollowingFeedService: No connections documents for $viewerId');
        log('👥 FollowingFeedService: No connections documents for $viewerId');
      }
    } catch (e, stackTrace) {
      print('❌ FollowingFeedService: Error reading connections: $e');
      print('📍 Stack trace: $stackTrace');
      log('❌ FollowingFeedService: Error reading connections: $e');
      log('📍 Stack trace: $stackTrace');
    }
    print('👥 FollowingFeedService: After connections, rawIds count: ${rawIds.length}');
    log('👥 FollowingFeedService: After connections, rawIds count: ${rawIds.length}');
    
    print('👥 FollowingFeedService: Collecting from relationships...');
    log('👥 FollowingFeedService: Collecting from relationships...');
    await _collectFromRelationships(viewerId, rawIds);
    print('👥 FollowingFeedService: After relationships, rawIds count: ${rawIds.length}');
    log('👥 FollowingFeedService: After relationships, rawIds count: ${rawIds.length}');
    
    print('👥 FollowingFeedService: Collecting from follows...');
    log('👥 FollowingFeedService: Collecting from follows...');
    await _collectFromFollows(viewerId, rawIds);
    print('👥 FollowingFeedService: After follows, rawIds count: ${rawIds.length}');
    log('👥 FollowingFeedService: After follows, rawIds count: ${rawIds.length}');
    
    rawIds.remove(viewerId);
    print('👥 FollowingFeedService: After removing viewerId, rawIds count: ${rawIds.length}');
    log('👥 FollowingFeedService: After removing viewerId, rawIds count: ${rawIds.length}');
    
    print('👥 FollowingFeedService: Filtering existing user IDs...');
    log('👥 FollowingFeedService: Filtering existing user IDs...');
    final List<String> filteredIds =
        await _filterExistingUserIds(rawIds.toList());
    print('👥 FollowingFeedService: Collected ${filteredIds.length} verified author IDs');
    log('👥 FollowingFeedService: Collected ${filteredIds.length} verified author IDs');
    if (filteredIds.length != rawIds.length) {
      print('👥 FollowingFeedService: Filtered out ${rawIds.length - filteredIds.length} invalid IDs');
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
        print('👥 FollowingFeedService: Querying videos for chunk: $chunk');
        log('👥 FollowingFeedService: Querying videos for chunk: $chunk');
        
        Query query;
        QuerySnapshot? querySnapshot;
        bool processedWithUserId = false;
        
        // 🔍 DEBUG: First check if ANY videos exist for these authors (without status filter)
        try {
          final debugQuery = _firestore
              .collection('videos')
              .where('userId', whereIn: chunk)
              .limit(5);
          final debugSnapshot = await debugQuery.get();
          print('🔍 FollowingFeedService: DEBUG - Found ${debugSnapshot.docs.length} total videos (any status) for chunk: $chunk');
          log('🔍 FollowingFeedService: DEBUG - Found ${debugSnapshot.docs.length} total videos (any status) for chunk: $chunk');
          if (debugSnapshot.docs.isNotEmpty) {
            final sampleDoc = debugSnapshot.docs.first;
            final sampleData = sampleDoc.data() as Map<String, dynamic>?;
            print('🔍 FollowingFeedService: DEBUG - Sample video status: ${sampleData?['status']}, userId: ${sampleData?['userId']}, creatorId: ${sampleData?['creatorId']}');
            log('🔍 FollowingFeedService: DEBUG - Sample video status: ${sampleData?['status']}, userId: ${sampleData?['userId']}, creatorId: ${sampleData?['creatorId']}');
          }
        } catch (e) {
          print('⚠️ FollowingFeedService: DEBUG query failed: $e');
          log('⚠️ FollowingFeedService: DEBUG query failed: $e');
        }
        
        // Try with status filter first (requires composite index)
        try {
          query = _firestore
              .collection('videos')
              .where('userId', whereIn: chunk)
              .where('status', isEqualTo: 'published')
              .orderBy('createdAt', descending: true);

          // Add pagination if needed
          if (startAfter != null && i == 0) {
            query = query.startAfterDocument(startAfter);
          }

          // Limit per chunk to avoid overwhelming the query
          query = query.limit(limit ~/ (authorIds.length / 10).ceil() + 5);

          querySnapshot = await query.get();
          print('👥 FollowingFeedService: Query (with status) returned ${querySnapshot.docs.length} documents for chunk: $chunk');
          log('👥 FollowingFeedService: Query (with status) returned ${querySnapshot.docs.length} documents for chunk: $chunk');
          
          if (querySnapshot.docs.isNotEmpty) {
            final chunkVideos = querySnapshot.docs
                .map((doc) => _homeVideoFromFirestore(doc))
                .toList();
            allVideos.addAll(chunkVideos);
            print('👥 FollowingFeedService: Fetched ${chunkVideos.length} videos from ${chunk.length} authors (chunk: $chunk) using userId field (with status filter)');
            log('👥 FollowingFeedService: Fetched ${chunkVideos.length} videos from ${chunk.length} authors (chunk: $chunk) using userId field (with status filter)');
            processedWithUserId = true;
          }
        } catch (e) {
          // If index doesn't exist, query without status filter and filter in memory
          print('⚠️ FollowingFeedService: Query with status filter failed (may need index), trying without status filter: $e');
          log('⚠️ FollowingFeedService: Query with status filter failed (may need index), trying without status filter: $e');
          
          query = _firestore
              .collection('videos')
              .where('userId', whereIn: chunk)
              .orderBy('createdAt', descending: true);

          if (startAfter != null && i == 0) {
            query = query.startAfterDocument(startAfter);
          }

          query = query.limit((limit ~/ (authorIds.length / 10).ceil() + 5) * 2); // Fetch more to filter

          querySnapshot = await query.get();
          
          // Filter by status in memory
          final filteredDocs = querySnapshot.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>?;
            return data?['status'] == 'published';
          }).toList();
          
          print('👥 FollowingFeedService: Query (without status) returned ${querySnapshot.docs.length} documents, filtered to ${filteredDocs.length} published videos');
          log('👥 FollowingFeedService: Query (without status) returned ${querySnapshot.docs.length} documents, filtered to ${filteredDocs.length} published videos');
          
          // Process filtered docs directly
          if (filteredDocs.isNotEmpty) {
            final chunkVideos = filteredDocs
                .map((doc) => _homeVideoFromFirestore(doc))
                .toList();
            allVideos.addAll(chunkVideos);
            print('👥 FollowingFeedService: Fetched ${chunkVideos.length} videos from ${chunk.length} authors (chunk: $chunk) using userId field (filtered in memory)');
            log('👥 FollowingFeedService: Fetched ${chunkVideos.length} videos from ${chunk.length} authors (chunk: $chunk) using userId field (filtered in memory)');
            processedWithUserId = true;
          }
        }

        // If no results with userId field, try creatorId field as fallback
        if (!processedWithUserId) {
          print('👥 FollowingFeedService: No videos found with userId field, trying creatorId field...');
          log('👥 FollowingFeedService: No videos found with userId field, trying creatorId field...');
          
          Query fallbackQuery;
          QuerySnapshot fallbackSnapshot;
          
          try {
            // Try with status filter first
            fallbackQuery = _firestore
                .collection('videos')
                .where('creatorId', whereIn: chunk)
                .where('status', isEqualTo: 'published')
                .orderBy('createdAt', descending: true);

            if (startAfter != null && i == 0) {
              fallbackQuery = fallbackQuery.startAfterDocument(startAfter);
            }

            fallbackQuery = fallbackQuery.limit(limit ~/ (authorIds.length / 10).ceil() + 5);
            fallbackSnapshot = await fallbackQuery.get();
            print('👥 FollowingFeedService: Fallback query (with status) returned ${fallbackSnapshot.docs.length} documents');
            log('👥 FollowingFeedService: Fallback query (with status) returned ${fallbackSnapshot.docs.length} documents');
          } catch (e) {
            // Fallback without status filter
            print('⚠️ FollowingFeedService: Fallback query with status failed, trying without: $e');
            log('⚠️ FollowingFeedService: Fallback query with status failed, trying without: $e');
            
            fallbackQuery = _firestore
                .collection('videos')
                .where('creatorId', whereIn: chunk)
                .orderBy('createdAt', descending: true);

            if (startAfter != null && i == 0) {
              fallbackQuery = fallbackQuery.startAfterDocument(startAfter);
            }

            fallbackQuery = fallbackQuery.limit((limit ~/ (authorIds.length / 10).ceil() + 5) * 2);
            fallbackSnapshot = await fallbackQuery.get();
            
            // Filter by status in memory
            final filteredFallbackDocs = fallbackSnapshot.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>?;
              return data?['status'] == 'published';
            }).toList();
            
            print('👥 FollowingFeedService: Fallback query (without status) returned ${fallbackSnapshot.docs.length} documents, filtered to ${filteredFallbackDocs.length} published videos');
            log('👥 FollowingFeedService: Fallback query (without status) returned ${fallbackSnapshot.docs.length} documents, filtered to ${filteredFallbackDocs.length} published videos');
            
            if (filteredFallbackDocs.isNotEmpty) {
              final chunkVideos = filteredFallbackDocs
                  .map((doc) => _homeVideoFromFirestore(doc))
                  .toList();
              allVideos.addAll(chunkVideos);
              print('👥 FollowingFeedService: Fetched ${chunkVideos.length} videos from ${chunk.length} authors (chunk: $chunk) using creatorId field (filtered in memory)');
              log('👥 FollowingFeedService: Fetched ${chunkVideos.length} videos from ${chunk.length} authors (chunk: $chunk) using creatorId field (filtered in memory)');
            }
            continue; // Skip to next chunk
          }

          final chunkVideos = fallbackSnapshot.docs
              .map((doc) => _homeVideoFromFirestore(doc))
              .toList();

          allVideos.addAll(chunkVideos);
          print('👥 FollowingFeedService: Fetched ${chunkVideos.length} videos from ${chunk.length} authors (chunk: $chunk) using creatorId field');
          log('👥 FollowingFeedService: Fetched ${chunkVideos.length} videos from ${chunk.length} authors (chunk: $chunk) using creatorId field');
        } else {
          final chunkVideos = querySnapshot.docs
              .map((doc) => _homeVideoFromFirestore(doc))
              .toList();

          allVideos.addAll(chunkVideos);
          print('👥 FollowingFeedService: Fetched ${chunkVideos.length} videos from ${chunk.length} authors (chunk: $chunk) using userId field');
          log('👥 FollowingFeedService: Fetched ${chunkVideos.length} videos from ${chunk.length} authors (chunk: $chunk) using userId field');
        }
      } catch (e, stackTrace) {
        print('❌ FollowingFeedService: Error fetching videos from chunk: $e');
        print('📍 Stack trace: $stackTrace');
        log('❌ FollowingFeedService: Error fetching videos from chunk: $e');
        log('📍 Stack trace: $stackTrace');
        // Continue with next chunk instead of failing completely
      }
    }

    // 🔥 DEDUPLICATE: Remove duplicate videos by videoId before sorting
    final uniqueVideos = <String, HomeVideo>{};
    for (final video in allVideos) {
      if (video.id.isNotEmpty && !uniqueVideos.containsKey(video.id)) {
        uniqueVideos[video.id] = video;
      }
    }
    final deduplicatedVideos = uniqueVideos.values.toList();
    
    print('👥 FollowingFeedService: Deduplicated ${allVideos.length} videos to ${deduplicatedVideos.length} unique videos');
    log('👥 FollowingFeedService: Deduplicated ${allVideos.length} videos to ${deduplicatedVideos.length} unique videos');

    // Sort all videos by creation date (since we got them from multiple queries)
    deduplicatedVideos.sort((a, b) {
      final aTime = a.createdAt ?? Timestamp.now();
      final bTime = b.createdAt ?? Timestamp.now();
      return bTime.compareTo(aTime);
    });

    // Return only the requested limit
    return deduplicatedVideos.take(limit).toList();
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
    final String peerId = (data['peerId'] ??
        data['userId'] ??
        data['connectionId'] ??
        doc.id) as String;
    return Connection(
      connectionId: doc.id,
      peerId: peerId,
      followState: data['followState'] ?? 'follower',
      canDM: data['canDM'] ?? false,
      updatedAt: updatedAt?.toDate(),
    );
  }

  /// Parse duration from various formats (string "M:SS", double, int) to seconds (double)
  double _parseDuration(dynamic duration) {
    try {
      if (duration == null) return 0.0;

      if (duration is double) return duration;
      if (duration is int) return duration.toDouble();

      if (duration is String) {
        // Handle duration stored as string (e.g., "120" or "2:00" or "0:13")
        if (duration.contains(':')) {
          // Parse format like "2:00" or "1:30" or "0:13"
          final parts = duration.split(':');
          if (parts.length == 2) {
            final minutes = int.tryParse(parts[0]) ?? 0;
            final secs = int.tryParse(parts[1]) ?? 0;
            return (minutes * 60 + secs).toDouble();
          }
        } else {
          // Parse as seconds string
          return double.tryParse(duration) ?? 0.0;
        }
      }

      return 0.0;
    } catch (e) {
      log('⚠️ FollowingFeedService: Error parsing duration "$duration": $e');
      return 0.0;
    }
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

    // 🔍 DEBUG: Log video URL resolution
    final resolvedUrl = resolveVideoUrl(data);
    if (resolvedUrl.isEmpty) {
      print('⚠️ FollowingFeedService: No video URL found for ${doc.id}');
      print('   Available fields: ${data.keys.toList()}');
      print('   videoUrl: ${data['videoUrl']}');
      print('   videoURL: ${data['videoURL']}');
      print('   canonicalPlaybackUrl: ${data['canonicalPlaybackUrl']}');
      print('   metadata: ${data['metadata']}');
      log('⚠️ FollowingFeedService: No video URL found for ${doc.id}');
      log('   Available fields: ${data.keys.toList()}');
    } else {
      print('✅ FollowingFeedService: Resolved video URL for ${doc.id}: ${resolvedUrl.substring(0, resolvedUrl.length > 50 ? 50 : resolvedUrl.length)}...');
      log('✅ FollowingFeedService: Resolved video URL for ${doc.id}');
    }

    return HomeVideo(
      id: doc.id,
      creator: creator,
      videoURL: resolvedUrl,
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
      duration: _parseDuration(data['metadata']?['duration'] ?? data['duration']),
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
