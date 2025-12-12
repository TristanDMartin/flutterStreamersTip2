import 'package:flutter_test/flutter_test.dart';

/// Pure logic tests for follow/following/connections tab math.
void main() {
  Set<String> connections(Set<String> following, Set<String> followers) =>
      following.intersection(followers);

  Set<String> followersOnly(Set<String> following, Set<String> followers) =>
      followers.difference(following);

  Set<String> followingOnly(Set<String> following, Set<String> followers) =>
      following.difference(followers);

  test('mutual follow lands in connections, not in other tabs', () {
    final following = {'userB'};
    final followers = {'userB'};

    expect(connections(following, followers), {'userB'});
    expect(followersOnly(following, followers), isEmpty);
    expect(followingOnly(following, followers), isEmpty);
  });

  test('one-way follow (you follow them) appears only in Following', () {
    final following = {'userB'};
    final followers = <String>{};

    expect(connections(following, followers), isEmpty);
    expect(followersOnly(following, followers), isEmpty);
    expect(followingOnly(following, followers), {'userB'});
  });

  test('one-way follower (they follow you) appears only in Followers', () {
    final following = <String>{};
    final followers = {'userB'};

    expect(connections(following, followers), isEmpty);
    expect(followersOnly(following, followers), {'userB'});
    expect(followingOnly(following, followers), isEmpty);
  });

  test('mixed lists separate correctly', () {
    final following = {'userB', 'userC', 'userD'};
    final followers = {'userA', 'userC', 'userE'};

    expect(connections(following, followers), {'userC'});
    expect(followersOnly(following, followers), {'userA', 'userE'});
    expect(followingOnly(following, followers), {'userB', 'userD'});
  });
}
