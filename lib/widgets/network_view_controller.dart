import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/user.dart';
import '../services/network_service_optimized.dart';
import '../services/user_blocking_service.dart';

enum NetworkActionType {
  follow,
  unfollow,
  remove,
}

@immutable
class NetworkViewState {
  const NetworkViewState({
    this.connections = const <User>[],
    this.followers = const <User>[],
    this.following = const <User>[],
    this.isLoading = true,
    this.error,
    this.pendingActionUserId,
    this.pendingActionType,
  });

  final List<User> connections;
  final List<User> followers;
  final List<User> following;
  final bool isLoading;
  final String? error;
  final String? pendingActionUserId;
  final NetworkActionType? pendingActionType;

  NetworkViewState copyWith({
    List<User>? connections,
    List<User>? followers,
    List<User>? following,
    bool? isLoading,
    Object? error = _sentinel,
    Object? pendingActionUserId = _sentinel,
    Object? pendingActionType = _sentinel,
  }) {
    return NetworkViewState(
      connections: connections ?? this.connections,
      followers: followers ?? this.followers,
      following: following ?? this.following,
      isLoading: isLoading ?? this.isLoading,
      error: identical(error, _sentinel) ? this.error : error as String?,
      pendingActionUserId: identical(pendingActionUserId, _sentinel)
          ? this.pendingActionUserId
          : pendingActionUserId as String?,
      pendingActionType: identical(pendingActionType, _sentinel)
          ? this.pendingActionType
          : pendingActionType as NetworkActionType?,
    );
  }
}

const Object _sentinel = Object();

@immutable
class NetworkActionFeedback {
  const NetworkActionFeedback({
    required this.message,
    this.isError = false,
  });

  final String message;
  final bool isError;
}

abstract class NetworkViewService {
  Future<List<User>> getConnections();
  Future<List<User>> getFollowers();
  Future<List<User>> getFollowing();
  Future<bool> followUser(String userId);
  Future<bool> unfollowUser(String userId);
  Future<bool> removeFollower(String userId);
}

class NetworkViewServiceAdapter implements NetworkViewService {
  NetworkViewServiceAdapter({
    NetworkServiceOptimized? networkService,
  }) : _networkService = networkService ?? NetworkServiceOptimized();

  final NetworkServiceOptimized _networkService;

  @override
  Future<List<User>> getConnections() => _networkService.getConnections();

  @override
  Future<List<User>> getFollowers() => _networkService.getFollowers();

  @override
  Future<List<User>> getFollowing() => _networkService.getFollowing();

  @override
  Future<bool> followUser(String userId) => _networkService.followUser(userId);

  @override
  Future<bool> unfollowUser(String userId) =>
      _networkService.unfollowUser(userId);

  @override
  Future<bool> removeFollower(String userId) =>
      _networkService.removeFollower(userId);
}

class NetworkViewController extends ChangeNotifier {
  NetworkViewController({
    NetworkViewService? networkService,
    UserBlockingService? blockingService,
    Future<List<String>> Function()? blockedUsersLoader,
  })  : _networkService = networkService ?? NetworkViewServiceAdapter(),
        _blockingService = blockingService,
        _blockedUsersLoader = blockedUsersLoader;

  final NetworkViewService _networkService;
  final UserBlockingService? _blockingService;
  final Future<List<String>> Function()? _blockedUsersLoader;

  NetworkViewState _state = const NetworkViewState();

  NetworkViewState get state => _state;

  Future<void> initialize() => refresh();

  Future<void> refresh() async {
    _updateState(
      _state.copyWith(
        isLoading: true,
        error: null,
      ),
    );

    try {
      final results = await Future.wait<List<User>>([
        _networkService.getConnections(),
        _networkService.getFollowers(),
        _networkService.getFollowing(),
      ]);

      final blockedUserIds = (await (_blockedUsersLoader?.call() ??
              _blockingService?.getBlockedUsers() ??
              Future<List<String>>.value(const <String>[])))
          .toSet();

      _updateState(
        _state.copyWith(
          connections: _filterBlockedUsers(results[0], blockedUserIds),
          followers: _filterBlockedUsers(results[1], blockedUserIds),
          following: _filterBlockedUsers(results[2], blockedUserIds),
          isLoading: false,
          error: null,
        ),
      );
    } catch (error) {
      _updateState(
        _state.copyWith(
          isLoading: false,
          error: error.toString(),
        ),
      );
    }
  }

  Future<NetworkActionFeedback> follow(User user) async {
    HapticFeedback.lightImpact();
    return _runUserAction(
      user: user,
      actionType: NetworkActionType.follow,
      action: () => _networkService.followUser(user.id),
      successMessage: 'Following ${user.displayName}',
      failureMessage: 'Failed to follow ${user.displayName}',
    );
  }

  Future<NetworkActionFeedback> unfollow(User user) async {
    HapticFeedback.lightImpact();
    return _runUserAction(
      user: user,
      actionType: NetworkActionType.unfollow,
      action: () => _networkService.unfollowUser(user.id),
      successMessage: 'Unfollowed ${user.displayName}',
      failureMessage: 'Failed to unfollow ${user.displayName}',
    );
  }

  Future<NetworkActionFeedback> remove(User user) async {
    HapticFeedback.lightImpact();
    return _runUserAction(
      user: user,
      actionType: NetworkActionType.remove,
      action: () => _networkService.removeFollower(user.id),
      successMessage: 'Removed ${user.displayName}',
      failureMessage: 'Failed to remove ${user.displayName}',
    );
  }

  Future<NetworkActionFeedback> _runUserAction({
    required User user,
    required NetworkActionType actionType,
    required Future<bool> Function() action,
    required String successMessage,
    required String failureMessage,
  }) async {
    if (_state.pendingActionUserId == user.id) {
      return const NetworkActionFeedback(
        message: 'Please wait for the current action to finish.',
        isError: true,
      );
    }

    _updateState(
      _state.copyWith(
        pendingActionUserId: user.id,
        pendingActionType: actionType,
      ),
    );

    try {
      final success = await action();
      if (!success) {
        return NetworkActionFeedback(message: failureMessage, isError: true);
      }

      await refresh();
      return NetworkActionFeedback(message: successMessage);
    } catch (_) {
      return const NetworkActionFeedback(
        message: 'Something went wrong. Please try again.',
        isError: true,
      );
    } finally {
      _updateState(
        _state.copyWith(
          pendingActionUserId: null,
          pendingActionType: null,
        ),
      );
    }
  }

  List<User> _filterBlockedUsers(List<User> users, Set<String> blockedUserIds) {
    if (blockedUserIds.isEmpty) {
      return users;
    }

    return users.where((user) => !blockedUserIds.contains(user.id)).toList();
  }

  void _updateState(NetworkViewState nextState) {
    _state = nextState;
    notifyListeners();
  }
}
