import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/connection_lite.dart';

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
      log('❌ ConnectionsService: No authenticated user');
      return [];
    }

    final userId = currentUser.uid;

    // Check cache first (valid for 5 minutes)
    if (!forceRefresh && _connectionsCache.containsKey(userId)) {
      final cacheTime = _cacheTimestamp[userId];
      if (cacheTime != null &&
          DateTime.now().difference(cacheTime).inMinutes < 5) {
        log('✅ ConnectionsService: Using cached connections for $userId');
        return _connectionsCache[userId] ?? [];
      }
    }

    try {
      log('🔄 ConnectionsService: Fetching connections for $userId');

      // Fetch connections from Firestore with ranking
      final connections = await _fetchConnectionsWithRanking(userId, limit);

      // Cache the results
      _connectionsCache[userId] = connections;
      _cacheTimestamp[userId] = DateTime.now();

      log('✅ ConnectionsService: Loaded ${connections.length} connections for $userId');
      return connections;
    } catch (e) {
      log('❌ ConnectionsService: Error fetching connections: $e');
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
      log('📊 ConnectionsService: Counting total connections from all sources for $userId');

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

        log('📊 ConnectionsService: Found ${uniqueUserIds.length} connections from subcollection');
      } catch (e) {
        log('⚠️ ConnectionsService: Error counting from subcollection: $e');
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

        log('📊 ConnectionsService: Found additional connections from relationships (following)');
      } catch (e) {
        log('⚠️ ConnectionsService: Error counting from relationships (following): $e');
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

        log('📊 ConnectionsService: Found mutual connections from relationships (followers)');
      } catch (e) {
        log('⚠️ ConnectionsService: Error counting from relationships (followers): $e');
      }

      total = uniqueUserIds.length;
      _connectionsTotalCache[userId] = total;

      log('📊 ConnectionsService: Total unique connections for $userId: $total');
      return total;
    } catch (e) {
      log('❌ ConnectionsService: Error counting connections: $e');
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
      log('🔍 ConnectionsService: Searching connections with query: "$query"');

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

          // If connection data is incomplete, fetch from users collection
          if (handle.isEmpty || displayName.isEmpty || avatarUrl.isEmpty) {
            final userDoc =
                await _firestore.collection('users').doc(connectedUserId).get();

            if (userDoc.exists) {
              final userData = userDoc.data()!;
              handle = handle.isEmpty ? (userData['username'] ?? '') : handle;
              displayName = displayName.isEmpty
                  ? (userData['displayName'] ?? userData['name'] ?? handle)
                  : displayName;
              avatarUrl =
                  avatarUrl.isEmpty ? (userData['avatarURL'] ?? '') : avatarUrl;
              isOnline = userData['isOnline'] ?? false;

              log('🔍 ConnectionsService: Fetched user data for $connectedUserId - handle: $handle, avatarUrl: $avatarUrl');
            } else {
              log('⚠️ ConnectionsService: User document not found for $connectedUserId');
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
        log('⚠️ ConnectionsService: Error searching subcollection: $e');
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

          // If relationship data is incomplete, fetch from users collection
          if (handle.isEmpty || displayName.isEmpty) {
            final userDoc =
                await _firestore.collection('users').doc(connectedUserId).get();

            if (userDoc.exists) {
              final userData = userDoc.data()!;
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
        log('⚠️ ConnectionsService: Error searching relationships (following): $e');
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

          // If relationship data is incomplete, fetch from users collection
          if (handle.isEmpty || displayName.isEmpty) {
            final userDoc =
                await _firestore.collection('users').doc(connectedUserId).get();

            if (userDoc.exists) {
              final userData = userDoc.data()!;
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
        log('⚠️ ConnectionsService: Error searching relationships (followers): $e');
      }

      // Sort by ranking score for search results
      connections.sort((a, b) => b.rankingScore.compareTo(a.rankingScore));

      log('🔍 ConnectionsService: Found ${connections.length} matching connections from all sources');
      return connections.take(limit).toList();
    } catch (e) {
      log('❌ ConnectionsService: Error searching connections: $e');
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
      log('📤 ConnectionsService: Sending DM share to $recipientId for video $videoId');

      // Fetch video data for better display
      String videoTitle = 'Shared a video';
      String videoThumbnailUrl = '';

      try {
        final videoDoc =
            await _firestore.collection('videos').doc(videoId).get();
        if (videoDoc.exists) {
          final videoData = videoDoc.data()!;
          videoTitle =
              videoData['caption'] ?? videoData['title'] ?? 'Shared a video';
          videoThumbnailUrl = videoData['thumbnailUrl'] ?? '';
          log('📤 ConnectionsService: Fetched video data - title: "$videoTitle", thumbnail: "$videoThumbnailUrl"');
          log('📤 ConnectionsService: Full video data keys: ${videoData.keys.toList()}');
          log('📤 ConnectionsService: Raw caption: "${videoData['caption']}", title: "${videoData['title']}"');
        } else {
          log('⚠️ ConnectionsService: Video document does not exist: $videoId');
        }
      } catch (e) {
        log('⚠️ ConnectionsService: Could not fetch video data: $e');
        // Continue with default values
      }

      // Create DM share message
      final messageData = {
        'type': 'video_share',
        'messageType': 'video_share', // Add messageType for ChatView
        'from': _auth.currentUser!.uid, // Use 'from' field for Firestore rules
        'senderId': _auth.currentUser!.uid, // Keep for compatibility
        'recipientId': recipientId,
        'videoId': videoId,
        'shareToken': shareToken,
        'videoTitle': videoTitle, // Real video title
        'videoThumbnailUrl': videoThumbnailUrl, // Real thumbnail URL
        'text': 'Shared a video', // Fallback text for compatibility
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'readBy': [_auth.currentUser!.uid], // Mark as read by sender
      };

      // Find or create chat in the chats collection
      final chatId = await _findOrCreateChat(recipientId);

      // Add message to the chat
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add(messageData);

      // Update chat metadata
      await _firestore.collection('chats').doc(chatId).update({
        'lastMessage': 'Shared a video',
        'lastTimestamp': FieldValue.serverTimestamp(),
        'unreadCount': FieldValue.increment(1),
      });

      // Update connection ranking (bump lastInteraction)
      await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('connections')
          .doc(recipientId)
          .update({
        'lastInteraction': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
      });

      log('✅ ConnectionsService: DM share sent successfully to chat $chatId');
      return chatId;
    } catch (e) {
      log('❌ ConnectionsService: Error sending DM share: $e');
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
        log('❌ ConnectionsService: Failed to share to $recipientId: $e');
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

    log('🗑️ ConnectionsService: Cleared cache for $userId');
  }

  /// Fetch connections with server-side ranking from ALL sources
  Future<List<ConnectionLite>> _fetchConnectionsWithRanking(
      String userId, int limit) async {
    try {
      log('🔄 ConnectionsService: Fetching ALL connections for $userId from multiple sources');

      final connections = <ConnectionLite>[];
      final Set<String> processedUserIds = {}; // Prevent duplicates

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

          log('🔍 ConnectionsService: Connection data for $connectedUserId - handle: $handle, avatarUrl: $avatarUrl');
          log('🔍 ConnectionsService: Raw connection data: ${connectionData.keys.toList()}');

          // If connection data is incomplete, fetch from users collection
          if (handle.isEmpty || displayName.isEmpty || avatarUrl.isEmpty) {
            final userDoc =
                await _firestore.collection('users').doc(connectedUserId).get();

            if (userDoc.exists) {
              final userData = userDoc.data()!;
              handle = handle.isEmpty ? (userData['username'] ?? '') : handle;
              displayName = displayName.isEmpty
                  ? (userData['displayName'] ?? userData['name'] ?? handle)
                  : displayName;
              avatarUrl =
                  avatarUrl.isEmpty ? (userData['avatarURL'] ?? '') : avatarUrl;
              isOnline = userData['isOnline'] ?? false;

              log('🔍 ConnectionsService: Fetched user data for $connectedUserId - handle: $handle, avatarUrl: $avatarUrl');
            } else {
              log('⚠️ ConnectionsService: User document not found for $connectedUserId');
            }
          }

          if (handle.isNotEmpty) {
            // If still no avatar URL, try to construct a default one
            if (avatarUrl.isEmpty) {
              avatarUrl =
                  'https://via.placeholder.com/120x120/4ECDC4/FFFFFF?text=${handle.substring(0, 1).toUpperCase()}';
              log('🔍 ConnectionsService: Using placeholder avatar for $handle: $avatarUrl');
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

        log('✅ ConnectionsService: Found ${connections.length} connections from subcollection');
      } catch (e) {
        log('⚠️ ConnectionsService: Error fetching from connections subcollection: $e');
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

          // If relationship data is incomplete, fetch from users collection
          if (handle.isEmpty || displayName.isEmpty) {
            final userDoc =
                await _firestore.collection('users').doc(connectedUserId).get();

            if (userDoc.exists) {
              final userData = userDoc.data()!;
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
              log('🔍 ConnectionsService: Using placeholder avatar for $handle: $avatarUrl');
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

        log('✅ ConnectionsService: Found additional connections from relationships collection');
      } catch (e) {
        log('⚠️ ConnectionsService: Error fetching from relationships collection: $e');
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

          // If relationship data is incomplete, fetch from users collection
          if (handle.isEmpty || displayName.isEmpty) {
            final userDoc =
                await _firestore.collection('users').doc(connectedUserId).get();

            if (userDoc.exists) {
              final userData = userDoc.data()!;
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
              log('🔍 ConnectionsService: Using placeholder avatar for $handle: $avatarUrl');
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

        log('✅ ConnectionsService: Found mutual connections from followers');
      } catch (e) {
        log('⚠️ ConnectionsService: Error fetching mutual connections: $e');
      }

      // Sort by ranking score and return top connections
      connections.sort((a, b) => b.rankingScore.compareTo(a.rankingScore));

      log('🎯 ConnectionsService: Total connections found: ${connections.length}');
      return connections.take(limit).toList();
    } catch (e) {
      log('❌ ConnectionsService: Error fetching connections with ranking: $e');
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

  /// Find or create chat between two users
  Future<String> _findOrCreateChat(String otherUserId) async {
    final currentUserId = _auth.currentUser!.uid;

    try {
      // First, try to find existing chat
      final existingQuery = await _firestore
          .collection('chats')
          .where('participants', arrayContains: currentUserId)
          .get();

      for (final doc in existingQuery.docs) {
        final participants =
            List<String>.from(doc.data()['participants'] ?? []);
        if (participants.contains(otherUserId)) {
          log('📱 ConnectionsService: Found existing chat ${doc.id}');
          return doc.id;
        }
      }

      // Create new chat if none exists
      log('📱 ConnectionsService: Creating new chat with $otherUserId');
      final chatData = {
        'participants': [currentUserId, otherUserId],
        'lastMessage': '',
        'lastTimestamp': FieldValue.serverTimestamp(),
        'chatType': 'direct',
        'unreadCount': 0,
      };

      final docRef = await _firestore.collection('chats').add(chatData);
      log('📱 ConnectionsService: Created new chat ${docRef.id}');
      return docRef.id;
    } catch (e) {
      log('❌ ConnectionsService: Error finding/creating chat: $e');
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

      log('✅ ConnectionsService: Created ${mockConnections.length} mock connections');
    } catch (e) {
      log('❌ ConnectionsService: Error creating mock connections: $e');
    }
  }
}
