import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

import '../components/onboarding/product_tour_target_keys.dart';
import '../models/user.dart' as app_user;
import '../providers/follow_refresh_provider.dart';
import '../routing/app_navigator.dart';
import '../services/profile_update_service.dart';
import '../services/user_blocking_service.dart';
import '../utils/avatar_url_resolver.dart';
import 'profile_back_view.dart';
import 'profile_view/profile_post_count_reconcile.dart';
import 'profile_view/profile_user_data_cache.dart';
import 'profile_view/profile_view_front_shell.dart';

class ProfileViewOptimized extends ConsumerStatefulWidget {
  const ProfileViewOptimized({
    super.key,
    required this.user,
    required this.isCurrentUser,
  });

  final app_user.User user;
  final bool isCurrentUser;

  @override
  ConsumerState<ProfileViewOptimized> createState() =>
      _ProfileViewOptimizedState();
}

class _ProfileViewOptimizedState extends ConsumerState<ProfileViewOptimized>
    with TickerProviderStateMixin {
  late AnimationController _segmentedController;
  late AnimationController _contentTransitionController;
  late Animation<double> _contentFadeAnimation;
  late Animation<Offset> _contentSlideAnimation;
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  bool _isDisposed = false;
  int _selectedTabIndex = 0;
  bool _isFront = true;
  ProfileUpdateService? _profileUpdateService;
  final ProfileUserDataCache _userDataCache = ProfileUserDataCache();
  final UserBlockingService _blockingService = UserBlockingService();
  Timer? _rebuildDebounceTimer;
  ProviderSubscription<int>? _followRefreshSubscription;

  @override
  void initState() {
    super.initState();
    _segmentedController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _contentTransitionController = AnimationController(
      duration: const Duration(milliseconds: 240),
      vsync: this,
    );
    _contentFadeAnimation = CurvedAnimation(
      parent: _contentTransitionController,
      curve: Curves.easeOutCubic,
    );
    _contentSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.03),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _contentTransitionController,
        curve: Curves.easeOutCubic,
      ),
    );
    _contentTransitionController.value = 1.0;
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _flipAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
    _profileUpdateService = ProfileUpdateService();
    _profileUpdateService?.addProfileViewListener(_onProfileUpdated);
    _blockingService.blockListRevision.addListener(_handleBlockListChanged);
    _followRefreshSubscription = ref.listenManual<int>(
      followRefreshProvider,
      (int? previous, int next) {
        if (previous == next || !mounted) {
          return;
        }
        setState(() {
          _userDataCache.markDirty();
        });
      },
    );
    ProfilePostCountReconcile.reconcileIfStale(
      userId: widget.user.id,
      isCurrentUser: widget.isCurrentUser,
    );
  }

  @override
  void didUpdateWidget(covariant ProfileViewOptimized oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id) {
      _userDataCache.resetForNewProfile();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _rebuildDebounceTimer?.cancel();
    _blockingService.blockListRevision.removeListener(_handleBlockListChanged);
    _followRefreshSubscription?.close();
    _profileUpdateService?.removeProfileViewListener(_onProfileUpdated);
    _segmentedController.dispose();
    _contentTransitionController.dispose();
    _flipController.dispose();
    super.dispose();
  }

  void _onProfileUpdated() {
    _rebuildDebounceTimer?.cancel();
    _rebuildDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted || _isDisposed) {
        return;
      }
      _userDataCache.markDirty();
      _userDataCache.onProfileServiceAvatarHint(
        resolveAvatarUrl(_profileUpdateService?.userData),
      );
      setState(() {});
      if (kDebugMode) {
        debugPrint('🔄 ProfileView: profile data updated');
      }
    });
  }

  void _handleBlockListChanged() {
    if (widget.isCurrentUser) {
      return;
    }
    unawaited(_dismissIfViewingBlockedProfile());
  }

  Future<void> _dismissIfViewingBlockedProfile() async {
    final blockedUserIds = await _blockingService.getBlockedUsers();
    if (!mounted || !blockedUserIds.contains(widget.user.id)) {
      return;
    }

    Navigator.of(context).maybePop();
  }

  void _flipCard() {
    HapticFeedback.lightImpact();
    if (_isFront) {
      _flipController.forward();
    } else {
      _flipController.reverse();
    }
    _isFront = !_isFront;
  }

  void _openStreamerCard() {
    HapticFeedback.lightImpact();
    try {
      AppNavigator.openStreamerCard(
        context,
        userId: widget.user.id,
        currentUserId: _profileUpdateService?.currentUser?.uid,
        onDismiss: () => Navigator.of(context).pop(),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening profile: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Map<String, dynamic> _getCurrentUserData() {
    return _userDataCache.resolve(
      profileUser: widget.user,
      updateService: _profileUpdateService,
    );
  }

  void _onTabSelected(int index) {
    if (_selectedTabIndex == index) {
      return;
    }
    HapticFeedback.lightImpact();
    setState(() {
      _selectedTabIndex = index;
    });
    _segmentedController.forward().then((_) {
      _segmentedController.reset();
    });
    _contentTransitionController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> userData = _getCurrentUserData();
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: KeyedSubtree(
        key: ProductTourTargetKeys.profile,
        child: AnimatedBuilder(
          animation: _flipAnimation,
          builder: (BuildContext context, Widget? child) {
            final bool isShowingFront = _flipAnimation.value < 0.5;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(_flipAnimation.value * 3.14159),
              child: isShowingFront
                  ? ProfileViewFrontShell(
                      userData: userData,
                      profileUserId: widget.user.id,
                      isCurrentUser: widget.isCurrentUser,
                      selectedTabIndex: _selectedTabIndex,
                      onTabSelected: _onTabSelected,
                      contentFade: _contentFadeAnimation,
                      contentSlide: _contentSlideAnimation,
                      onBack: () => Navigator.of(context).pop(),
                      onFlip: _flipCard,
                      onStreamerCard: _openStreamerCard,
                    )
                  : Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..rotateY(3.14159),
                      child: ProfileBackView(
                        user: userData,
                        onFlip: _flipCard,
                      ),
                    ),
            );
          },
        ),
      ),
    );
  }
}
