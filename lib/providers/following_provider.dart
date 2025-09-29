import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/following_service.dart';

enum FollowRelationship {
  notFollowing,
  following,
  connected,
}

class FollowingState {
  final List<String> followingList;
  final List<String> followersList;
  final bool isLoading;
  final String? error;

  const FollowingState({
    this.followingList = const [],
    this.followersList = const [],
    this.isLoading = false,
    this.error,
  });

  FollowingState copyWith({
    List<String>? followingList,
    List<String>? followersList,
    bool? isLoading,
    String? error,
  }) {
    return FollowingState(
      followingList: followingList ?? this.followingList,
      followersList: followersList ?? this.followersList,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class FollowingNotifier extends StateNotifier<FollowingState> {
  FollowingNotifier() : super(const FollowingState()) {
    print('🔵 FollowingNotifier: Constructor called - initializing...');
    loadFollowingList();
  }

  /// Load the list of users being followed and followers
  Future<void> loadFollowingList() async {
    print('🔵 FollowingNotifier: loadFollowingList() called');
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final followingUsers = await FollowingService.getFollowingList();
      final followersUsers = await FollowingService.getFollowersList();
      print('🔵 FollowingNotifier: Loaded ${followingUsers.length} following, ${followersUsers.length} followers');
      state = state.copyWith(
        followingList: followingUsers.map((user) => user.id).toList(),
        followersList: followersUsers.map((user) => user.id).toList(),
        isLoading: false,
      );
    } catch (e) {
      print('🔵 FollowingNotifier: Error loading follow lists: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Follow a user
  Future<bool> followUser(String userId) async {
    print('🔵 FollowingNotifier: followUser($userId) called');
    try {
      final success = await FollowingService.followUser(userId);
      print('🔵 FollowingNotifier: followUser result: $success');
      if (success) {
        // Reload the following list
        await loadFollowingList();
      }
      return success;
    } catch (e) {
      print('🔵 FollowingNotifier: Error in followUser: $e');
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Unfollow a user
  Future<bool> unfollowUser(String userId) async {
    try {
      final success = await FollowingService.unfollowUser(userId);
      if (success) {
        // Reload the following list
        await loadFollowingList();
      }
      return success;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Toggle follow status
  Future<bool> toggleFollow(String userId) async {
    try {
      final success = await FollowingService.toggleFollow(userId);
      if (success) {
        // Reload the following list
        await loadFollowingList();
      }
      return success;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Add user to following list locally (for mock functionality)
  void addToFollowingList(String userId) {
    if (!state.followingList.contains(userId)) {
      state = state.copyWith(
        followingList: [...state.followingList, userId],
      );
    }
  }

  /// Remove user from following list locally (for mock functionality)
  void removeFromFollowingList(String userId) {
    if (state.followingList.contains(userId)) {
      state = state.copyWith(
        followingList: state.followingList.where((id) => id != userId).toList(),
      );
    }
  }

  /// Check if following a specific user
  bool isFollowing(String userId) {
    return state.followingList.contains(userId);
  }

  /// Check if a specific user is following the current user
  bool isFollowedBy(String userId) {
    return state.followersList.contains(userId);
  }

  /// Get the follow relationship status between current user and another user
  FollowRelationship getFollowRelationship(String userId) {
    final isFollowing = state.followingList.contains(userId);
    final isFollowedBy = state.followersList.contains(userId);
    
    if (isFollowing && isFollowedBy) {
      return FollowRelationship.connected;
    } else if (isFollowing) {
      return FollowRelationship.following;
    } else {
      return FollowRelationship.notFollowing;
    }
  }

  /// Clear error state
  void clearError() {
    state = state.copyWith(error: null);
  }
}

final followingProvider = StateNotifierProvider<FollowingNotifier, FollowingState>((ref) {
  return FollowingNotifier();
});
