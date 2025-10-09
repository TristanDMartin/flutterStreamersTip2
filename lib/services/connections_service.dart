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

  /// Get total connections count
  Future<int> getConnectionsTotal({bool forceRefresh = false}) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return 0;

    final userId = currentUser.uid;

    // Check cache
    if (!forceRefresh && _connectionsTotalCache.containsKey(userId)) {
      return _connectionsTotalCache[userId] ?? 0;
    }

    try {
      // Count total connections
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('connections')
          .count()
          .get();

      final total = snapshot.count ?? 0;
      _connectionsTotalCache[userId] = total;

      log('📊 ConnectionsService: Total connections for $userId: $total');
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

      // Search in connections collection
      final snapshot = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('connections')
          .limit(50) // Get more for client-side filtering
          .get();

      final connections = <ConnectionLite>[];

      for (final doc in snapshot.docs) {
        final connectionData = doc.data();
        final connectedUserId = connectionData['userId'] ?? doc.id;

        // Get user details from connection data
        String handle = connectionData['username'] ?? '';
        String displayName =
            connectionData['displayName'] ?? connectionData['name'] ?? handle;
        String avatarUrl =
            connectionData['avatarUrl'] ?? connectionData['avatar'] ?? '';
        bool isOnline = connectionData['isOnline'] ??
            connectionData['onlineStatus'] == 'online';

        // If connection data is incomplete, fetch from users collection
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
                avatarUrl.isEmpty ? (userData['avatarUrl'] ?? '') : avatarUrl;
            isOnline = userData['isOnline'] ?? false;
          }
        }

        // Client-side filtering
        if (handle.toLowerCase().contains(query.toLowerCase()) ||
            displayName.toLowerCase().contains(query.toLowerCase())) {
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
          ));
        }
      }

      // Sort by handle for search results
      connections.sort(
          (a, b) => a.handle.toLowerCase().compareTo(b.handle.toLowerCase()));

      log('🔍 ConnectionsService: Found ${connections.length} matching connections');
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

      // Create DM share message
      final messageData = {
        'type': 'video_share',
        'senderId': _auth.currentUser!.uid,
        'recipientId': recipientId,
        'videoId': videoId,
        'shareToken': shareToken,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      };

      // Add to conversations collection
      final conversationId =
          _generateConversationId(_auth.currentUser!.uid, recipientId);

      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .add(messageData);

      // Update conversation metadata
      await _firestore.collection('conversations').doc(conversationId).set({
        'participants': [_auth.currentUser!.uid, recipientId],
        'lastMessage': messageData,
        'lastActivity': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

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

      log('✅ ConnectionsService: DM share sent successfully');
      return conversationId;
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
        final conversationId = await shareToConnection(
          recipientId: recipientId,
          videoId: videoId,
          shareToken: shareToken,
        );
        results.add(conversationId);
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

  /// Fetch connections with server-side ranking
  Future<List<ConnectionLite>> _fetchConnectionsWithRanking(
      String userId, int limit) async {
    try {
      // Get connections from the existing structure (no status filter needed)
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('connections')
          .limit(limit * 2) // Get more for client-side filtering
          .get();

      final connections = <ConnectionLite>[];

      for (final doc in snapshot.docs) {
        final connectionData = doc.data();

        // The connection document contains the user data directly
        final connectedUserId = connectionData['userId'] ?? doc.id;

        // Try to get user details from connection data first
        String handle = connectionData['username'] ?? '';
        String displayName =
            connectionData['displayName'] ?? connectionData['name'] ?? handle;
        String avatarUrl =
            connectionData['avatarUrl'] ?? connectionData['avatar'] ?? '';
        bool isOnline = connectionData['isOnline'] ??
            connectionData['onlineStatus'] == 'online';

        // If connection data is incomplete, fetch from users collection
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
                avatarUrl.isEmpty ? (userData['avatarUrl'] ?? '') : avatarUrl;
            isOnline = userData['isOnline'] ?? false;
          }
        }

        if (handle.isNotEmpty) {
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

      // Sort by ranking score and return top connections
      connections.sort((a, b) => b.rankingScore.compareTo(a.rankingScore));

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

  /// Generate conversation ID for two users
  String _generateConversationId(String userId1, String userId2) {
    final sortedIds = [userId1, userId2]..sort();
    return '${sortedIds[0]}_${sortedIds[1]}';
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
