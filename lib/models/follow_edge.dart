import 'package:cloud_firestore/cloud_firestore.dart';

/// FollowEdge - Single source of truth for follow relationships
///
/// Stores one directed edge per user pair with status tracking
class FollowEdge {
  final String followerId; // the user who follows
  final String followeeId; // the user being followed
  final FollowStatus status; // "active" | "none" | "blocked" | "pending"
  final DateTime createdAt;
  final DateTime updatedAt;

  const FollowEdge({
    required this.followerId,
    required this.followeeId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FollowEdge.fromMap(Map<String, dynamic> map) {
    return FollowEdge(
      followerId: map['followerId'] as String,
      followeeId: map['followeeId'] as String,
      status: FollowStatus.fromString(map['status'] as String),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'followerId': followerId,
      'followeeId': followeeId,
      'status': status.value,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  FollowEdge copyWith({
    String? followerId,
    String? followeeId,
    FollowStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FollowEdge(
      followerId: followerId ?? this.followerId,
      followeeId: followeeId ?? this.followeeId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if this is a mutual follow relationship
  bool isMutualWith(FollowEdge? otherEdge) {
    if (otherEdge == null) return false;
    return status == FollowStatus.active &&
        otherEdge.status == FollowStatus.active &&
        followerId == otherEdge.followeeId &&
        followeeId == otherEdge.followerId;
  }

  @override
  String toString() {
    return 'FollowEdge(followerId: $followerId, followeeId: $followeeId, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FollowEdge &&
        other.followerId == followerId &&
        other.followeeId == followeeId;
  }

  @override
  int get hashCode => followerId.hashCode ^ followeeId.hashCode;
}

/// Follow status enum
enum FollowStatus {
  active('active'),
  none('none'),
  blocked('blocked'),
  pending('pending');

  const FollowStatus(this.value);
  final String value;

  static FollowStatus fromString(String value) {
    switch (value) {
      case 'active':
        return FollowStatus.active;
      case 'none':
        return FollowStatus.none;
      case 'blocked':
        return FollowStatus.blocked;
      case 'pending':
        return FollowStatus.pending;
      default:
        return FollowStatus.none;
    }
  }
}

/// Relationship state for UI updates
class RelationshipState {
  final String userId;
  final List<String> following; // users I follow
  final List<String> followers; // users who follow me
  final List<String> connections; // mutual follows

  const RelationshipState({
    required this.userId,
    required this.following,
    required this.followers,
    required this.connections,
  });

  factory RelationshipState.empty(String userId) {
    return RelationshipState(
      userId: userId,
      following: [],
      followers: [],
      connections: [],
    );
  }

  RelationshipState copyWith({
    String? userId,
    List<String>? following,
    List<String>? followers,
    List<String>? connections,
  }) {
    return RelationshipState(
      userId: userId ?? this.userId,
      following: following ?? this.following,
      followers: followers ?? this.followers,
      connections: connections ?? this.connections,
    );
  }

  int get followingCount => following.length;
  int get followersCount => followers.length;
  int get connectionsCount => connections.length;
}
