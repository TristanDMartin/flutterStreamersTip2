import 'package:flutter_test/flutter_test.dart';

/// Headless in-memory follow flow to mirror tab and button states.
/// This does not hit Firestore; it simulates the rules:
/// - Connections: mutual follows
/// - Followers: they follow you only
/// - Following: you follow them only
/// - Block: hides both directions
enum FollowButtonState { self, connected, following, follow, blocked }

class FollowEdge {
  FollowEdge(this.follower, this.target, {this.isActive = true});
  final String follower;
  final String target;
  bool isActive;
}

class BlockEdge {
  BlockEdge(this.blocker, this.blocked);
  final String blocker;
  final String blocked;
}

class FakeSocialGraph {
  final List<FollowEdge> follows = [];
  final List<BlockEdge> blocks = [];

  void follow(String follower, String target) {
    if (follower == target) return;
    if (_isBlockedEitherWay(follower, target)) return;
    final existing = follows
        .where((e) => e.follower == follower && e.target == target)
        .toList();
    if (existing.isEmpty) {
      follows.add(FollowEdge(follower, target, isActive: true));
    } else {
      existing.first.isActive = true;
    }
  }

  void unfollow(String follower, String target) {
    for (final e in follows) {
      if (e.follower == follower && e.target == target) {
        e.isActive = false;
      }
    }
  }

  void block(String blocker, String blocked) {
    blocks.add(BlockEdge(blocker, blocked));
    // deactivate any follow edges between them
    for (final e in follows) {
      if ((e.follower == blocker && e.target == blocked) ||
          (e.follower == blocked && e.target == blocker)) {
        e.isActive = false;
      }
    }
  }

  bool _isBlockedEitherWay(String a, String b) {
    return blocks.any((e) =>
        (e.blocker == a && e.blocked == b) ||
        (e.blocker == b && e.blocked == a));
  }

  Set<String> connections(String user) {
    final following = _activeTargets(user);
    final followers = _activeFollowers(user);
    return following.intersection(followers)
      ..removeWhere((id) => _isBlockedEitherWay(user, id));
  }

  Set<String> followersOnly(String user) {
    final following = _activeTargets(user);
    final followers = _activeFollowers(user);
    final result = followers.difference(following);
    result.removeWhere((id) => _isBlockedEitherWay(user, id));
    return result;
  }

  Set<String> followingOnly(String user) {
    final following = _activeTargets(user);
    final followers = _activeFollowers(user);
    final result = following.difference(followers);
    result.removeWhere((id) => _isBlockedEitherWay(user, id));
    return result;
  }

  FollowButtonState buttonState(String viewer, String target) {
    if (viewer == target) return FollowButtonState.self;
    if (_isBlockedEitherWay(viewer, target)) return FollowButtonState.blocked;
    final isFollowing = follows
        .any((e) => e.follower == viewer && e.target == target && e.isActive);
    final isFollowedBy = follows
        .any((e) => e.follower == target && e.target == viewer && e.isActive);
    if (isFollowing && isFollowedBy) return FollowButtonState.connected;
    if (isFollowing) return FollowButtonState.following;
    return FollowButtonState.follow;
  }

  Set<String> _activeTargets(String follower) => follows
      .where((e) => e.follower == follower && e.isActive)
      .map((e) => e.target)
      .toSet();

  Set<String> _activeFollowers(String target) => follows
      .where((e) => e.target == target && e.isActive)
      .map((e) => e.follower)
      .toSet();
}

void main() {
  test('mutual follow → connections + connected button', () {
    final g = FakeSocialGraph();
    g.follow('userA', 'userB');
    g.follow('userB', 'userA');

    expect(g.connections('userA'), {'userB'});
    expect(g.followersOnly('userA'), isEmpty);
    expect(g.followingOnly('userA'), isEmpty);
    expect(g.buttonState('userA', 'userB'), FollowButtonState.connected);
  });

  test('one-way follow → following tab + following button', () {
    final g = FakeSocialGraph();
    g.follow('userA', 'userB');

    expect(g.connections('userA'), isEmpty);
    expect(g.followingOnly('userA'), {'userB'});
    expect(g.followersOnly('userB'), {'userA'});
    expect(g.buttonState('userA', 'userB'), FollowButtonState.following);
    expect(g.buttonState('userB', 'userA'), FollowButtonState.follow);
  });

  test('unfollow removes from following and connections', () {
    final g = FakeSocialGraph();
    g.follow('userA', 'userB');
    g.follow('userB', 'userA');
    g.unfollow('userA', 'userB');

    expect(g.connections('userA'), isEmpty);
    expect(g.followingOnly('userA'), isEmpty);
    expect(g.followersOnly('userA'), {'userB'});
    expect(g.buttonState('userA', 'userB'), FollowButtonState.follow);
  });

  test('block hides both directions and button shows blocked', () {
    final g = FakeSocialGraph();
    g.follow('userA', 'userB');
    g.follow('userB', 'userA');
    g.block('userA', 'userB');

    expect(g.connections('userA'), isEmpty);
    expect(g.followersOnly('userA'), isEmpty);
    expect(g.followingOnly('userA'), isEmpty);
    expect(g.buttonState('userA', 'userB'), FollowButtonState.blocked);
    expect(g.buttonState('userB', 'userA'), FollowButtonState.blocked);
  });
}
