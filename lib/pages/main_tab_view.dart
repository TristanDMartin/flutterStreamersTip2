import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../components/onboarding/onboarding_feature_tip.dart';
import '../services/robust_auth_service.dart';
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

class MainTabView extends ConsumerStatefulWidget {
  const MainTabView({super.key, this.initialTabIndex = 0});

  final int initialTabIndex;

  @override
  ConsumerState<MainTabView> createState() => _MainTabViewState();
}

class _MainTabViewState extends ConsumerState<MainTabView> {
  late int _currentIndex;
  late PageController _pageController;
  late NetworkViewModelAdvanced _networkViewModel;
  ProviderSubscription<int?>? _productTourTabSubscription;

  // ⏱️ MEMORY FIX: Timers for proper cancellation
  Timer? _unblockTimer;
  Timer? _cameraNavTimer;
  Timer? _inboxNavTimer;
  Timer? _profileNavTimer;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _networkViewModel = NetworkViewModelAdvanced();
    _productTourTabSubscription = ref.listenManual<int?>(
      productTourMainTabIndexRequestProvider,
      (int? previous, int? next) {
        if (next == null) {
          return;
        }
        if (!mounted) {
          return;
        }
        if (_currentIndex != next) {
          _onTabTapped(next);
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          ref.read(productTourMainTabIndexRequestProvider.notifier).state =
              null;
        });
      },
    );
    _startDataSync();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncPlaybackForCurrentTab();
    });
  }

  @override
  void dispose() {
    _productTourTabSubscription?.close();
    // ⏱️ MEMORY FIX: Cancel all timers to prevent memory leaks
    _unblockTimer?.cancel();
    _cameraNavTimer?.cancel();
    _inboxNavTimer?.cancel();
    _profileNavTimer?.cancel();
    _pageController.dispose();
    _networkViewModel.dispose();
    super.dispose();
  }

  void _requestHomeReactivation(String reason) {
    if (!mounted) return;
    if (_currentIndex != 0) return;
    ref.read(homeViewReactivateProvider.notifier).triggerReactivation();
    log('▶️ MainTabView: Requested HomeView reactivation ($reason)');
  }

  void _startDataSync() {
    // Initialize data synchronization after login
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // Initialize clean relationship service
      await CleanRelationshipService().initialize();
      if (!mounted) return;

      final authService = ref.read(robustAuthServiceProvider);
      if (authService.isLoggedIn && authService.currentUser != null) {
        // Initialize ProfileUpdateService for cross-view updates
        try {
          final profileUpdateService = ProfileUpdateService();
          await profileUpdateService.initialize();
          log(
            '✅ MainTabView: ProfileUpdateService initialized for user: ${authService.currentUser!.displayName}',
          );
        } catch (e) {
          log('❌ MainTabView: Error initializing ProfileUpdateService: $e');
        }

        // Data sync will be handled by the individual views
        log(
          '🔄 MainTabView: Starting data sync for user: ${authService.currentUser!.displayName}',
        );
      }
    });
  }

  Future<void> _onTabTapped(int index) async {
    if (index != 0) {
      final bool shouldContinue = await _showFirstTapTipIfNeeded(index);
      if (!shouldContinue || !mounted) {
        return;
      }
    }

    // Handle the creation screen (index 2) specially
    if (index == 2) {
      _onUploadTapped();
      return;
    }

    // Handle the inbox view (index 3) specially - navigate to full screen
    if (index == 3) {
      _onInboxTapped();
      return;
    }

    // Handle the profile view (index 4) specially - navigate to full screen
    if (index == 4) {
      _onProfileTapped();
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

    _pageController
        .animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    )
        .then((_) {
      if (!mounted) return;
      _syncPlaybackForCurrentTab();
    });
  }

  Future<bool> _showFirstTapTipIfNeeded(int index) async {
    final OnboardingFeatureTip? tip = OnboardingFeatureTip.forTabIndex(index);
    if (tip == null) {
      return true;
    }
    if (!mounted) {
      return false;
    }
    final authService = ref.read(robustAuthServiceProvider);
    final String userId = authService.currentUser?.id ?? 'local';
    if (!mounted) {
      return false;
    }
    return showOnboardingFeatureTipIfNeeded(
      context: context,
      userId: userId,
      tip: tip,
    );
  }

  void _syncPlaybackForCurrentTab() {
    if (!mounted) return;
    final playbackManager = GlobalPlaybackManager.instance;
    if (_currentIndex == 0) {
      _requestHomeReactivation('tab_sync');
      return;
    }

    playbackManager.setActiveOwner(PlaybackOwners.network);
  }

  void _onUploadTapped() {
    // Pause HomeView videos before navigating to CameraView
    log('🚨 CAMERA NAVIGATION: Tap detected!');
    _pauseAllHomeViewVideos();

    log('🚨 CAMERA NAVIGATION: About to call Navigator.push');
    // AUDIO FIX: Add delay to ensure disposal completes before navigation
    _cameraNavTimer = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      // Navigate directly to StreamersTip camera view
      Navigator.of(context).pushNamed(AppRoutes.camera).then((_) {
        if (!mounted) return;
        _syncPlaybackForCurrentTab();
      });
    });
    log('🚨 CAMERA NAVIGATION: Navigator.push completed');
  }

  void _onInboxTapped() {
    // AUDIO FIX: Pause HomeView videos before navigating to InboxView
    log('🚨 INBOX NAVIGATION: Starting aggressive video disposal...');
    _pauseAllHomeViewVideos();

    // AUDIO FIX: Add delay to ensure disposal completes before navigation
    _inboxNavTimer = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      // Navigate to inbox view as full screen
      Navigator.of(context).pushNamed(AppRoutes.inbox).then((_) {
        if (!mounted) return;
        _syncPlaybackForCurrentTab();
      });
    });
  }

  void _onProfileTapped() {
    // AUDIO FIX: Pause HomeView videos before navigating to ProfileView
    log('🚨 PROFILE NAVIGATION: Starting aggressive video disposal...');
    _pauseAllHomeViewVideos();

    // Navigate to profile view as full screen
    final authService = ref.read(robustAuthServiceProvider);
    if (authService.currentUser != null) {
      debugPrint(
        "🔍 MainTabView: Creating User object with ID: ${authService.currentUser!.id}",
      );
      debugPrint(
        "🔍 MainTabView: AuthService currentUser: ${authService.currentUser}",
      );

      final user = User(
        id: authService.currentUser!.id,
        username: authService.currentUser!.username,
        displayName: authService.currentUser!.displayName,
        bio: authService.currentUser!.bio,
        avatarURL: authService.currentUser!.avatarURL,
        onlineStatus: authService.currentUser!.onlineStatus,
        hashtags: authService.currentUser!.hashtags,
        aiSelf: authService.currentUser!.aiSelf,
        calendarEvents: authService.currentUser!.calendarEvents,
      );

      debugPrint("🔍 MainTabView: Created User object with ID: ${user.id}");

      // AUDIO FIX: Add delay to ensure disposal completes before navigation
      _profileNavTimer = Timer(const Duration(milliseconds: 200), () {
        if (!mounted) return;
        Navigator.of(context)
            .push(
          MaterialPageRoute(
            builder: (context) =>
                ProfileViewOptimized(user: user, isCurrentUser: true),
            fullscreenDialog: true,
            settings: const RouteSettings(name: '/profile'),
          ),
        )
            .then((_) {
          if (!mounted) return;
          _syncPlaybackForCurrentTab();
        });
      });
    }
  }

  void _refreshHomeView() {
    try {
      // Refresh the home provider to reload videos
      final homeNotifier = ref.read(homeProvider.notifier);
      homeNotifier.loadVideos();

      log('🔄 MainTabView: Refreshing HomeView video feed');
      debugPrint('🔄 MainTabView: Refreshing HomeView video feed');

      // Provide haptic feedback
      HapticFeedback.lightImpact();
    } catch (e) {
      log('❌ MainTabView: Error refreshing HomeView: $e');
      debugPrint('❌ MainTabView: Error refreshing HomeView: $e');
    }
  }

  void _pauseAllHomeViewVideos({String? nextOwner}) {
    try {
      log('🚨 AUDIO FIX: Pausing HomeView videos for tab switch...');

      // 🔊 AUDIO FIX: Use GlobalPlaybackManager for consistent audio control
      final playbackManager = ref.read(globalPlaybackManagerProvider);
      if (nextOwner != null) {
        playbackManager.setActiveOwner(nextOwner);
      } else {
        playbackManager.pauseAllForTabSwitch(); // Pause + mute all videos
      }
      // ❌ REMOVED: playbackManager.disposeAll() - too aggressive, causes disposal errors

      log(
        '⏸️ MainTabView: Paused all HomeView videos (controllers kept alive)',
      );
      debugPrint(
        '⏸️ MainTabView: Paused all HomeView videos (controllers kept alive)',
      );
    } catch (e) {
      log('❌ MainTabView: Error pausing HomeView videos: $e');
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
          setState(() {
            _currentIndex = index;
          });

          _syncPlaybackForCurrentTab();
        },
        // Disable horizontal swipe on Home / Network so nested horizontal
        // gestures (e.g. StreamerCardView) are not stolen.
        physics: _currentIndex == 0 || _currentIndex == 1
            ? const NeverScrollableScrollPhysics()
            : const ClampingScrollPhysics(),
        children: [
          HomeView(),
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
          Center(
            child: Icon(
              Icons.mail_outline,
              size: 80,
              color: on.withValues(alpha: 0.45),
            ),
          ),
          Center(
            child: Icon(
              Icons.account_circle_outlined,
              size: 80,
              color: on.withValues(alpha: 0.45),
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
}
