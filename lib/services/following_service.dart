import 'package:flutter/foundation.dart';
import 'follows_service.dart';
import '../models/user_model.dart' as user_model;

/// FollowingService - Wrapper around FollowsService for backward compatibility
///
/// This service maintains the same API as before but now uses the correct
/// data model implemented in FollowsService.
class FollowingService {
  static final FollowsService _followsService = FollowsService();

  /// Follow a user using the new FollowsService
  static Future<bool> followUser(String userId) async {
    try {
      debugPrint('FollowingService: Following user $userId');
      return await _followsService.followUser(userId);
    } catch (e) {
      debugPrint('FollowingService: Error following user: $e');
      return false;
    }
  }

  /// Unfollow a user using the new FollowsService
  static Future<bool> unfollowUser(String userId) async {
    try {
      debugPrint('FollowingService: Unfollowing user $userId');
      return await _followsService.unfollowUser(userId);
    } catch (e) {
      debugPrint('FollowingService: Error unfollowing user: $e');
      return false;
    }
  }

  /// Check if current user follows a specific user
  static Future<bool> isFollowing(String userId) async {
    try {
      return await _followsService.isFollowing(userId);
    } catch (e) {
      debugPrint('FollowingService: Error checking follow status: $e');
      return false;
    }
  }

  /// Check if a specific user follows the current user
  static Future<bool> isFollowedBy(String userId) async {
    try {
      return await _followsService.isFollowedBy(userId);
    } catch (e) {
      debugPrint('FollowingService: Error checking follow status: $e');
      return false;
    }
  }

  /// Check if users have a mutual follow relationship
  static Future<bool> isMutualFollow(String userId) async {
    try {
      return await _followsService.isMutualFollow(userId);
    } catch (e) {
      debugPrint('FollowingService: Error checking mutual follow: $e');
      return false;
    }
  }

  /// Get list of users the current user is following
  static Future<List<user_model.User>> getFollowingList() async {
    try {
      return await _followsService.getUsersForTab('following');
    } catch (e) {
      debugPrint('FollowingService: Error getting following list: $e');
      return [];
    }
  }

  /// Get list of users who follow the current user
  static Future<List<user_model.User>> getFollowersList() async {
    try {
      return await _followsService.getUsersForTab('followers');
    } catch (e) {
      debugPrint('FollowingService: Error getting followers list: $e');
      return [];
    }
  }

  /// Get list of mutual connections
  static Future<List<user_model.User>> getConnectionsList() async {
    try {
      return await _followsService.getUsersForTab('connections');
    } catch (e) {
      debugPrint('FollowingService: Error getting connections list: $e');
      return [];
    }
  }

  /// Toggle follow status (follow if not following, unfollow if following)
  static Future<bool> toggleFollow(String userId) async {
    try {
      final isCurrentlyFollowing = await isFollowing(userId);
      if (isCurrentlyFollowing) {
        return await unfollowUser(userId);
      } else {
        return await followUser(userId);
      }
    } catch (e) {
      debugPrint('FollowingService: Error toggling follow: $e');
      return false;
    }
  }
}
