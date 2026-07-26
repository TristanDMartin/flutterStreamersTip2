import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import '../models/creator_profile_snapshot.dart';
import '../models/user.dart';
import '../routing/app_navigator.dart';
import '../services/user_blocking_service.dart';
import 'network_view_controller.dart';
import 'network_view_sections.dart';
import 'screen_feedback_state.dart';

class NetworkView extends StatefulWidget {
  const NetworkView({super.key});

  @override
  State<NetworkView> createState() => _NetworkViewState();
}

class _NetworkViewState extends State<NetworkView>
    with TickerProviderStateMixin {
  late final TabController _tabController;
  late final NetworkViewController _controller;
  final UserBlockingService _blockingService = UserBlockingService();
  String? _actionError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _controller = NetworkViewController()
      ..addListener(_handleControllerChanged);
    _blockingService.blockListRevision.addListener(_handleBlockListChanged);
    _controller.initialize();
  }

  @override
  void dispose() {
    _blockingService.blockListRevision.removeListener(_handleBlockListChanged);
    _controller
      ..removeListener(_handleControllerChanged)
      ..dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleBlockListChanged() {
    _controller.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;

    return Scaffold(
      backgroundColor: const Color(0xFF090312),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            NetworkViewHeader(
              onRefresh: _controller.refresh,
              isRefreshing: state.isLoading,
            ),
            if (_actionError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: ScreenInlineErrorBanner(
                  message: _actionError!,
                  onDismiss: () {
                    if (mounted) {
                      setState(() => _actionError = null);
                    }
                  },
                ),
              ),
            NetworkViewTabBarCard(controller: _tabController),
            Expanded(
              child: state.isLoading
                  ? const NetworkViewLoadingState()
                  : state.error != null
                      ? NetworkViewErrorState(
                          error: state.error!,
                          onRetry: _controller.refresh,
                        )
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            NetworkUserList(
                              listKind: NetworkListKind.connections,
                              users: state.connections,
                              emptyTitle: 'No connections yet',
                              emptySubtitle:
                                  'Mutual follows will show up here once you and another creator follow each other.',
                              emptyIcon: Icons.people_outline_rounded,
                              pendingActionUserId: state.pendingActionUserId,
                              pendingActionType: state.pendingActionType,
                              onUserTap: _openStreamerCardForUser,
                              onFollow: _handleFollow,
                              onUnfollow: _handleUnfollow,
                              onRemove: _handleRemove,
                            ),
                            NetworkUserList(
                              listKind: NetworkListKind.followers,
                              users: state.followers,
                              emptyTitle: 'No followers yet',
                              emptySubtitle:
                                  'When people discover your profile and follow you, they will appear here.',
                              emptyIcon: Icons.person_search_rounded,
                              pendingActionUserId: state.pendingActionUserId,
                              pendingActionType: state.pendingActionType,
                              onUserTap: _openStreamerCardForUser,
                              onFollow: _handleFollow,
                              onUnfollow: _handleUnfollow,
                              onRemove: _handleRemove,
                            ),
                            NetworkUserList(
                              listKind: NetworkListKind.following,
                              users: state.following,
                              emptyTitle: 'Not following anyone yet',
                              emptySubtitle:
                                  'Follow creators you want to keep up with, and they will be listed here.',
                              emptyIcon: Icons.person_add_disabled_rounded,
                              pendingActionUserId: state.pendingActionUserId,
                              pendingActionType: state.pendingActionType,
                              onUserTap: _openStreamerCardForUser,
                              onFollow: _handleFollow,
                              onUnfollow: _handleUnfollow,
                              onRemove: _handleRemove,
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleFollow(User user) async {
    final feedback = await _controller.follow(user);
    _showActionFeedback(feedback.message, isError: feedback.isError);
  }

  Future<void> _handleUnfollow(User user) async {
    final feedback = await _controller.unfollow(user);
    _showActionFeedback(feedback.message, isError: feedback.isError);
  }

  Future<void> _handleRemove(User user) async {
    final feedback = await _controller.remove(user);
    _showActionFeedback(feedback.message, isError: feedback.isError);
  }

  void _showActionFeedback(String message, {required bool isError}) {
    if (isError) {
      setState(() => _actionError = message);
      return;
    }
    if (_actionError != null) {
      setState(() => _actionError = null);
    }
  }

  void _openStreamerCardForUser(User user) {
    final currentUserId = firebase_auth.FirebaseAuth.instance.currentUser?.uid;

    AppNavigator.openStreamerCard(
      context,
      userId: user.id,
      initialCreator: CreatorProfileSnapshot.fromUser(user),
      currentUserId: currentUserId,
      onDismiss: () => Navigator.of(context).pop(),
    );
  }
}
