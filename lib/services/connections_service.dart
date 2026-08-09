import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../features/messaging/data/messaging_repository.dart';
import '../models/connection_lite.dart';
import 'progression_service.dart';
import 'public_profile_firestore.dart';
import 'package:streamers_tip/utils/secure_log.dart';

/// ConnectionsService - Handles fetching and caching user connections
///
/// Provides optimized connection data for share sheet with server-side ranking
class ConnectionsService {
  static final ConnectionsService _instance = ConnectionsService._internal();
  factory ConnectionsService() => _instance;
  ConnectionsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Cache for connections preview (keyed by userId)
  final Map<String, List<ConnectionLite>> _connectionsCache = {};
  final Map<String, int> _connectionsTotalCache = {};
  final Map<String, DateTime> _cacheTimestamp = {};

  /// Get connections preview for share sheet (top 12 ranked connections)
  Future<List<ConnectionLite>> getConnectionsPreview({
    int limit = 12,
    bool forceRefresh = false,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      secureLog('❌ ConnectionsService: No authenticated user');
      return [];
    }

    final userId = currentUser.uid;

    // Check cache first (valid for 5 minutes)
    if (!forceRefresh && _connectionsCache.containsKey(userId)) {
      final cacheTime = _cacheTimestamp[userId];
      if (cacheTime != null &&
          DateTime.now().difference(cacheTime).inMinutes < 5) {
        secureLog('✅ ConnectionsService: Using cached connections for $userId');
        return _connectionsCache[userId] ?? [];
      }
    }

    try {
      secureLog('🔄 ConnectionsService: Fetching connections for $userId');

      // Fetch connections from Firestore with ranking
      final connections = await _fetchConnectionsWithRanking(userId, limit);

      // Cache the results
      _connectionsCache[userId] = connections;
      _cacheTimestamp[userId] = DateTime.now();

      secureLog(
          '✅ ConnectionsService: Loaded ${connections.length} connections for $userId');
      return connections;
    } catch (e) {
      secureLog('❌ ConnectionsService: Error fetching connections: $e');
      // Return cached data if available, even if stale
      return _connectionsCache[userId] ?? [];
    }
  }

  /// Get total connections count from ALL sources
  Future<int> getConnectionsTotal({bool forceRefresh = false}) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return 0;

    final userId = currentUser.uid;

    // Check cache
    if (!forceRefresh && _connectionsTotalCache.containsKey(userId)) {
      return _connectionsTotalCache[userId] ?? 0;
    }

    try {
      secureLog(
          '📊 ConnectionsService: Counting total connections from all sources for $userId');

      int total = 0;
      final Set<String> uniqueUserIds = {}; // Prevent duplicates

      // 1. Count connections from subcollection
      try {
        final connectionsSnapshot = await _firestore
            .collection('users')
            .doc(userId)
            .collection('connections')
            .get();

        for (final doc in connectionsSnapshot.docs) {
          final connectionData = doc.data();
          final connectedUserId = connectionData['userId'] ?? doc.id;
          if (connectedUserId.isNotEmpty) {
            uniqueUserIds.add(connectedUserId);
          }
        }

        secureLog(
            '📊 ConnectionsService: Found ${uniqueUserIds.length} connections from subcollection');
      } catch (e) {
        secureLog(
            '⚠️ ConnectionsService: Error counting from subcollection: $e');
      }

      // 2. Count connections from relationships (following)
      try {
        final followingQuery = await _firestore
            .collection('relationships')
            .where('followerId', isEqualTo: userId)
            .get();

        for (final doc in followingQuery.docs) {
          final relationshipData = doc.data();
          final connectedUserId = relationshipData['followingId'] ?? '';
          if (connectedUserId.isNotEmpty) {
            uniqueUserIds.add(connectedUserId);
          }
        }

        secureLog(
            '📊 ConnectionsService: Found additional connections from relationships (following)');
      } catch (e) {
        secureLog(
            '⚠️ ConnectionsService: Error counting from relationships (following): $e');
      }

      // 3. Count mutual connections (followers)
      try {
        final followersQuery = await _firestore
            .collection('relationships')
            .where('followingId', isEqualTo: userId)
            .get();

        for (final doc in followersQuery.docs) {
          final relationshipData = doc.data();
          final connectedUserId = relationshipData['followerId'] ?? '';
          if (connectedUserId.isNotEmpty) {
            uniqueUserIds.add(connectedUserId);
          }
        }

        secureLog(
            '📊 ConnectionsService: Found mutual connections from relationships (followers)');
      } catch (e) {
        secureLog(
            '⚠️ ConnectionsService: Error counting from relationships (followers): $e');
      }

      total = uniqueUserIds.length;
      _connectionsTotalCache[userId] = total;

      secureLog(
          '📊 ConnectionsService: Total unique connections for $userId: $total');
      return total;
    } catch (e) {
      secureLog('❌ ConnectionsService: Error counting connections: $e');
      return _connectionsTotalCache[userId] ?? 0;
    }
  }

  /// Search connections with typeahead
  Future<List<ConnectionLite>> searchConnections({
    required String query,
    int limit = 20,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return [];

    if (query.trim().isEmpty) {
      // Return top connections if no query
      return getConnectionsPreview(limit: limit);
    }

    try {
      secureLog(
          '🔍 ConnectionsService: Searching connections with query: "$query"');

      final connections = <ConnectionLite>[];
      final Set<String> processedUserIds = {}; // Prevent duplicates
      final String lowerQuery = query.toLowerCase();

      // 1. Search in connections subcollection
      try {
        final snapshot = await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .collection('connections')
            .limit(50)
            .get();

        for (final doc in snapshot.docs) {
          final connectionData = doc.data();
          final connectedUserId = connectionData['userId'] ?? doc.id;

          if (processedUserIds.contains(connectedUserId)) {
            continue;
          }
          processedUserIds.add(connectedUserId);

          // Get user details from connection data
          String handle = connectionData['username'] ?? '';
          String displayName =
              connectionData['displayName'] ?? connectionData['name'] ?? handle;
          String avatarUrl =
              connectionData['avatarURL'] ?? connectionData['avatarURL'] ?? '';
          bool isOnline = connectionData['isOnline'] ??
              connectionData['onlineStatus'] == 'online';

          // If connection data is incomplete, fetch public profile
          if (handle.isEmpty || displayName.isEmpty || avatarUrl.isEmpty) {
            final userData = await PublicProfileFirestore.instance
                .getProfileMap(connectedUserId);

            if (userData != null) {
              handle = handle.isEmpty ? (userData['username'] ?? '') : handle;
              displayName = displayName.isEmpty
                  ? (userData['displayName'] ?? userData['name'] ?? handle)
                  : displayName;
              avatarUrl =
                  avatarUrl.isEmpty ? (userData['avatarURL'] ?? '') : avatarUrl;
              isOnline = userData['isOnline'] ?? false;

              secureLog(
                  '🔍 ConnectionsService: Fetched user data for $connectedUserId - handle: $handle, avatarUrl: $avatarUrl');
            } else {
              secureLog(
                  '⚠️ ConnectionsService: User document not found for $connectedUserId');
            }
          }

          // Client-side filtering
          if (handle.toLowerCase().contains(lowerQuery) ||
              displayName.toLowerCase().contains(lowerQuery)) {
            connections.add(ConnectionLite(
              userId: connectedUserId,
              handle: handle,
              displayName: displayName,
              avatarUrl: avatarUrl,
              isOnline: isOnline,
              canDM: connectionData['canReceiveDMs'] ?? true,
              lastInteractedAt:
                  connectionData['lastInteraction']?.millisecondsSinceEpoch ??
                      connectionData['lastSeen']?.millisecondsSinceEpoch,
              rankingScore: _calculateRankingScore(connectionData, {}),
            ));
          }
        }
      } catch (e) {
        secureLog('⚠️ ConnectionsService: Error searching subcollection: $e');
      }

      // 2. Search in relationships (following)
      try {
        final followingQuery = await _firestore
            .collection('relationships')
            .where('followerId', isEqualTo: currentUser.uid)
            .limit(50)
            .get();

        for (final doc in followingQuery.docs) {
          final relationshipData = doc.data();
          final connectedUserId = relationshipData['followingId'] ?? '';

          if (processedUserIds.contains(connectedUserId) ||
              connectedUserId.isEmpty) {
            continue;
          }
          processedUserIds.add(connectedUserId);

          // Get user details from relationship data
          String handle = relationshipData['username'] ?? '';
          String displayName = relationshipData['displayName'] ??
              relationshipData['name'] ??
              handle;
          String avatarUrl = relationshipData['avatarURL'] ??
              relationshipData['avatarURL'] ??
              '';

          // If relationship data is incomplete, fetch public profile
          if (handle.isEmpty || displayName.isEmpty) {
            final userData = await PublicProfileFirestore.instance
                .getProfileMap(connectedUserId);

            if (userData != null) {
              handle = handle.isEmpty ? (userData['username'] ?? '') : handle;
              displayName = displayName.isEmpty
                  ? (userData['displayName'] ?? userData['name'] ?? handle)
                  : displayName;
              avatarUrl =
                  avatarUrl.isEmpty ? (userData['avatarURL'] ?? '') : avatarUrl;
            }
          }

          // Client-side filtering
          if (handle.toLowerCase().contains(lowerQuery) ||
              displayName.toLowerCase().contains(lowerQuery)) {
            connections.add(ConnectionLite(
              userId: connectedUserId,
              handle: handle,
              displayName: displayName,
              avatarUrl: avatarUrl,
              isOnline: false,
              canDM: relationshipData['canDM'] ?? true,
              lastInteractedAt:
                  relationshipData['timestamp']?.millisecondsSinceEpoch,
              rankingScore: _calculateRankingScore(relationshipData, {}),
            ));
          }
        }
      } catch (e) {
        secureLog(
            '⚠️ ConnectionsService: Error searching relationships (following): $e');
      }

      // 3. Search in mutual connections (followers)
      try {
        final followersQuery = await _firestore
            .collection('relationships')
            .where('followingId', isEqualTo: currentUser.uid)
            .limit(50)
            .get();

        for (final doc in followersQuery.docs) {
          final relationshipData = doc.data();
          final connectedUserId = relationshipData['followerId'] ?? '';

          if (processedUserIds.contains(connectedUserId) ||
              connectedUserId.isEmpty) {
            continue;
          }
          processedUserIds.add(connectedUserId);

          // Get user details from relationship data
          String handle = relationshipData['username'] ?? '';
          String displayName = relationshipData['displayName'] ??
              relationshipData['name'] ??
              handle;
          String avatarUrl = relationshipData['avatarURL'] ??
              relationshipData['avatarURL'] ??
              '';

          // If relationship data is incomplete, fetch public profile
          if (handle.isEmpty || displayName.isEmpty) {
            final userData = await PublicProfileFirestore.instance
                .getProfileMap(connectedUserId);

            if (userData != null) {
              handle = handle.isEmpty ? (userData['username'] ?? '') : handle;
              displayName = displayName.isEmpty
                  ? (userData['displayName'] ?? userData['name'] ?? handle)
                  : displayName;
              avatarUrl =
                  avatarUrl.isEmpty ? (userData['avatarURL'] ?? '') : avatarUrl;
            }
          }

          // Client-side filtering
          if (handle.toLowerCase().contains(lowerQuery) ||
              displayName.toLowerCase().contains(lowerQuery)) {
            connections.add(ConnectionLite(
              userId: connectedUserId,
              handle: handle,
              displayName: displayName,
              avatarUrl: avatarUrl,
              isOnline: false,
              canDM: relationshipData['canDM'] ?? true,
              lastInteractedAt:
                  relationshipData['timestamp']?.millisecondsSinceEpoch,
              rankingScore: _calculateRankingScore(relationshipData, {}) +
                  5.0, // Boost for mutual connections
            ));
          }
        }
      } catch (e) {
        secureLog(
            '⚠️ ConnectionsService: Error searching relationships (followers): $e');
      }

      // Sort by ranking score for search results
      connections.sort((a, b) => b.rankingScore.compareTo(a.rankingScore));

      secureLog(
          '🔍 ConnectionsService: Found ${connections.length} matching connections from all sources');
      return connections.take(limit).toList();
    } catch (e) {
      secureLog('❌ ConnectionsService: Error searching connections: $e');
      return [];
    }
  }

  /// Send DM share to connection
  Future<String?> shareToConnection({
    required String recipientId,
    required String videoId,
    required String shareToken,
  }) async {
    try {
      secureLog(
          '📤 ConnectionsService: Sending DM share to $recipientId for video $videoId');

      String videoTitle = 'Shared a video';
      String videoThumbnailUrl = '';
      String creatorUsername = '';
      Map<String, dynamic> videoData = <String, dynamic>{};

      try {
        final DocumentSnapshot<Map<String, dynamic>> videoDoc =
            await _firestore.collection('videos').doc(videoId).get();
        if (videoDoc.exists) {
          videoData = videoDoc.data() ?? <String, dynamic>{};
          videoTitle = videoData['caption'] as String? ??
              videoData['title'] as String? ??
              'Shared a video';
          videoThumbnailUrl = videoData['thumbnailUrl'] as String? ?? '';
          creatorUsername = (videoData['username'] as String?)?.trim() ??
              (videoData['creatorUsername'] as String?)?.trim() ??
              (videoData['displayName'] as String?)?.trim() ??
              '';
          secureLog(
              '📤 ConnectionsService: Fetched video data - title: "$videoTitle", thumbnail: "$videoThumbnailUrl"');
        } else {
          secureLog(
              '⚠️ ConnectionsService: Video document does not exist: $videoId');
        }
      } catch (e) {
        secureLog('⚠️ ConnectionsService: Could not fetch video data: $e');
      }

      final String publicUrl = 'https://streamerstip.com/video/$videoId';
      final String deepLink = 'streamerstip://video/$videoId';

      final messageData = <String, dynamic>{
        'type': 'video_share',
        'messageType': 'video_share',
        'from': _auth.currentUser!.uid,
        'senderId': _auth.currentUser!.uid,
        'to': recipientId,
        'recipientId': recipientId,
        'videoId': videoId,
        'shareToken': shareToken,
        'videoTitle': videoTitle,
        'videoThumbnailUrl': videoThumbnailUrl,
        'publicUrl': publicUrl,
        'deepLink': deepLink,
        'creatorUsername': creatorUsername,
        'text': 'Shared a video',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'isRead': false,
        'readBy': <String>[_auth.currentUser!.uid],
      };

      final String chatId = await _findOrCreateChat(recipientId);

      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add(messageData);

      try {
        await _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .collection('connections')
            .doc(recipientId)
            .set(<String, dynamic>{
          'userId': recipientId,
          'lastInteraction': FieldValue.serverTimestamp(),
          'lastSeen': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        secureLog('⚠️ ConnectionsService: Non-fatal connection bump: $e');
      }

      try {
        await _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .collection('recentShares')
            .add(<String, dynamic>{
          'recipientId': recipientId,
          'videoId': videoId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        secureLog('⚠️ ConnectionsService: recentShares write skipped: $e');
      }

      secureLog(
          '✅ ConnectionsService: DM share sent successfully to chat $chatId');
      unawaited(ProgressionService.instance.markTaskCompleted(
        _auth.currentUser!.uid,
        ProgressionTaskIds.firstMessageSent,
        source: 'messages',
      ));
      return chatId;
    } catch (e) {
      secureLog('❌ ConnectionsService: Error sending DM share: $e');
      rethrow;
    }
  }

  /// Send batch DM shares to multiple connections
  Future<List<String?>> shareToConnections({
    required List<String> recipientIds,
    required String videoId,
    required String shareToken,
  }) async {
    final results = <String?>[];

    for (final recipientId in recipientIds) {
      try {
        final chatId = await shareToConnection(
          recipientId: recipientId,
          videoId: videoId,
          shareToken: shareToken,
        );
        results.add(chatId);
      } catch (e) {
        secureLog('❌ ConnectionsService: Failed to share to $recipientId: $e');
        results.add(null);
      }
    }

    return results;
  }

  /// Clear cache for current user
  void clearCache() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final userId = currentUser.uid;
    _connectionsCache.remove(userId);
    _connectionsTotalCache.remove(userId);
    _cacheTimestamp.remove(userId);

    secureLog('🗑️ ConnectionsService: Cleared cache for $userId');
  }

  /// Fetch connections with server-side ranking from ALL sources
  Future<List<ConnectionLite>> _fetchConnectionsWithRanking(
      String userId, int limit) async {
    try {
      secureLog(
          '🔄 ConnectionsService: Fetching ALL connections for $userId from multiple sources');

      final connections = <ConnectionLite>[];
      final Set<String> processedUserIds = {}; // Prevent duplicates
      final Set<String> recentShareUserIds = <String>{};
      try {
        final QuerySnapshot<Map<String, dynamic>> recentSnap = await _firestore
            .collection('users')
            .doc(userId)
            .collection('recentShares')
            .limit(24)
            .get();
        for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
            in recentSnap.docs) {
          final Map<String, dynamic> m = doc.data();
          final String? peer = (m['recipientId'] ??
              m['userId'] ??
              m['toUserId'] ??
              m['peerUserId'] ??
              m['targetUserId']) as String?;
          if (peer != null && peer.isNotEmpty) {
            recentShareUserIds.add(peer);
          }
        }
      } catch (e) {
        secureLog('⚠️ ConnectionsService: recentShares unavailable: $e');
      }

      // 1. Get connections from connections subcollection (app-created)
      try {
        final connectionsSnapshot = await _firestore
            .collection('users')
            .doc(userId)
            .collection('connections')
            .limit(limit * 2)
            .get();

        for (final doc in connectionsSnapshot.docs) {
          final connectionData = doc.data();
          final connectedUserId = connectionData['userId'] ?? doc.id;

          if (processedUserIds.contains(connectedUserId)) {
            continue;
          }
          processedUserIds.add(connectedUserId);

          // Try to get user details from connection data first
          String handle = connectionData['username'] ?? '';
          String displayName =
              connectionData['displayName'] ?? connectionData['name'] ?? handle;
          String avatarUrl =
              connectionData['avatarURL'] ?? connectionData['avatarURL'] ?? '';
          bool isOnline = connectionData['isOnline'] ??
              connectionData['onlineStatus'] == 'online';

          secureLog(
              '🔍 ConnectionsService: Connection data for $connectedUserId - handle: $handle, avatarUrl: $avatarUrl');
          secureLog(
              '🔍 ConnectionsService: Raw connection data: ${connectionData.keys.toList()}');

          // If connection data is incomplete, fetch public profile
          if (handle.isEmpty || displayName.isEmpty || avatarUrl.isEmpty) {
            final userData = await PublicProfileFirestore.instance
                .getProfileMap(connectedUserId);

            if (userData != null) {
              handle = handle.isEmpty ? (userData['username'] ?? '') : handle;
              displayName = displayName.isEmpty
                  ? (userData['displayName'] ?? userData['name'] ?? handle)
                  : displayName;
              avatarUrl =
                  avatarUrl.isEmpty ? (userData['avatarURL'] ?? '') : avatarUrl;
              isOnline = userData['isOnline'] ?? false;

              secureLog(
                  '🔍 ConnectionsService: Fetched user data for $connectedUserId - handle: $handle, avatarUrl: $avatarUrl');
            } else {
              secureLog(
                  '⚠️ ConnectionsService: User document not found for $connectedUserId');
            }
          }

          if (handle.isNotEmpty) {
            // If still no avatar URL, try to construct a default one
            if (avatarUrl.isEmpty) {
              avatarUrl =
                  'https://via.placeholder.com/120x120/4ECDC4/FFFFFF?text=${handle.substring(0, 1).toUpperCase()}';
              secureLog(
                  '🔍 ConnectionsService: Using placeholder avatar for $handle: $avatarUrl');
            }

            connections.add(ConnectionLite(
              userId: connectedUserId,
              handle: handle,
              displayName: displayName,
              avatarUrl: avatarUrl,
              isOnline: isOnline,
              canDM: connectionData['canReceiveDMs'] ?? true,
              lastInteractedAt:
                  connectionData['lastInteraction']?.millisecondsSinceEpoch ??
                      connectionData['lastSeen']?.millisecondsSinceEpoch,
              rankingScore: _calculateRankingScore(connectionData, {}),
            ));
          }
        }

        secureLog(
            '✅ ConnectionsService: Found ${connections.length} connections from subcollection');
      } catch (e) {
        secureLog(
            '⚠️ ConnectionsService: Error fetching from connections subcollection: $e');
      }

      // 2. Get connections from relationships collection (website-created)
      try {
        final followingQuery = await _firestore
            .collection('relationships')
            .where('followerId', isEqualTo: userId)
            .limit(limit * 2)
            .get();

        for (final doc in followingQuery.docs) {
          final relationshipData = doc.data();
          final connectedUserId = relationshipData['followingId'] ?? '';

          if (processedUserIds.contains(connectedUserId) ||
              connectedUserId.isEmpty) {
            continue;
          }
          processedUserIds.add(connectedUserId);

          // Get user details from relationship data
          String handle = relationshipData['username'] ?? '';
          String displayName = relationshipData['displayName'] ??
              relationshipData['name'] ??
              handle;
          String avatarUrl = relationshipData['avatarURL'] ??
              relationshipData['avatarURL'] ??
              '';

          // If relationship data is incomplete, fetch public profile
          if (handle.isEmpty || displayName.isEmpty) {
            final userData = await PublicProfileFirestore.instance
                .getProfileMap(connectedUserId);

            if (userData != null) {
              handle = handle.isEmpty ? (userData['username'] ?? '') : handle;
              displayName = displayName.isEmpty
                  ? (userData['displayName'] ?? userData['name'] ?? handle)
                  : displayName;
              avatarUrl =
                  avatarUrl.isEmpty ? (userData['avatarURL'] ?? '') : avatarUrl;
            }
          }

          if (handle.isNotEmpty) {
            // If still no avatar URL, try to construct a default one
            if (avatarUrl.isEmpty) {
              avatarUrl =
                  'https://via.placeholder.com/120x120/4ECDC4/FFFFFF?text=${handle.substring(0, 1).toUpperCase()}';
              secureLog(
                  '🔍 ConnectionsService: Using placeholder avatar for $handle: $avatarUrl');
            }

            connections.add(ConnectionLite(
              userId: connectedUserId,
              handle: handle,
              displayName: displayName,
              avatarUrl: avatarUrl,
              isOnline: false, // Default to offline for relationships
              canDM: relationshipData['canDM'] ?? true,
              lastInteractedAt:
                  relationshipData['timestamp']?.millisecondsSinceEpoch,
              rankingScore: _calculateRankingScore(relationshipData, {}),
            ));
          }
        }

        secureLog(
            '✅ ConnectionsService: Found additional connections from relationships collection');
      } catch (e) {
        secureLog(
            '⚠️ ConnectionsService: Error fetching from relationships collection: $e');
      }

      // 3. Get mutual connections (both following each other)
      try {
        final followersQuery = await _firestore
            .collection('relationships')
            .where('followingId', isEqualTo: userId)
            .limit(limit * 2)
            .get();

        for (final doc in followersQuery.docs) {
          final relationshipData = doc.data();
          final connectedUserId = relationshipData['followerId'] ?? '';

          if (processedUserIds.contains(connectedUserId) ||
              connectedUserId.isEmpty) {
            continue;
          }
          processedUserIds.add(connectedUserId);

          // Get user details from relationship data
          String handle = relationshipData['username'] ?? '';
          String displayName = relationshipData['displayName'] ??
              relationshipData['name'] ??
              handle;
          String avatarUrl = relationshipData['avatarURL'] ??
              relationshipData['avatarURL'] ??
              '';

          // If relationship data is incomplete, fetch public profile
          if (handle.isEmpty || displayName.isEmpty) {
            final userData = await PublicProfileFirestore.instance
                .getProfileMap(connectedUserId);

            if (userData != null) {
              handle = handle.isEmpty ? (userData['username'] ?? '') : handle;
              displayName = displayName.isEmpty
                  ? (userData['displayName'] ?? userData['name'] ?? handle)
                  : displayName;
              avatarUrl =
                  avatarUrl.isEmpty ? (userData['avatarURL'] ?? '') : avatarUrl;
            }
          }

          if (handle.isNotEmpty) {
            // If still no avatar URL, try to construct a default one
            if (avatarUrl.isEmpty) {
              avatarUrl =
                  'https://via.placeholder.com/120x120/4ECDC4/FFFFFF?text=${handle.substring(0, 1).toUpperCase()}';
              secureLog(
                  '🔍 ConnectionsService: Using placeholder avatar for $handle: $avatarUrl');
            }

            connections.add(ConnectionLite(
              userId: connectedUserId,
              handle: handle,
              displayName: displayName,
              avatarUrl: avatarUrl,
              isOnline: false, // Default to offline for relationships
              canDM: relationshipData['canDM'] ?? true,
              lastInteractedAt:
                  relationshipData['timestamp']?.millisecondsSinceEpoch,
              rankingScore: _calculateRankingScore(relationshipData, {}) +
                  5.0, // Boost for mutual connections
            ));
          }
        }

        secureLog(
            '✅ ConnectionsService: Found mutual connections from followers');
      } catch (e) {
        secureLog(
            '⚠️ ConnectionsService: Error fetching mutual connections: $e');
      }

      final List<ConnectionLite> ranked = connections
          .map(
            (ConnectionLite c) => recentShareUserIds.contains(c.userId)
                ? c.copyWith(rankingScore: c.rankingScore + 40.0)
                : c,
          )
          .toList();
      ranked.sort(
        (ConnectionLite a, ConnectionLite b) =>
            b.rankingScore.compareTo(a.rankingScore),
      );

      secureLog(
          '🎯 ConnectionsService: Total connections found: ${ranked.length}');
      return ranked.take(limit).toList();
    } catch (e) {
      secureLog(
          '❌ ConnectionsService: Error fetching connections with ranking: $e');
      return [];
    }
  }

  /// Calculate ranking score for connections
  double _calculateRankingScore(
      Map<String, dynamic> connectionData, Map<String, dynamic> userData) {
    double score = 0.0;

    // Recent interaction boost (highest weight)
    final lastInteracted =
        connectionData['lastInteraction'] ?? connectionData['lastSeen'];
    if (lastInteracted != null) {
      final daysSince =
          DateTime.now().difference(lastInteracted.toDate()).inDays;
      score += (30 - daysSince).clamp(0, 30) * 2.0; // Max 60 points
    }

    // Online presence boost
    if (connectionData['isOnline'] == true ||
        connectionData['onlineStatus'] == 'online') {
      score += 10.0;
    }

    // Verified/creator boost
    if (connectionData['isVerified'] == true ||
        connectionData['verified'] == true) {
      score += 5.0;
    }

    // Mutual engagement boost (likes, comments, etc.)
    final mutualEngagement = connectionData['mutualEngagement'] ??
        connectionData['interactionCount'] ??
        0;
    score += (mutualEngagement * 0.5).clamp(0, 20);

    // Connection strength boost (if available)
    final connectionStrength = connectionData['connectionStrength'] ?? 0.0;
    score += connectionStrength * 10;

    return score;
  }

  /// Find or create chat between two users (deterministic DM ID).
  Future<String> _findOrCreateChat(String otherUserId) async {
    final currentUserId = _auth.currentUser!.uid;
    try {
      return await MessagingRepository.instance.getOrCreateDirectChat(
        currentUserId: currentUserId,
        otherUserId: otherUserId,
      );
    } catch (e) {
      secureLog('❌ ConnectionsService: Error finding/creating chat: $e');
      rethrow;
    }
  }

  /// Create mock connections for testing (remove in production)
  Future<void> createMockConnections() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      final mockConnections = [
        {
          'userId': 'mock_user_1',
          'username': 'alex_creator',
          'displayName': 'Alex Creator',
          'avatarUrl':
              'https://firebasestorage.googleapis.com/v0/b/streamerstip-6cfdb.firebasestorage.app/o/avatars%2Fdefault_avatar_1.jpg',
          'isOnline': true,
          'canReceiveDMs': true,
          'lastInteraction': FieldValue.serverTimestamp(),
          'verified': true,
        },
        {
          'userId': 'mock_user_2',
          'username': 'sarah_streamer',
          'displayName': 'Sarah Streamer',
          'avatarUrl':
              'https://firebasestorage.googleapis.com/v0/b/streamerstip-6cfdb.firebasestorage.app/o/avatars%2Fdefault_avatar_2.jpg',
          'isOnline': false,
          'canReceiveDMs': true,
          'lastInteraction': FieldValue.serverTimestamp(),
          'verified': false,
        },
        {
          'userId': 'mock_user_3',
          'username': 'mike_gamer',
          'displayName': 'Mike Gamer',
          'avatarUrl':
              'https://firebasestorage.googleapis.com/v0/b/streamerstip-6cfdb.firebasestorage.app/o/avatars%2Fdefault_avatar_3.jpg',
          'isOnline': true,
          'canReceiveDMs': true,
          'lastInteraction': FieldValue.serverTimestamp(),
          'verified': true,
        },
      ];

      for (final connection in mockConnections) {
        await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .collection('connections')
            .doc(connection['userId'] as String)
            .set(connection);
      }

      secureLog(
          '✅ ConnectionsService: Created ${mockConnections.length} mock connections');
    } catch (e) {
      secureLog('❌ ConnectionsService: Error creating mock connections: $e');
    }
  }
}
