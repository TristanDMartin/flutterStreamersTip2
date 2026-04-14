import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../services/follows_service.dart';

enum StreamerCardRelationshipActionResult {
  success,
  authRequired,
  busy,
  notFound,
  permissionDenied,
  networkError,
  failure,
}

@immutable
class StreamerCardRelationshipState {
  const StreamerCardRelationshipState({
    this.isFollowing = false,
    this.isFollowedByStreamer = false,
    this.isConnected = false,
    this.isFollowingOperation = false,
    this.isUnfollowingOperation = false,
  });

  final bool isFollowing;
  final bool isFollowedByStreamer;
  final bool isConnected;
  final bool isFollowingOperation;
  final bool isUnfollowingOperation;

  StreamerCardRelationshipState copyWith({
    bool? isFollowing,
    bool? isFollowedByStreamer,
    bool? isConnected,
    bool? isFollowingOperation,
    bool? isUnfollowingOperation,
  }) {
    return StreamerCardRelationshipState(
      isFollowing: isFollowing ?? this.isFollowing,
      isFollowedByStreamer:
          isFollowedByStreamer ?? this.isFollowedByStreamer,
      isConnected: isConnected ?? this.isConnected,
      isFollowingOperation:
          isFollowingOperation ?? this.isFollowingOperation,
      isUnfollowingOperation:
          isUnfollowingOperation ?? this.isUnfollowingOperation,
    );
  }
}

class StreamerCardRelationshipController extends ChangeNotifier {
  StreamerCardRelationshipController({
    required FollowsService followsService,
    FirebaseFirestore? firestore,
  })  : _followsService = followsService,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FollowsService _followsService;
  final FirebaseFirestore _firestore;
  final List<StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
      _followGraphSubscriptions = <StreamSubscription<
          QuerySnapshot<Map<String, dynamic>>>>[];

  Timer? _relationshipRefreshDebounce;
  String? _currentUserId;
  String? _targetUserId;
  StreamerCardRelationshipState _state = const StreamerCardRelationshipState();

  StreamerCardRelationshipState get state => _state;

  Future<void> bind({
    required String? currentUserId,
    required String targetUserId,
  }) async {
    _currentUserId = currentUserId;
    _targetUserId = targetUserId;

    _cancelListeners();

    if (currentUserId == null || currentUserId == targetUserId) {
      _setState(const StreamerCardRelationshipState());
      return;
    }

    await refresh();
    _setupRelationshipListeners();
  }

  Future<void> refresh() async {
    if (_currentUserId == null ||
        _targetUserId == null ||
        _currentUserId == _targetUserId) {
      _setState(const StreamerCardRelationshipState());
      return;
    }

    try {
      final isFollowing = await _followsService.isFollowing(_targetUserId!);
      final isFollowedByStreamer =
          await _followsService.isFollowedBy(_targetUserId!);
      _setRelationshipState(
        isFollowing: isFollowing,
        isFollowedByStreamer: isFollowedByStreamer,
        preserveOperationFlags: true,
      );
    } catch (_) {
      _setRelationshipState(
        isFollowing: false,
        isFollowedByStreamer: false,
        preserveOperationFlags: true,
      );
    }
  }

  Future<StreamerCardRelationshipActionResult> follow({
    FutureOr<void> Function(String userId)? onFollow,
  }) async {
    if (_state.isFollowingOperation || _state.isUnfollowingOperation) {
      return StreamerCardRelationshipActionResult.busy;
    }
    if (_currentUserId == null || _targetUserId == null) {
      return StreamerCardRelationshipActionResult.authRequired;
    }

    final originalState = _state;
    _setState(
      _state.copyWith(
        isFollowing: true,
        isConnected: _state.isFollowedByStreamer,
        isFollowingOperation: true,
      ),
    );

    try {
      if (onFollow != null) {
        await onFollow(_targetUserId!);
        final persisted = await _followsService.isFollowing(_targetUserId!);
        if (!persisted) {
          final persistedOk = await _followsService.followUser(_targetUserId!);
          if (!persistedOk) {
            throw Exception('Follow write failed after callback');
          }
        }
      } else {
        final success = await _followsService.followUser(_targetUserId!);
        if (!success) {
          throw Exception('Failed to follow user via FollowsService');
        }
      }

      _setState(_state.copyWith(isFollowingOperation: false));
      await refresh();
      return StreamerCardRelationshipActionResult.success;
    } catch (error) {
      _setState(
        originalState.copyWith(isFollowingOperation: false),
      );
      return _mapError(error);
    }
  }

  Future<StreamerCardRelationshipActionResult> unfollow() async {
    if (_state.isFollowingOperation || _state.isUnfollowingOperation) {
      return StreamerCardRelationshipActionResult.busy;
    }
    if (_currentUserId == null || _targetUserId == null) {
      return StreamerCardRelationshipActionResult.authRequired;
    }

    final originalState = _state;
    _setState(
      _state.copyWith(
        isFollowing: false,
        isConnected: false,
        isUnfollowingOperation: true,
      ),
    );

    try {
      final success = await _followsService.unfollowUser(_targetUserId!);
      if (!success) {
        throw Exception('Failed to unfollow user via FollowsService');
      }

      _setState(_state.copyWith(isUnfollowingOperation: false));
      await refresh();
      return StreamerCardRelationshipActionResult.success;
    } catch (error) {
      _setState(
        originalState.copyWith(isUnfollowingOperation: false),
      );
      return _mapError(error);
    }
  }

  void _setupRelationshipListeners() {
    if (_currentUserId == null ||
        _targetUserId == null ||
        _currentUserId == _targetUserId) {
      return;
    }

    final String uid = _currentUserId!;
    final List<Query<Map<String, dynamic>>> queries = <Query<Map<String, dynamic>>>[
      _firestore.collection('follows').where('followerUserId', isEqualTo: uid),
      _firestore.collection('follows').where('targetUserId', isEqualTo: uid),
      _firestore.collection('follows').where('followerId', isEqualTo: uid),
      _firestore.collection('follows').where('followingId', isEqualTo: uid),
      _firestore.collection('follows').where('followedId', isEqualTo: uid),
    ];

    void scheduleRefresh() {
      _relationshipRefreshDebounce?.cancel();
      _relationshipRefreshDebounce =
          Timer(const Duration(milliseconds: 120), () {
        unawaited(refresh());
      });
    }

    for (final Query<Map<String, dynamic>> query in queries) {
      _followGraphSubscriptions.add(
        query.snapshots().listen(
          (_) => scheduleRefresh(),
          onError: (_) {},
        ),
      );
    }
  }

  void _setRelationshipState({
    required bool isFollowing,
    required bool isFollowedByStreamer,
    bool preserveOperationFlags = false,
  }) {
    _setState(
      StreamerCardRelationshipState(
        isFollowing: isFollowing,
        isFollowedByStreamer: isFollowedByStreamer,
        isConnected: isFollowing && isFollowedByStreamer,
        isFollowingOperation:
            preserveOperationFlags ? _state.isFollowingOperation : false,
        isUnfollowingOperation:
            preserveOperationFlags ? _state.isUnfollowingOperation : false,
      ),
    );
  }

  StreamerCardRelationshipActionResult _mapError(Object error) {
    final text = error.toString();
    if (text.contains('not-found')) {
      return StreamerCardRelationshipActionResult.notFound;
    }
    if (text.contains('permission-denied')) {
      return StreamerCardRelationshipActionResult.permissionDenied;
    }
    if (text.contains('network')) {
      return StreamerCardRelationshipActionResult.networkError;
    }
    return StreamerCardRelationshipActionResult.failure;
  }

  void _setState(StreamerCardRelationshipState newState) {
    _state = newState;
    notifyListeners();
  }

  void _cancelListeners() {
    for (final sub in _followGraphSubscriptions) {
      sub.cancel();
    }
    _followGraphSubscriptions.clear();
    _relationshipRefreshDebounce?.cancel();
    _relationshipRefreshDebounce = null;
  }

  @override
  void dispose() {
    _cancelListeners();
    super.dispose();
  }
}
