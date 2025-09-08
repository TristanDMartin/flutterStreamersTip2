import 'package:flutter/foundation.dart';

/// Network Models for NetworkView
/// 
/// This file contains all the models and algorithms needed for the NetworkView
/// including relationship management, user connections, and network analytics.

/// ======== CORE MODELS ========

/// NetworkTab enum for different network views
enum NetworkTab { connections, followers, following }

/// OnlineStatus enum for user status
enum OnlineStatus {
  online('online', 'Online'),
  offline('offline', 'Offline'),
  busy('busy', 'Busy'),
  dnd('dnd', 'Do Not Disturb'),
  streaming('streaming', 'Streaming');

  const OnlineStatus(this.value, this.displayName);
  final String value;
  final String displayName;
}

/// RelationshipType enum for different relationship types
enum RelationshipType {
  mutual('mutual', 'Mutual Follow'),
  follower('follower', 'Follower'),
  following('following', 'Following'),
  none('none', 'No Relationship');

  const RelationshipType(this.value, this.displayName);
  final String value;
  final String displayName;
}

/// ======== DATA MODELS ========

/// UserConnection model for network relationships
class UserConnection {
  final String userId;
  final String displayName;
  final String username;
  final String? avatarURL;
  final OnlineStatus onlineStatus;
  final RelationshipType relationshipType;
  final DateTime lastInteraction;
  final int interactionCount;
  final double connectionStrength;
  final List<String> mutualConnections;
  final List<String> hashtags;
  final String? bio;
  final int followerCount;
  final int followingCount;
  final int postCount;

  const UserConnection({
    required this.userId,
    required this.displayName,
    required this.username,
    this.avatarURL,
    required this.onlineStatus,
    required this.relationshipType,
    required this.lastInteraction,
    required this.interactionCount,
    required this.connectionStrength,
    required this.mutualConnections,
    required this.hashtags,
    this.bio,
    required this.followerCount,
    required this.followingCount,
    required this.postCount,
  });

  factory UserConnection.fromMap(Map<String, dynamic> data) {
    return UserConnection(
      userId: data['userId'] ?? '',
      displayName: data['displayName'] ?? '',
      username: data['username'] ?? '',
      avatarURL: data['avatarURL'],
      onlineStatus: OnlineStatus.values.firstWhere(
        (e) => e.value == data['onlineStatus'],
        orElse: () => OnlineStatus.offline,
      ),
      relationshipType: RelationshipType.values.firstWhere(
        (e) => e.value == data['relationshipType'],
        orElse: () => RelationshipType.none,
      ),
      lastInteraction: DateTime.tryParse(data['lastInteraction'] ?? '') ?? DateTime.now(),
      interactionCount: data['interactionCount'] ?? 0,
      connectionStrength: (data['connectionStrength'] ?? 0.0).toDouble(),
      mutualConnections: List<String>.from(data['mutualConnections'] ?? []),
      hashtags: List<String>.from(data['hashtags'] ?? []),
      bio: data['bio'],
      followerCount: data['followerCount'] ?? 0,
      followingCount: data['followingCount'] ?? 0,
      postCount: data['postCount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'displayName': displayName,
      'username': username,
      'avatarURL': avatarURL,
      'onlineStatus': onlineStatus.value,
      'relationshipType': relationshipType.value,
      'lastInteraction': lastInteraction.toIso8601String(),
      'interactionCount': interactionCount,
      'connectionStrength': connectionStrength,
      'mutualConnections': mutualConnections,
      'hashtags': hashtags,
      'bio': bio,
      'followerCount': followerCount,
      'followingCount': followingCount,
      'postCount': postCount,
    };
  }
}

/// NetworkStats model for network analytics
class NetworkStats {
  final int totalConnections;
  final int totalFollowers;
  final int totalFollowing;
  final int mutualConnections;
  final int newConnectionsThisWeek;
  final int newFollowersThisWeek;
  final double averageConnectionStrength;
  final double networkGrowthRate;
  final List<String> topHashtags;
  final List<String> topMutualConnections;
  final DateTime lastUpdated;

  const NetworkStats({
    required this.totalConnections,
    required this.totalFollowers,
    required this.totalFollowing,
    required this.mutualConnections,
    required this.newConnectionsThisWeek,
    required this.newFollowersThisWeek,
    required this.averageConnectionStrength,
    required this.networkGrowthRate,
    required this.topHashtags,
    required this.topMutualConnections,
    required this.lastUpdated,
  });

  factory NetworkStats.fromMap(Map<String, dynamic> data) {
    return NetworkStats(
      totalConnections: data['totalConnections'] ?? 0,
      totalFollowers: data['totalFollowers'] ?? 0,
      totalFollowing: data['totalFollowing'] ?? 0,
      mutualConnections: data['mutualConnections'] ?? 0,
      newConnectionsThisWeek: data['newConnectionsThisWeek'] ?? 0,
      newFollowersThisWeek: data['newFollowersThisWeek'] ?? 0,
      averageConnectionStrength: (data['averageConnectionStrength'] ?? 0.0).toDouble(),
      networkGrowthRate: (data['networkGrowthRate'] ?? 0.0).toDouble(),
      topHashtags: List<String>.from(data['topHashtags'] ?? []),
      topMutualConnections: List<String>.from(data['topMutualConnections'] ?? []),
      lastUpdated: DateTime.tryParse(data['lastUpdated'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalConnections': totalConnections,
      'totalFollowers': totalFollowers,
      'totalFollowing': totalFollowing,
      'mutualConnections': mutualConnections,
      'newConnectionsThisWeek': newConnectionsThisWeek,
      'newFollowersThisWeek': newFollowersThisWeek,
      'averageConnectionStrength': averageConnectionStrength,
      'networkGrowthRate': networkGrowthRate,
      'topHashtags': topHashtags,
      'topMutualConnections': topMutualConnections,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }
}

/// ======== ALGORITHMS ========

/// NetworkAlgorithm class for network analysis and optimization
class NetworkAlgorithm {
  /// Calculate connection strength between two users
  static double calculateConnectionStrength({
    required int mutualConnections,
    required int totalInteractions,
    required DateTime lastInteraction,
    int daysSinceLastInteraction = 0,
  }) {
    // Base strength from mutual connections (0-0.4)
    final mutualStrength = (mutualConnections / 100).clamp(0.0, 0.4);
    
    // Interaction frequency (0-0.3)
    final interactionStrength = (totalInteractions / 1000).clamp(0.0, 0.3);
    
    // Recency factor (0-0.3)
    final recencyFactor = (1.0 - (daysSinceLastInteraction / 30)).clamp(0.0, 1.0);
    final recencyStrength = recencyFactor * 0.3;
    
    return (mutualStrength + interactionStrength + recencyStrength).clamp(0.0, 1.0);
  }

  /// Find optimal connection suggestions
  static List<String> findConnectionSuggestions({
    required List<String> currentConnections,
    required List<String> followers,
    required List<String> following,
    Map<String, int> interactionCounts = const {},
    int maxSuggestions = 10,
  }) {
    // Get all potential connections (followers + following - current connections)
    final currentSet = currentConnections.toSet();
    final allPotential = [...followers, ...following]
        .where((id) => !currentSet.contains(id))
        .toSet()
        .toList();
    
    // Score each potential connection
    final scored = allPotential.map((id) {
      final score = _calculateSuggestionScore(
        id,
        currentConnections,
        followers,
        following,
        interactionCounts,
      );
      return MapEntry(id, score);
    }).toList();
    
    // Sort by score and return top suggestions
    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.take(maxSuggestions).map((e) => e.key).toList();
  }

  static double _calculateSuggestionScore(
    String userId,
    List<String> currentConnections,
    List<String> followers,
    List<String> following,
    Map<String, int> interactionCounts,
  ) {
    double score = 0.0;
    
    // Mutual connections boost
    final mutualCount = currentConnections.where((id) => 
        followers.contains(id) && following.contains(id)).length;
    score += mutualCount * 0.3;
    
    // Interaction history
    final interactions = interactionCounts[userId] ?? 0;
    score += (interactions / 100).clamp(0.0, 0.4);
    
    // Follower ratio (if they follow you, higher score)
    if (followers.contains(userId)) {
      score += 0.2;
    }
    
    // Following ratio (if you follow them, higher score)
    if (following.contains(userId)) {
      score += 0.1;
    }
    
    return score;
  }

  /// Optimize network performance
  static Map<String, dynamic> optimizeNetworkPerformance({
    required List<UserConnection> connections,
    required Map<String, int> interactionCounts,
    int maxConnections = 1000,
  }) {
    // Sort connections by strength and recency
    final sortedConnections = connections.toList()
      ..sort((a, b) {
        final strengthA = a.connectionStrength;
        final strengthB = b.connectionStrength;
        if (strengthA != strengthB) {
          return strengthB.compareTo(strengthA);
        }
        return b.lastInteraction.compareTo(a.lastInteraction);
      });
    
    // Take top connections
    final optimizedConnections = sortedConnections.take(maxConnections).toList();
    
    // Calculate performance metrics
    final totalStrength = optimizedConnections.fold(0.0, (sum, conn) => sum + conn.connectionStrength);
    final averageStrength = optimizedConnections.isNotEmpty 
        ? totalStrength / optimizedConnections.length 
        : 0.0;
    
    return {
      'optimizedConnections': optimizedConnections,
      'totalStrength': totalStrength,
      'averageStrength': averageStrength,
      'connectionCount': optimizedConnections.length,
      'optimizationScore': averageStrength * optimizedConnections.length,
    };
  }

  /// Detect network anomalies
  static List<String> detectNetworkAnomalies({
    required List<UserConnection> connections,
    required Map<String, int> recentInteractions,
    int thresholdDays = 7,
  }) {
    final anomalies = <String>[];
    final thresholdDate = DateTime.now().subtract(Duration(days: thresholdDays));
    
    for (final connection in connections) {
      // Check for inactive connections
      if (connection.lastInteraction.isBefore(thresholdDate) && 
          connection.connectionStrength > 0.5) {
        anomalies.add('Inactive high-strength connection: ${connection.displayName}');
      }
      
      // Check for low interaction despite high strength
      final interactions = recentInteractions[connection.userId] ?? 0;
      if (connection.connectionStrength > 0.7 && interactions < 5) {
        anomalies.add('Low interaction despite high strength: ${connection.displayName}');
      }
      
      // Check for suspicious activity patterns
      if (connection.followerCount > 10000 && connection.postCount < 10) {
        anomalies.add('Potential fake account: ${connection.displayName}');
      }
    }
    
    return anomalies;
  }

  /// Calculate network growth rate
  static double calculateNetworkGrowthRate({
    required int currentConnections,
    required int previousConnections,
    required int daysBetween,
  }) {
    if (previousConnections == 0 || daysBetween == 0) return 0.0;
    
    final growthRate = (currentConnections - previousConnections) / previousConnections;
    return (growthRate / daysBetween) * 30; // Monthly growth rate
  }

  /// Find network clusters
  static Map<String, List<String>> findNetworkClusters({
    required List<UserConnection> connections,
    required Map<String, List<String>> mutualConnections,
  }) {
    final clusters = <String, List<String>>{};
    final processed = <String>{};
    
    for (final connection in connections) {
      if (processed.contains(connection.userId)) continue;
      
      final cluster = <String>[connection.userId];
      final mutuals = mutualConnections[connection.userId] ?? [];
      
      // Find all connections that share mutual connections
      for (final other in connections) {
        if (other.userId == connection.userId || processed.contains(other.userId)) continue;
        
        final otherMutuals = mutualConnections[other.userId] ?? [];
        final sharedMutuals = mutuals.where((id) => otherMutuals.contains(id)).length;
        
        if (sharedMutuals >= 3) { // Threshold for cluster membership
          cluster.add(other.userId);
        }
      }
      
      if (cluster.length > 1) {
        clusters['cluster_${clusters.length + 1}'] = cluster;
        processed.addAll(cluster);
      }
    }
    
    return clusters;
  }
}

/// ======== UTILITY FUNCTIONS ========

/// Network utility functions
class NetworkUtils {
  /// Format connection count for display
  static String formatConnectionCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }

  /// Get connection strength color
  static String getConnectionStrengthColor(double strength) {
    if (strength >= 0.8) return 'green';
    if (strength >= 0.6) return 'yellow';
    if (strength >= 0.4) return 'orange';
    return 'red';
  }

  /// Calculate network health score
  static double calculateNetworkHealth({
    required int totalConnections,
    required double averageStrength,
    required int activeConnections,
    required double growthRate,
  }) {
    // Connection count score (0-0.3)
    final countScore = (totalConnections / 1000).clamp(0.0, 0.3);
    
    // Strength score (0-0.3)
    final strengthScore = averageStrength * 0.3;
    
    // Activity score (0-0.2)
    final activityScore = (activeConnections / totalConnections).clamp(0.0, 1.0) * 0.2;
    
    // Growth score (0-0.2)
    final growthScore = (growthRate / 10).clamp(0.0, 1.0) * 0.2;
    
    return (countScore + strengthScore + activityScore + growthScore).clamp(0.0, 1.0);
  }
}