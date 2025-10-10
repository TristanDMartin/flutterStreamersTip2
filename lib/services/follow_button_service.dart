import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service to determine Follow button state based on NetworkView logic
/// Implements the product rules for Follow/Following/Connected/Self states
class FollowButtonService {
  static FollowButtonService? _instance;
  static FollowButtonService get instance =>
      _instance ??= FollowButtonService._();

  FollowButtonService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Determine the follow button state for a creator
  /// Returns: 'self', 'connected', 'following', 'follow', or null (hide button)
  Future<FollowButtonState> getButtonState({
    required String viewerId,
    required String creatorId,
  }) async {
    // 1. Check if creator is self
    if (viewerId == creatorId) {
      return FollowButtonState.self;
    }

    try {
      // 2. Check Connections (highest priority after self)
      final isConnected = await _isInConnections(viewerId, creatorId);
      if (isConnected) {
        return FollowButtonState.connected;
      }

      // 3. Check Following list
      final isFollowing = await _isFollowing(viewerId, creatorId);
      if (isFollowing) {
        return FollowButtonState.following;
      }

      // 4. Default: show Follow button
      return FollowButtonState.follow;
    } catch (e) {
      log('❌ FollowButtonService: Error determining state: $e');
      return FollowButtonState.follow; // Safe default
    }
  }

  /// Check if creator is in viewer's Connections (mutual follows)
  Future<bool> _isInConnections(String viewerId, String creatorId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(viewerId)
          .collection('connections')
          .doc(creatorId)
          .get();

      if (!doc.exists) return false;

      final data = doc.data();
      final followState = data?['followState'] as String?;

      // Connected means mutual follow
      return followState == 'mutual';
    } catch (e) {
      log('❌ FollowButtonService: Error checking connections: $e');
      return false;
    }
  }

  /// Check if viewer is following the creator (one-way)
  Future<bool> _isFollowing(String viewerId, String creatorId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(viewerId)
          .collection('connections')
          .doc(creatorId)
          .get();

      if (!doc.exists) return false;

      final data = doc.data();
      final followState = data?['followState'] as String?;

      // Following or mutual both count as "following"
      return followState == 'following' || followState == 'mutual';
    } catch (e) {
      log('❌ FollowButtonService: Error checking following: $e');
      return false;
    }
  }

  /// Follow a user (optimistic update)
  Future<bool> followUser({
    required String viewerId,
    required String creatorId,
  }) async {
    try {
      log('👥 FollowButtonService: Following user $creatorId');

      // Create connection document
      await _firestore
          .collection('users')
          .doc(viewerId)
          .collection('connections')
          .doc(creatorId)
          .set({
        'followState':
            'following', // Will auto-upgrade to 'mutual' if they follow back
        'canDM': false, // Will be true when mutual
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      log('✅ FollowButtonService: Successfully followed $creatorId');
      return true;
    } catch (e) {
      log('❌ FollowButtonService: Error following user: $e');
      return false;
    }
  }

  /// Unfollow a user
  Future<bool> unfollowUser({
    required String viewerId,
    required String creatorId,
  }) async {
    try {
      log('👥 FollowButtonService: Unfollowing user $creatorId');

      // Remove connection document
      await _firestore
          .collection('users')
          .doc(viewerId)
          .collection('connections')
          .doc(creatorId)
          .delete();

      log('✅ FollowButtonService: Successfully unfollowed $creatorId');
      return true;
    } catch (e) {
      log('❌ FollowButtonService: Error unfollowing user: $e');
      return false;
    }
  }
}

/// Follow button state enum
enum FollowButtonState {
  self, // "You" - viewer's own post
  connected, // "Connected" - mutual follows (in Connections)
  following, // "Following" - viewer follows creator (one-way)
  follow, // "Follow" - not following yet
}

/// Extension for button text and styling
extension FollowButtonStateExtension on FollowButtonState {
  String get buttonText {
    switch (this) {
      case FollowButtonState.self:
        return 'You';
      case FollowButtonState.connected:
        return 'Connected';
      case FollowButtonState.following:
        return 'Following';
      case FollowButtonState.follow:
        return 'Follow';
    }
  }

  bool get isTappable {
    switch (this) {
      case FollowButtonState.self:
        return false; // Can't follow yourself
      case FollowButtonState.connected:
        return true; // Can tap to see options
      case FollowButtonState.following:
        return true; // Can tap to unfollow
      case FollowButtonState.follow:
        return true; // Can tap to follow
    }
  }

  bool get showGradient {
    return this == FollowButtonState.follow; // Only "Follow" has gradient
  }
}

/// Riverpod provider for the service
final followButtonServiceProvider = Provider<FollowButtonService>((ref) {
  return FollowButtonService.instance;
});
