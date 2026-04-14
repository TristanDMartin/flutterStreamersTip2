import 'package:flutter_test/flutter_test.dart';

import 'package:streamers_tip/models/user.dart';
import 'package:streamers_tip/widgets/network_view_controller.dart';

class _FakeNetworkViewService implements NetworkViewService {
  List<User> connectionsResult;
  List<User> followersResult;
  List<User> followingResult;

  final List<String> followedUserIds = <String>[];
  final List<String> unfollowedUserIds = <String>[];
  final List<String> removedUserIds = <String>[];

  bool followShouldSucceed;
  bool unfollowShouldSucceed;
  bool removeShouldSucceed;

  _FakeNetworkViewService({
    required this.connectionsResult,
    required this.followersResult,
    required this.followingResult,
  })  : followShouldSucceed = true,
        unfollowShouldSucceed = true,
        removeShouldSucceed = true;

  @override
  Future<List<User>> getConnections() async => connectionsResult;

  @override
  Future<List<User>> getFollowers() async => followersResult;

  @override
  Future<List<User>> getFollowing() async => followingResult;

  @override
  Future<bool> followUser(String userId) async {
    followedUserIds.add(userId);
    return followShouldSucceed;
  }

  @override
  Future<bool> unfollowUser(String userId) async {
    unfollowedUserIds.add(userId);
    return unfollowShouldSucceed;
  }

  @override
  Future<bool> removeFollower(String userId) async {
    removedUserIds.add(userId);
    return removeShouldSucceed;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NetworkViewController', () {
    late User alex;
    late User blair;
    late User casey;

    setUp(() {
      alex = const User(
        id: 'alex',
        username: 'alex',
        displayName: 'Alex',
      );
      blair = const User(
        id: 'blair',
        username: 'blair',
        displayName: 'Blair',
      );
      casey = const User(
        id: 'casey',
        username: 'casey',
        displayName: 'Casey',
      );
    });

    test('refresh loads lists and filters blocked users', () async {
      final service = _FakeNetworkViewService(
        connectionsResult: <User>[alex, blair],
        followersResult: <User>[blair, casey],
        followingResult: <User>[alex, casey],
      );

      final controller = NetworkViewController(
        networkService: service,
        blockedUsersLoader: () async => <String>['blair'],
      );

      await controller.refresh();

      expect(controller.state.isLoading, isFalse);
      expect(controller.state.error, isNull);
      expect(
        controller.state.connections.map((user) => user.id),
        <String>['alex'],
      );
      expect(
        controller.state.followers.map((user) => user.id),
        <String>['casey'],
      );
      expect(
        controller.state.following.map((user) => user.id),
        <String>['alex', 'casey'],
      );
    });

    test('follow action reports success and refreshes state', () async {
      final service = _FakeNetworkViewService(
        connectionsResult: const <User>[],
        followersResult: <User>[alex],
        followingResult: const <User>[],
      );

      final controller = NetworkViewController(
        networkService: service,
        blockedUsersLoader: () async => const <String>[],
      );

      await controller.refresh();

      service.connectionsResult = <User>[alex];
      service.followersResult = <User>[alex];
      service.followingResult = <User>[alex];

      final feedback = await controller.follow(alex);

      expect(feedback.isError, isFalse);
      expect(feedback.message, contains('Following Alex'));
      expect(service.followedUserIds, <String>['alex']);
      expect(
        controller.state.following.map((user) => user.id),
        <String>['alex'],
      );
      expect(controller.state.pendingActionUserId, isNull);
    });

    test('remove action reports failure without mutating loaded lists', () async {
      final service = _FakeNetworkViewService(
        connectionsResult: const <User>[],
        followersResult: <User>[casey],
        followingResult: const <User>[],
      );
      service.removeShouldSucceed = false;

      final controller = NetworkViewController(
        networkService: service,
        blockedUsersLoader: () async => const <String>[],
      );

      await controller.refresh();
      final feedback = await controller.remove(casey);

      expect(feedback.isError, isTrue);
      expect(feedback.message, contains('Failed to remove Casey'));
      expect(service.removedUserIds, <String>['casey']);
      expect(
        controller.state.followers.map((user) => user.id),
        <String>['casey'],
      );
      expect(controller.state.pendingActionUserId, isNull);
    });
  });
}
