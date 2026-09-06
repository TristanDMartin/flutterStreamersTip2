import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../components/onboarding/contextual_tip_overlay.dart';
import '../components/onboarding/contextual_tips_service.dart';
import '../services/robust_auth_service.dart';
import '../widgets/inbox_view_optimized.dart';
import '../widgets/profile_view_optimized.dart';
import '../widgets/custom_bottom_nav.dart';
import '../views/network_view.dart';
import 'home_view.dart';
import '../models/user.dart';
import '../services/network_view_model_advanced.dart';
import '../services/profile_update_service.dart';
import '../features/home/application/home_first_frame_gate.dart';
import 'package:streamers_tip/utils/like_interaction_boundary.dart';
import '../services/clean_relationship_service.dart';
import '../providers/feed_state_provider.dart';
import '../providers/main_tab_provider.dart';
import '../providers/unread_messages_provider.dart';
import '../providers/home_provider.dart' as hp;
import '../features/billing/subscription_provider.dart';
import '../features/main_tabs/application/main_tab_background_refresh.dart';
import '../controllers/home_view_controller.dart';
import '../services/global_playback_manager.dart';
import '../routing/app_routes.dart';
import '../constants/playback_owners.dart';
import '../widgets/upload_status_bar.dart';
import 'package:streamers_tip/qa/qa_runtime.dart';
import 'package:streamers_tip/utils/interaction_diagnostics.dart';
import 'package:streamers_tip/utils/secure_log.dart';

class MainTabView extends ConsumerStatefulWidget {
  const MainTabView({super.key, this.initialTabIndex = 0});

  final int initialTabIndex;

  @override
  ConsumerState<MainTabView> createState() => _MainTabViewState();
}

class _MainTabViewState extends ConsumerState<MainTabView>
    with WidgetsBindingObserver {
  late int _currentIndex;
  late NetworkViewModelAdvanced _networkViewModel;
  final MainTabBackgroundRefreshScheduler _tabRefreshScheduler =
      MainTabBackgroundRefreshScheduler();
  late RobustAuthenticationService _authService;

  // ⏱️ MEMORY FIX: Timers for proper cancellation
  Timer? _unblockTimer;
  Timer? _cameraNavTimer;
  Timer? _dataSyncRetryTimer;
  bool _dataSyncStarted = false;
  bool _dataSyncCompleted = false;
  final GlobalKey _homeViewKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentIndex = widget.initialTabIndex;
    _networkViewModel = NetworkViewModelAdvanced();
    _authService = ref.read(robustAuthServiceProvider);
    ref.listenManual<int?>(
      mainTabIndexRequestProvider,
      (int? previous, int? next) {
        _handleMainTabIndexRequest(next, mainTabIndexRequestProvider);
      },
    );
    _startDataSync();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(mainTabActiveIndexProvider.notifier).setIndex(_currentIndex);
      _syncPlaybackForCurrentTab();
      if (!QaRuntime.isMobileFeedE2e) {
        Future<void>.delayed(const Duration(milliseconds: 900), () {
          if (!mounted || _currentIndex != 0) return;
          unawaited(_showFirstTapTipIfNeeded(0));
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // ⏱️ MEMORY FIX: Cancel all timers to prevent memory leaks
    _unblockTimer?.cancel();
    _cameraNavTimer?.cancel();
    _dataSyncRetryTimer?.cancel();
    _tabRefreshScheduler.dispose();
    _networkViewModel.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state != AppLifecycleState.resumed) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      try {
        invalidateSubscriptionEntitlements(ref);
      } catch (error) {
        debugPrint(
          'MainTabView: skipped resume entitlements after lifecycle: $error',
        );
      }
      _cameraNavTimer?.cancel();
      if (_currentIndex != 0) {
        _syncPlaybackForCurrentTab();
      }
    });
  }

  void _startDataSync() {
    if (_dataSyncCompleted || _dataSyncStarted) {
      return;
    }
    _dataSyncStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        _dataSyncStarted = false;
        return;
      }
      if (_dataSyncCompleted) {
        return;
      }
      if (Firebase.apps.isEmpty) {
        _dataSyncStarted = false;
        _dataSyncRetryTimer?.cancel();
        _dataSyncRetryTimer = Timer(const Duration(milliseconds: 500), () {
          if (mounted) {
            _startDataSync();
          }
        });
        return;
      }
      _dataSyncCompleted = true;
      HomeFirstFrameGate.instance.runAfterFirstFrame(() {
        Timer(const Duration(seconds: 5), () async {
          if (!mounted) {
            return;
          }
          try {
            await CleanRelationshipService().initialize();
          } catch (e) {
            secureLog(
                '⚠️ MainTabView: Clean relationship startup deferred: $e');
          }
          if (!mounted) {
            return;
          }
          if (_authService.isLoggedIn && _authService.currentUser != null) {
            try {
              final ProfileUpdateService profileUpdateService =
                  ProfileUpdateService();
              await profileUpdateService.initialize();
              secureLog(
                '✅ MainTabView: ProfileUpdateService initialized for user: ${_authService.currentUser!.displayName}',
              );
            } catch (e) {
              secureLog(
                  '❌ MainTabView: Error initializing ProfileUpdateService: $e');
            }
            secureLog(
              '🔄 MainTabView: Starting data sync for user: ${_authService.currentUser!.displayName}',
            );
          }
        });
      });
    });
  }

  void _handleMainTabIndexRequest(
    int? next,
    StateProvider<int?> provider,
  ) {
    if (next == null) {
      return;
    }
    if (!mounted) {
      return;
    }
    if (_currentIndex != next) {
      _activateTab(next, previousIndex: _currentIndex);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref.read(provider.notifier).state = null;
    });
  }

  Future<void> _onTabTapped(int index) async {
    LikeInteractionBoundary.markFirstUserInteraction();
    InteractionDiagnostics.logBottomNavTap(index: index, blocked: false);
    if (index == 2) {
      unawaited(_showFirstTapTipIfNeeded(index));
      _onUploadTapped();
      return;
    }

    if (index == 0 && _currentIndex == 0) {
      _refreshHomeView();
      return;
    }

    if (_currentIndex == index) {
      return;
    }

    _activateTab(index, previousIndex: _currentIndex);

    if (index != 0) {
      unawaited(_showFirstTapTipIfNeeded(index));
    }
  }

  void _activateTab(int index, {required int previousIndex}) {
    if (_currentIndex == 0 && index != 0) {
      ref.read(homeViewControllerProvider.notifier).prepareForTabSwitchAway(
            reason: 'main_tab_$index',
            nextActiveOwner: _playbackOwnerForTab(index),
          );
    }

    setState(() => _currentIndex = index);
    ref.read(mainTabActiveIndexProvider.notifier).setIndex(index);
    _syncPlaybackForCurrentTab();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _currentIndex != index) {
        return;
      }
      _scheduleBackgroundRefreshForTab(index);
    });
  }

  String? _playbackOwnerForTab(int index) {
    return switch (index) {
      0 => PlaybackOwners.home,
      1 => PlaybackOwners.network,
      4 => PlaybackOwners.profile,
      _ => null,
    };
  }

  void _scheduleBackgroundRefreshForTab(int index) {
    _tabRefreshScheduler.schedule(
      tabIndex: index,
      currentTabIndex: _currentIndex,
      isMounted: () => mounted,
      refresh: () => _runBackgroundRefreshForTab(index),
    );
  }

  Future<void> _runBackgroundRefreshForTab(int index) async {
    switch (index) {
      case 0:
        final hp.HomeState homeState = ref.read(hp.homeProvider);
        if (homeState.forYouVideos.isEmpty) {
          return;
        }
        await ref.read(hp.homeProvider.notifier).runDeferredBackgroundRefresh();
      case 1:
        ref.read(networkTabBackgroundRefreshProvider.notifier).requestRefresh();
      case 3:
        ref.read(inboxTabBackgroundRefreshProvider.notifier).requestRefresh();
      default:
        break;
    }
  }

  Future<bool> _showFirstTapTipIfNeeded(int index) async {
    if (QaRuntime.isMobileFeedE2e || !context.mounted) {
      return true;
    }
    final RobustAuthenticationService authService =
        ref.read(robustAuthServiceProvider);
    final String? userId = authService.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      return true;
    }
    final ContextualTipsService tipsService = ContextualTipsService();
    final ContextualTipsState tipsState = await tipsService.fetchTips(userId);
    if (!mounted) {
      return false;
    }
    await ContextualTipCatalog.showTabTipIfNeeded(
      context: context,
      userId: userId,
      tabIndex: index,
      service: tipsService,
      tipsState: tipsState,
    );
    return true;
  }

  void _syncPlaybackForCurrentTab() {
    if (!mounted) return;
    final GlobalPlaybackManager playbackManager =
        GlobalPlaybackManager.instance;
    final String? owner = _playbackOwnerForTab(_currentIndex);
    if (owner == null) {
      playbackManager.pauseAllForTabSwitch();
      return;
    }
    if (_currentIndex == 0) {
      ref.read(homeViewControllerProvider.notifier).resumeFromTabReturn();
      return;
    }
    playbackManager.setVisibleOwner(owner);
  }

  void _onUploadTapped() {
    secureLog('🚨 CAMERA NAVIGATION: Tap detected!');
    _pauseAllHomeViewVideos();
    _cameraNavTimer?.cancel();
    Navigator.of(context).pushNamed(AppRoutes.camera).then((_) {
      if (!mounted) return;
      _syncPlaybackForCurrentTab();
    });
  }

  void _refreshHomeView() {
    try {
      // Refresh the home provider to reload videos
      final homeNotifier = ref.read(hp.homeProvider.notifier);
      homeNotifier.loadVideos();

      secureLog('🔄 MainTabView: Refreshing HomeView video feed');
      debugPrint('🔄 MainTabView: Refreshing HomeView video feed');

      // Provide haptic feedback
      HapticFeedback.lightImpact();
    } catch (e) {
      secureLog('❌ MainTabView: Error refreshing HomeView: $e');
      debugPrint('❌ MainTabView: Error refreshing HomeView: $e');
    }
  }

  void _pauseAllHomeViewVideos({String? nextOwner}) {
    try {
      secureLog('🚨 AUDIO FIX: Pausing HomeView videos for tab switch...');
      ref.read(homeViewControllerProvider.notifier).prepareForTabSwitchAway(
            reason: 'pause_home_videos',
            nextActiveOwner: nextOwner,
          );
      secureLog(
        '⏸️ MainTabView: Paused all HomeView videos (controllers kept alive)',
      );
      debugPrint(
        '⏸️ MainTabView: Paused all HomeView videos (controllers kept alive)',
      );
    } catch (e) {
      secureLog('❌ MainTabView: Error pausing HomeView videos: $e');
      debugPrint('❌ MainTabView: Error pausing HomeView videos: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(unreadMessagesProvider);
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final Color on = colorScheme.onSurface;
    final Widget shell = Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBody:
          true, // This allows content to extend behind the bottom navigation
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          IndexedStack(
            index: _currentIndex,
            sizing: StackFit.expand,
            children: <Widget>[
              HomeView(key: _homeViewKey),
              const NetworkView(),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      Icons.add_circle,
                      size: 80,
                      color: on.withValues(alpha: 0.45),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Create Content',
                      style: TextStyle(
                        fontSize: 24,
                        color: on.withValues(alpha: 0.6),
                      ),
                    ),
                    Text(
                      'Tap the + button',
                      style: TextStyle(
                        fontSize: 16,
                        color: on.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              const InboxViewOptimized(),
              _buildCurrentUserProfileTab(on),
            ],
          ),
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: UploadStatusBar(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
      ),
    );
    return shell;
  }

  Widget _buildCurrentUserProfileTab(Color onColor) {
    final authService = ref.watch(robustAuthServiceProvider);
    final User? user = authService.currentUser;
    if (user == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Log in to view your profile',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: onColor.withValues(alpha: 0.72),
            ),
          ),
        ),
      );
    }
    return ProfileViewOptimized(
      user: user,
      isCurrentUser: true,
    );
  }
}
