import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import '../models/user_count_fields.dart';
import '../models/network_models.dart';
import '../models/user.dart';
import '../utils/avatar_url_resolver.dart';

/// Advanced Network Service
///
/// This service provides advanced network management including:
/// - Connection optimization algorithms
/// - Network analytics and insights
/// - Performance monitoring
/// - Smart suggestions
class AdvancedNetworkService extends ChangeNotifier {
  static final AdvancedNetworkService _instance =
      AdvancedNetworkService._internal();
  factory AdvancedNetworkService() => _instance;
  AdvancedNetworkService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final fa.FirebaseAuth _auth = fa.FirebaseAuth.instance;

  // Network data
  List<UserConnection> _connections = [];
  List<User> _users = [];
  NetworkStats _stats = NetworkStats(
    totalConnections: 0,
    totalFollowers: 0,
    totalFollowing: 0,
    mutualConnections: 0,
    newConnectionsThisWeek: 0,
    newFollowersThisWeek: 0,
    averageConnectionStrength: 0.0,
    networkGrowthRate: 0.0,
    topHashtags: [],
    topMutualConnections: [],
    lastUpdated: DateTime.now(),
  );
  List<Map<String, dynamic>> _analytics = [];

  // Performance tracking
  bool _isLoading = false;
  String? _lastError;

  // Getters
  List<UserConnection> get connections => _connections;
  List<User> get users => _users;
  NetworkStats get stats => _stats;
  List<Map<String, dynamic>> get analytics => _analytics;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;

  /// Initialize the service with optimized loading
  Future<void> initialize() async {
    try {
      _isLoading = true;
      notifyListeners();

      // Load only critical data first (connections)
      await _loadConnections();

      // Load users and stats in background (non-blocking)
      _loadUsers().catchError((e) {
        debugPrint('⚠️ Failed to load users (non-critical): $e');
      });

      _calculateStats().catchError((e) {
        debugPrint('⚠️ Failed to calculate stats (non-critical): $e');
      });

      _loadAnalytics().catchError((e) {
        debugPrint('⚠️ Failed to load analytics (non-critical): $e');
      });

      _lastError = null;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('❌ AdvancedNetworkService: Error initializing: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load user connections from Firestore
  Future<void> _loadConnections() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      // Load following relationships
      final followingQuery = await _db
          .collection('relationships')
          .where('followerId', isEqualTo: uid)
          .get();

      // Load follower relationships
      final followersQuery = await _db
          .collection('relationships')
          .where('followingId', isEqualTo: uid)
          .get();

      final connections = <UserConnection>[];

      // Process following relationships
      for (final doc in followingQuery.docs) {
        final data = doc.data();
        connections.add(UserConnection(
          userId: data['followingId'] ?? '',
          displayName: data['displayName'] ?? 'User',
          username: data['username'] ?? 'user',
          avatarURL: resolveAvatarUrl(data),
          onlineStatus: OnlineStatus.offline,
          relationshipType: RelationshipType.following,
          lastInteraction:
              (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
          interactionCount: 0,
          connectionStrength: 0.5,
          mutualConnections: [],
          hashtags: [],
          bio: data['bio'],
          followerCount: UserCountFields.readFollowersCount(data),
          followingCount: UserCountFields.readFollowingCount(data),
          postCount: data['postCount'] ?? 0,
        ));
      }

      // Process follower relationships
      for (final doc in followersQuery.docs) {
        final data = doc.data();
        connections.add(UserConnection(
          userId: data['followerId'] ?? '',
          displayName: data['displayName'] ?? 'User',
          username: data['username'] ?? 'user',
          avatarURL: resolveAvatarUrl(data),
          onlineStatus: OnlineStatus.offline,
          relationshipType: RelationshipType.follower,
          lastInteraction:
              (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
          interactionCount: 0,
          connectionStrength: 0.5,
          mutualConnections: [],
          hashtags: [],
          bio: data['bio'],
          followerCount: UserCountFields.readFollowersCount(data),
          followingCount: UserCountFields.readFollowingCount(data),
          postCount: data['postCount'] ?? 0,
        ));
      }

      _connections = connections;
      debugPrint(
          '✅ AdvancedNetworkService: Loaded ${connections.length} connections');
    } catch (e) {
      debugPrint('❌ AdvancedNetworkService: Error loading connections: $e');
      rethrow;
    }
  }

  /// Load user data for connections
  Future<void> _loadUsers() async {
    try {
      final userIds = _connections.map((c) => c.userId).toSet().toList();

      if (userIds.isEmpty) {
        _users = [];
        return;
      }

      final users = <User>[];
      const batchSize = 10;

      for (int i = 0; i < userIds.length; i += batchSize) {
        final batch =
            userIds.sublist(i, (i + batchSize).clamp(0, userIds.length));
        final query = await _db
            .collection('users')
            .where(FieldPath.documentId, whereIn: batch)
            .get();

        for (final doc in query.docs) {
          users.add(User.fromMap(doc.data()));
        }
      }

      _users = users;
      debugPrint('✅ AdvancedNetworkService: Loaded ${users.length} users');
    } catch (e) {
      debugPrint('❌ AdvancedNetworkService: Error loading users: $e');
      rethrow;
    }
  }

  /// Calculate network statistics
  Future<void> _calculateStats() async {
    try {
      final connections = _connections;
      final mutualConnections = _findMutualConnections();
      final followers = connections
          .where((c) => c.relationshipType == RelationshipType.follower)
          .length;
      final following = connections
          .where((c) => c.relationshipType == RelationshipType.following)
          .length;

      // Calculate engagement rate
      await _getTotalInteractions();

      _stats = NetworkStats(
        totalConnections: connections.length,
        totalFollowers: followers,
        totalFollowing: following,
        mutualConnections: mutualConnections.length,
        newConnectionsThisWeek:
            0, // Placeholder - would calculate from recent connections
        newFollowersThisWeek:
            0, // Placeholder - would calculate from recent followers
        averageConnectionStrength: connections.isNotEmpty
            ? connections.fold(
                    0.0, (total, c) => total + c.connectionStrength) /
                connections.length
            : 0.0,
        networkGrowthRate:
            0.0, // Placeholder - would calculate growth over time
        topHashtags: [], // Placeholder - would analyze user hashtags
        topMutualConnections:
            mutualConnections.map((c) => c.userId).take(5).toList(),
        lastUpdated: DateTime.now(),
      );

      debugPrint(
          '✅ AdvancedNetworkService: Calculated stats: ${_stats.totalConnections} connections');
    } catch (e) {
      debugPrint('❌ AdvancedNetworkService: Error calculating stats: $e');
      rethrow;
    }
  }

  /// Find mutual connections
  List<UserConnection> _findMutualConnections() {
    final followingIds = _connections
        .where((c) => c.relationshipType == RelationshipType.following)
        .map((c) => c.userId)
        .toSet();

    final followerIds = _connections
        .where((c) => c.relationshipType == RelationshipType.follower)
        .map((c) => c.userId)
        .toSet();

    final mutualIds = followingIds.intersection(followerIds);

    return _connections
        .where((c) =>
            mutualIds.contains(c.userId) &&
            c.relationshipType == RelationshipType.mutual)
        .toList();
  }

  /// Get total interactions (simplified)
  Future<int> _getTotalInteractions() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return 0;

      // This would typically query interactions from a separate collection
      // For now, return a simplified calculation
      return _connections.length * 5; // Placeholder
    } catch (e) {
      debugPrint('❌ AdvancedNetworkService: Error getting interactions: $e');
      return 0;
    }
  }

  /// Load network analytics
  Future<void> _loadAnalytics() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      final query = await _db
          .collection('network_analytics')
          .where('userId', isEqualTo: uid)
          .orderBy('timestamp', descending: true)
          .limit(30)
          .get();

      _analytics = query.docs.map((doc) => doc.data()).toList();

      debugPrint(
          '✅ AdvancedNetworkService: Loaded ${_analytics.length} analytics records');
    } catch (e) {
      debugPrint('❌ AdvancedNetworkService: Error loading analytics: $e');
      // Don't rethrow - analytics are optional
    }
  }

  /// Get connection suggestions
  Future<List<User>> getConnectionSuggestions({int maxSuggestions = 10}) async {
    try {
      final currentConnections = _connections
          .where((c) => c.relationshipType == RelationshipType.mutual)
          .map((c) => c.userId)
          .toList();

      final followers = _connections
          .where((c) => c.relationshipType == RelationshipType.follower)
          .map((c) => c.userId)
          .toList();

      final following = _connections
          .where((c) => c.relationshipType == RelationshipType.following)
          .map((c) => c.userId)
          .toList();

      // Get interaction counts (simplified)
      final interactionCounts = <String, int>{};
      for (final user in _users) {
        interactionCounts[user.id] = user.followerCount; // Placeholder
      }

      final suggestionIds = NetworkAlgorithm.findConnectionSuggestions(
        currentConnections: currentConnections,
        followers: followers,
        following: following,
        interactionCounts: interactionCounts,
        maxSuggestions: maxSuggestions,
      );

      return _users.where((user) => suggestionIds.contains(user.id)).toList();
    } catch (e) {
      debugPrint('❌ AdvancedNetworkService: Error getting suggestions: $e');
      return [];
    }
  }

  /// Get network performance insights
  Map<String, dynamic> getPerformanceInsights() {
    try {
      final activeConnections = _connections;
      final interactionCounts = <String, int>{};

      for (final user in _users) {
        interactionCounts[user.id] = user.followerCount; // Placeholder
      }

      return NetworkAlgorithm.optimizeNetworkPerformance(
        connections: activeConnections,
        interactionCounts: interactionCounts,
        maxConnections: 1000,
      );
    } catch (e) {
      debugPrint('❌ AdvancedNetworkService: Error getting insights: $e');
      return {};
    }
  }

  /// Detect network anomalies
  List<String> detectAnomalies() {
    try {
      final interactionCounts = <String, int>{};

      for (final user in _users) {
        interactionCounts[user.id] = user.followerCount; // Placeholder
      }

      return NetworkAlgorithm.detectNetworkAnomalies(
        connections: _connections,
        recentInteractions: interactionCounts,
        thresholdDays: 7,
      );
    } catch (e) {
      debugPrint('❌ AdvancedNetworkService: Error detecting anomalies: $e');
      return [];
    }
  }

  /// Refresh network data
  Future<void> refresh() async {
    await initialize();
  }

  /// Add a new connection
  Future<void> addConnection(String userId, RelationshipType type) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      final connection = UserConnection(
        userId: userId,
        displayName: 'User', // Placeholder - would fetch from user profile
        username: 'user', // Placeholder - would fetch from user profile
        avatarURL: null,
        onlineStatus: OnlineStatus.offline,
        relationshipType: type,
        lastInteraction: DateTime.now(),
        interactionCount: 0,
        connectionStrength: 0.5,
        mutualConnections: [],
        hashtags: [],
        bio: null,
        followerCount: 0,
        followingCount: 0,
        postCount: 0,
      );

      await _db.collection('relationships').add({
        'followerId': uid,
        'followingId': userId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      _connections.add(connection);
      await _calculateStats();
      notifyListeners();

      debugPrint('✅ AdvancedNetworkService: Added connection to $userId');
    } catch (e) {
      debugPrint('❌ AdvancedNetworkService: Error adding connection: $e');
      rethrow;
    }
  }

  /// Remove a connection
  Future<void> removeConnection(String userId, RelationshipType type) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      // Find and remove from Firestore
      final query = await _db
          .collection('relationships')
          .where('followerId', isEqualTo: uid)
          .where('followingId', isEqualTo: userId)
          .get();

      for (final doc in query.docs) {
        await doc.reference.delete();
      }

      // Remove from local list
      _connections
          .removeWhere((c) => c.userId == userId && c.relationshipType == type);

      await _calculateStats();
      notifyListeners();

      debugPrint('✅ AdvancedNetworkService: Removed connection to $userId');
    } catch (e) {
      debugPrint('❌ AdvancedNetworkService: Error removing connection: $e');
      rethrow;
    }
  }

  /// Get user by ID
  User? getUserById(String userId) {
    try {
      return _users.firstWhere((user) => user.id == userId);
    } catch (e) {
      return null;
    }
  }

  /// Get connection by user ID
  UserConnection? getConnectionByUserId(String userId) {
    try {
      return _connections.firstWhere((c) => c.userId == userId);
    } catch (e) {
      return null;
    }
  }

  /// Check if users are connected
  bool areUsersConnected(String userId1, String userId2) {
    return _connections.any((c) => c.userId == userId1 || c.userId == userId2);
  }

  /// Get connection strength
  double getConnectionStrength(String userId) {
    try {
      final connection = getConnectionByUserId(userId);
      if (connection == null) return 0.0;

      final user = getUserById(userId);
      if (user == null) return 0.0;

      return NetworkAlgorithm.calculateConnectionStrength(
        mutualConnections: 1, // Simplified
        totalInteractions: user.followerCount,
        lastInteraction: connection.lastInteraction,
        daysSinceLastInteraction:
            DateTime.now().difference(connection.lastInteraction).inDays,
      );
    } catch (e) {
      debugPrint(
          '❌ AdvancedNetworkService: Error calculating connection strength: $e');
      return 0.0;
    }
  }
}
