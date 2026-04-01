import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/video_url_resolver.dart';
import '../models/home_video.dart';
import '../models/user.dart';
import 'real_user_data_service.dart';
import 'user_blocking_service.dart';

/// Service to fetch Following feed videos from Connections list
/// This ensures Following tab pulls from NetworkView Connections data
class FollowingFeedService {
  static FollowingFeedService? _instance;
  static FollowingFeedService get instance =>
      _instance ??= FollowingFeedService._();

  FollowingFeedService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RealUserDataService _userDataService = RealUserDataService();

  /// Fetch Following videos from user's Connections list
  /// Uses the same data source as NetworkView Connections tab
  /// Returns map with 'videos' and 'lastDocument' for cursor-based pagination
  Future<Map<String, dynamic>> fetchFollowingVideos({
    required String viewerId,
    int limit = 20,
    dynamic startAfter,
  }) async {
    try {
      log('👥 FollowingFeedService: Fetching videos for viewer $viewerId');
      final authorIds = await _collectAuthorIds(viewerId);
      log('👥 FollowingFeedService: Collected ${authorIds.length} author IDs');
      if (authorIds.isEmpty) {
        log('👥 FollowingFeedService: No valid author IDs for viewer $viewerId');
        return {
          'videos': <HomeVideo>[],
          'lastDocument': null,
          'authorCount': 0,
        };
      }
      log('👥 FollowingFeedService: Fetching videos for ${authorIds.length} authors');
      final result =
          await _fetchVideosFromAuthors(authorIds, limit, startAfter);
      final videos = result['videos'] as List<HomeVideo>;
      log('👥 FollowingFeedService: Fetched ${videos.length} videos');
      return {
        ...result,
        'authorCount': authorIds.length,
      };
    } catch (e, stackTrace) {
      log('❌ FollowingFeedService: Error fetching following videos: $e');
      log('📍 Stack trace: $stackTrace');
      return {
        'videos': <HomeVideo>[],
        'lastDocument': null,
        'authorCount': 0,
      };
    }
  }

  Future<List<String>> _collectAuthorIds(String viewerId) async {
    log('👥 FollowingFeedService: Starting _collectAuthorIds for viewer $viewerId');
    final Set<String> rawIds = <String>{};
    try {
      log('👥 FollowingFeedService: Fetching user connections...');
      final connections = await _getUserConnections(viewerId);
      log('👥 FollowingFeedService: Got ${connections.length} connections');
      if (connections.isNotEmpty) {
        log('👥 FollowingFeedService: Processing ${connections.length} connections');
        for (final connection in connections) {
          final String peerId = connection.peerId.isNotEmpty
              ? connection.peerId
              : connection.connectionId;
          if (_shouldIncludeConnection(connection) && peerId.isNotEmpty) {
            rawIds.add(peerId);
            log('   - Connection ${connection.connectionId} resolved to peer $peerId');
          }
        }
      } else {
        log('👥 FollowingFeedService: No connections documents for $viewerId');
      }
    } catch (e, stackTrace) {
      log('❌ FollowingFeedService: Error reading connections: $e');
      log('📍 Stack trace: $stackTrace');
    }
    log('👥 FollowingFeedService: Using connections as single source of truth');
    rawIds.remove(viewerId);
    log('👥 FollowingFeedService: After removing viewerId, rawIds count: ${rawIds.length}');
    
    log('👥 FollowingFeedService: Filtering existing user IDs...');
    List<String> filteredIds =
        await _filterExistingUserIds(rawIds.toList());
    final blockedIds = await UserBlockingService().getBlockedUsers();
    if (blockedIds.isNotEmpty) {
      filteredIds = filteredIds.where((id) => !blockedIds.contains(id)).toList();
      log('👥 FollowingFeedService: Excluded ${blockedIds.length} blocked creators');
    }
    log('👥 FollowingFeedService: Collected ${filteredIds.length} verified author IDs');
    if (filteredIds.length != rawIds.length) {
      log('👥 FollowingFeedService: Filtered out ${rawIds.length - filteredIds.length} invalid IDs');
    }
    return filteredIds;
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
  /// Returns map with 'videos' and 'lastDocument' for pagination
  Future<Map<String, dynamic>> _fetchVideosFromAuthors(
    List<String> authorIds,
    int limit,
    dynamic startAfter,
  ) async {
    final startAfterDoc = startAfter is DocumentSnapshot
        ? startAfter
        : (startAfter is Map ? startAfter['lastDoc'] as DocumentSnapshot? : null);
    return _fetchFromFollowingFeedEntries(
      authorIds: authorIds.toSet(),
      limit: limit,
      startAfterDoc: startAfterDoc,
    );
  }

  /// Check if user has any connections to show Following feed
  Future<bool> hasConnections(String viewerId) async {
    try {
      final connections = await _getUserConnections(viewerId);
      return connections.any(_shouldIncludeConnection);
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
          .where(_shouldIncludeConnection)
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
        data['connectedUserId'] ??
        data['uid'] ??
        data['userId'] ??
        data['connectionId'] ??
        doc.id) as String;
    return Connection(
      connectionId: doc.id,
      peerId: peerId,
      followState: _normalizeFollowState(data),
      canDM: (data['canDM'] ?? data['canReceiveDMs']) ?? false,
      updatedAt: updatedAt?.toDate(),
    );
  }

  bool _shouldIncludeConnection(Connection connection) {
    return switch (connection.followState) {
      'mutual' || 'following' || 'connected' => true,
      _ => false,
    };
  }

  String _normalizeFollowState(Map<String, dynamic> data) {
    final String rawState =
        (data['followState'] ?? data['relationshipType'] ?? '').toString().trim().toLowerCase();
    if (rawState.isNotEmpty) {
      return rawState;
    }

    if (data['connectedAt'] != null ||
        data['canReceiveDMs'] != null ||
        data['canDM'] != null) {
      return 'connected';
    }

    return 'follower';
  }

  bool _isEligibleFollowingVideo(
    Map<String, dynamic> data,
    List<String> authorIds,
  ) {
    if (data['isReadyForFeed'] == false) return false;

    final String status = (data['status'] ?? '').toString().trim().toLowerCase();
    final bool isActiveStatus =
        status == 'active' || status == 'published' || status == 'ready';
    if (!isActiveStatus) return false;

    final String? ownerId = _getOwnerId(data);
    if (ownerId == null || !authorIds.contains(ownerId)) return false;

    final String visibility =
        (data['visibility'] ?? '').toString().trim().toLowerCase();
    final String privacy =
        (data['privacy'] ?? '').toString().trim().toLowerCase();

    final bool isAllowedPrivacy = visibility == 'public' ||
        visibility == 'connections' ||
        privacy == 'everyone' ||
        privacy == 'public' ||
        privacy == 'connections' ||
        (visibility.isEmpty && privacy.isEmpty);

    return isAllowedPrivacy;
  }

  String? _getOwnerId(Map<String, dynamic> data) {
    final dynamic rawOwnerId =
        data['userId'] ?? data['creatorId'] ?? data['ownerId'] ?? data['creator_id'];
    if (rawOwnerId is! String) return null;
    final String ownerId = rawOwnerId.trim();
    return ownerId.isEmpty ? null : ownerId;
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

  /// Helper method to create HomeVideo from Firestore document.
  /// Returns null if video has no playable URL (skips unplayable videos).
  Future<HomeVideo?> _homeVideoFromFirestore(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;

    // Support all field name variants for cross-platform compatibility
    final userId = _getOwnerId(data) ?? '';

    final embeddedUsername =
        (data['creatorUsername'] ?? data['username'] ?? '').toString();
    final embeddedDisplayName =
        (data['creatorDisplayName'] ?? data['displayName'] ?? '').toString();
    final embeddedAvatarUrl = (data['creatorProfileImageURL'] ??
            data['creatorAvatarURL'] ??
            data['avatarURL'])
        ?.toString();

    User creator;
    User? hydratedCreator;
    if (userId.isNotEmpty) {
      try {
        hydratedCreator = await _userDataService.getUserById(userId);
      } catch (e) {
        log('⚠️ FollowingFeedService: Failed to hydrate creator $userId: $e');
      }
    }
    if (hydratedCreator != null) {
      creator = User(
        id: hydratedCreator.id,
        username: hydratedCreator.username.isNotEmpty
            ? hydratedCreator.username
            : embeddedUsername,
        displayName: hydratedCreator.displayName.isNotEmpty
            ? hydratedCreator.displayName
            : (embeddedDisplayName.isNotEmpty
                ? embeddedDisplayName
                : hydratedCreator.username),
        bio: hydratedCreator.bio ?? data['creatorBio'] ?? data['bio'],
        avatarURL: hydratedCreator.avatarURL ?? embeddedAvatarUrl,
        hashtags: hydratedCreator.hashtags,
      );
    } else {
      creator = User(
        id: userId,
        username: embeddedUsername.isNotEmpty
            ? embeddedUsername
            : 'user_${userId.length > 10 ? userId.substring(0, 10) : userId}',
        displayName:
            embeddedDisplayName.isNotEmpty ? embeddedDisplayName : 'User',
        bio: data['creatorBio'] ?? data['bio'],
        avatarURL: embeddedAvatarUrl,
        hashtags: const [],
      );
    }

    // 🔍 DEBUG: Log video URL resolution
    final resolvedUrl = resolveVideoUrl(data);
    if (resolvedUrl.isEmpty) {
      log('⚠️ FollowingFeedService: No video URL found for ${doc.id}');
      log('   Available fields: ${data.keys.toList()}');
      log('   videoUrl: ${data['videoUrl']}');
      log('   videoURL: ${data['videoURL']}');
      log('   canonicalPlaybackUrl: ${data['canonicalPlaybackUrl']}');
      log('   metadata: ${data['metadata']}');
    } else {
      log(
        '✅ FollowingFeedService: Resolved video URL for ${doc.id}: '
        '${resolvedUrl.substring(0, resolvedUrl.length > 50 ? 50 : resolvedUrl.length)}...',
      );
    }

    if (resolvedUrl.isEmpty) {
      return null;
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

  Future<Map<String, dynamic>> _fetchFromFollowingFeedEntries({
    required Set<String> authorIds,
    required int limit,
    DocumentSnapshot? startAfterDoc,
  }) async {
    final List<HomeVideo> videos = <HomeVideo>[];
    final Map<String, DocumentSnapshot> feedEntryByVideoId =
        <String, DocumentSnapshot>{};

    try {
      Query query = _firestore
          .collection('feeds')
          .doc('following')
          .collection('videos')
          .orderBy('addedAt', descending: true)
          .limit(limit * 12);
      if (startAfterDoc != null) {
        query = query.startAfterDocument(startAfterDoc);
      }

      final entriesSnapshot = await query.get();
      final List<QueryDocumentSnapshot> matchingEntries =
          <QueryDocumentSnapshot>[];
      for (final doc in entriesSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;
        final String authorId = (data['userId'] ?? '').toString().trim();
        final String privacy =
            (data['privacy'] ?? '').toString().trim().toLowerCase();
        if (!authorIds.contains(authorId)) continue;
        if (privacy.isNotEmpty &&
            privacy != 'everyone' &&
            privacy != 'connections' &&
            privacy != 'public') {
          continue;
        }
        matchingEntries.add(doc);
      }

      final Map<String, QueryDocumentSnapshot> entryByVideoId =
          <String, QueryDocumentSnapshot>{
        for (final entry in matchingEntries)
          if (entry.id.isNotEmpty) entry.id: entry,
      };

      final List<String> videoIds = entryByVideoId.keys.toList();
      for (int i = 0; i < videoIds.length; i += 10) {
        final chunk = videoIds.skip(i).take(10).toList();
        if (chunk.isEmpty) continue;
        final videosSnapshot = await _firestore
            .collection('videos')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        for (final doc in videosSnapshot.docs) {
          final data = doc.data();
          if (!_isEligibleFollowingVideo(data, authorIds.toList())) continue;
          final video = await _homeVideoFromFirestore(doc);
          if (video == null) continue;
          videos.add(video);
          final entry = entryByVideoId[doc.id];
          if (entry != null) {
            feedEntryByVideoId[doc.id] = entry;
          }
        }
      }

      videos.sort((a, b) {
        final aTime = a.createdAt ?? Timestamp.now();
        final bTime = b.createdAt ?? Timestamp.now();
        return bTime.compareTo(aTime);
      });

      final result = videos.take(limit).toList();
      final lastDoc =
          result.isNotEmpty ? feedEntryByVideoId[result.last.id] : null;
      return {
        'videos': result,
        'lastDocument': lastDoc,
      };
    } catch (e, stackTrace) {
      log('❌ FollowingFeedService: Feed-entry fetch failed: $e');
      log('📍 Stack trace: $stackTrace');
      return {
        'videos': <HomeVideo>[],
        'lastDocument': null,
      };
    }
  }
}

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
