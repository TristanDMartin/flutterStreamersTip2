import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../components/onboarding/onboarding_feature_tip.dart';
import '../components/onboarding/onboarding_tester_config.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import '../services/first_steps_achievement_service.dart';
import '../services/robust_auth_service.dart';
import '../widgets/inbox_view_optimized.dart';
import '../widgets/profile_view_optimized.dart';
import '../widgets/custom_bottom_nav.dart';
import '../views/network_view.dart';
import 'home_view.dart';
import '../models/user.dart';
import '../services/network_view_model_advanced.dart';
import '../services/profile_update_service.dart';
import '../services/clean_relationship_service.dart';
import '../providers/home_provider.dart';
import '../providers/feed_state_provider.dart';
import '../providers/product_tour_ui_provider.dart';
import '../services/global_playback_manager.dart';
import '../routing/app_routes.dart';
import '../constants/playback_owners.dart';
import 'package:streamers_tip/qa/qa_runtime.dart';
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
  late PageController _pageController;
  late NetworkViewModelAdvanced _networkViewModel;
  late HomeViewReactivateNotifier _homeReactivateNotifier;
  late RobustAuthenticationService _authService;
  ProviderSubscription<int?>? _productTourTabSubscription;

  // ⏱️ MEMORY FIX: Timers for proper cancellation
  Timer? _unblockTimer;
  Timer? _cameraNavTimer;
  Timer? _dataSyncRetryTimer;
  bool _dataSyncStarted = false;
  bool _dataSyncCompleted = false;
  bool _firstStepsToastChecked = false;
  final GlobalKey _homeViewKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentIndex = widget.initialTabIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _networkViewModel = NetworkViewModelAdvanced();
    _homeReactivateNotifier = ref.read(homeViewReactivateProvider.notifier);
    _authService = ref.read(robustAuthServiceProvider);
    _productTourTabSubscription = ref.listenManual<int?>(
      productTourMainTabIndexRequestProvider,
      (int? previous, int? next) {
        _handleMainTabIndexRequest(
            next, productTourMainTabIndexRequestProvider);
      },
    );
    ref.listenManual<int?>(
      mainTabIndexRequestProvider,
      (int? previous, int? next) {
        _handleMainTabIndexRequest(next, mainTabIndexRequestProvider);
      },
    );
    _startDataSync();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncPlaybackForCurrentTab();
      unawaited(_maybeShowFirstStepsAchievementToast());
      if (!QaRuntime.isMobileFeedE2e) {
        Future<void>.delayed(const Duration(milliseconds: 900), () {
          if (!context.mounted || _currentIndex != 0) return;
          unawaited(_showFirstTapTipIfNeeded(0));
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _productTourTabSubscription?.close();
    // ⏱️ MEMORY FIX: Cancel all timers to prevent memory leaks
    _unblockTimer?.cancel();
    _cameraNavTimer?.cancel();
    _dataSyncRetryTimer?.cancel();
    _pageController.dispose();
    _networkViewModel.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state != AppLifecycleState.resumed || !mounted) {
      return;
    }

    _cameraNavTimer?.cancel();
    _syncPlaybackForCurrentTab();
    setState(() {});

    unawaited(
      GlobalPlaybackManager.instance.recoverInteractionOnAppResume(
        fallbackOwner:
            _currentIndex == 0 ? PlaybackOwners.home : PlaybackOwners.network,
      ),
    );
  }

  void _requestHomeReactivation(String reason) {
    if (!mounted) return;
    if (_currentIndex != 0) return;
    _homeReactivateNotifier.triggerReactivation();
    secureLog('▶️ MainTabView: Requested HomeView reactivation ($reason)');
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
      try {
        await CleanRelationshipService().initialize();
      } catch (e) {
        secureLog('⚠️ MainTabView: Clean relationship startup deferred: $e');
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
      setState(() => _currentIndex = next);
      _pageController.jumpToPage(next);
      _syncPlaybackForCurrentTab();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref.read(provider.notifier).state = null;
    });
  }

  Future<void> _onTabTapped(int index) async {
    // Handle the creation screen (index 2) specially
    if (index == 2) {
      unawaited(_showFirstTapTipIfNeeded(index));
      _onUploadTapped();
      return;
    }

    // Handle Home tab (index 0) - refresh video feed if already on Home
    if (index == 0 && _currentIndex == 0) {
      _refreshHomeView();
      return;
    }

    // Silence Home immediately when leaving it for another tab so audio
    // cannot leak during the page animation into Network or other views.
    if (_currentIndex == 0 && index != 0) {
      _pauseAllHomeViewVideos(
        nextOwner: index == 1 ? PlaybackOwners.network : null,
      );
    }

    setState(() {
      _currentIndex = index;
    });

    _pageController.jumpToPage(index);
    _syncPlaybackForCurrentTab();

    if (index != 0) {
      unawaited(_showFirstTapTipIfNeeded(index));
    }
  }

  Future<bool> _showFirstTapTipIfNeeded(int index) async {
    if (QaRuntime.isMobileFeedE2e || !context.mounted) {
      return true;
    }
    final OnboardingFeatureTip? tip = OnboardingFeatureTip.forTabIndex(index);
    if (tip == null) {
      return true;
    }
    final authService = ref.read(robustAuthServiceProvider);
    final String userId = authService.currentUser?.id ?? 'local';
    final bool forceShow = OnboardingTesterConfig.isTesterUser(
      userId: userId,
      username: authService.currentUser?.username,
    );
    if (!mounted) {
      return false;
    }
    return showOnboardingFeatureTipIfNeeded(
      context: context,
      userId: userId,
      tip: tip,
      forceShow: forceShow,
    );
  }

  void _syncPlaybackForCurrentTab() {
    if (!mounted) return;
    final playbackManager = GlobalPlaybackManager.instance;
    if (_currentIndex == 0) {
      playbackManager.setVisibleOwner(PlaybackOwners.home);
      playbackManager.resumeAfterTabSwitch();
      _requestHomeReactivation('tab_sync');
      return;
    }

    playbackManager.setVisibleOwner(PlaybackOwners.network);
  }

  void _onUploadTapped() {
    // Pause HomeView videos before navigating to CameraView
    secureLog('🚨 CAMERA NAVIGATION: Tap detected!');
    _pauseAllHomeViewVideos();

    secureLog('🚨 CAMERA NAVIGATION: About to call Navigator.push');
    // AUDIO FIX: Add delay to ensure disposal completes before navigation
    _cameraNavTimer = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      // Navigate directly to StreamersTip camera view
      Navigator.of(context).pushNamed(AppRoutes.camera).then((_) {
        if (!mounted) return;
        _syncPlaybackForCurrentTab();
      });
    });
    secureLog('🚨 CAMERA NAVIGATION: Navigator.push completed');
  }

  void _refreshHomeView() {
    try {
      // Refresh the home provider to reload videos
      final homeNotifier = ref.read(homeProvider.notifier);
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

      // 🔊 AUDIO FIX: Use GlobalPlaybackManager for consistent audio control
      final playbackManager = ref.read(globalPlaybackManagerProvider);
      if (nextOwner != null) {
        playbackManager.setVisibleOwner(nextOwner);
      } else {
        playbackManager.pauseAllForTabSwitch(); // Pause + mute all videos
      }
      // ❌ REMOVED: playbackManager.disposeAll() - too aggressive, causes disposal errors

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
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final Color on = colorScheme.onSurface;
    final Widget shell = Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBody:
          true, // This allows content to extend behind the bottom navigation
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          if (_currentIndex != index) {
            setState(() {
              _currentIndex = index;
            });
          }

          _syncPlaybackForCurrentTab();
        },
        // Disable horizontal swipe on Home / Network so nested horizontal
        // gestures (e.g. StreamerCardView) are not stolen.
        physics: _currentIndex == 0 || _currentIndex == 1
            ? const NeverScrollableScrollPhysics()
            : const ClampingScrollPhysics(),
        children: [
          HomeView(key: _homeViewKey),
          NetworkView(),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
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

  Future<void> _maybeShowFirstStepsAchievementToast() async {
    if (_firstStepsToastChecked || !mounted) {
      return;
    }
    _firstStepsToastChecked = true;
    final fa.User? user = fa.FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
    try {
      final DocumentSnapshot<Map<String, dynamic>> snap =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
      final Map<String, dynamic>? data = snap.data();
      final Map<String, dynamic>? onboarding =
          (data?['onboarding'] as Map?)?.cast<String, dynamic>();
      final bool levelOneDone = onboarding?['hasCompletedLevelOne'] == true;
      final List<String> completedMissions =
          (onboarding?['completedMissions'] as List?)
                  ?.map((Object? e) => e.toString())
                  .toList() ??
              <String>[];
      final bool hasFirstPostMission =
          completedMissions.contains('upload_first_post');
      final bool eligible = levelOneDone || hasFirstPostMission;
      if (!mounted) {
        return;
      }
      await FirstStepsAchievementService.instance.maybeShowToast(
        context: context,
        uid: user.uid,
        isEligible: eligible,
      );
    } catch (e) {
      secureLog('First Steps achievement toast skipped: $e');
    }
  }
}
