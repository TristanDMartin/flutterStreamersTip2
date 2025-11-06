import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/robust_auth_service.dart';
import '../widgets/profile_view_optimized.dart';
import '../widgets/custom_bottom_nav.dart';
import '../widgets/tiktok_camera_view.dart';
import '../views/network_view.dart';
import '../widgets/inbox_view_optimized.dart';
import 'home_view.dart';
import '../models/user.dart';
import '../services/network_view_model_advanced.dart';
import '../services/profile_update_service.dart';
import '../services/clean_relationship_service.dart';
import '../providers/home_provider.dart';
import '../services/global_playback_manager.dart';

class MainTabView extends ConsumerStatefulWidget {
  const MainTabView({super.key});

  @override
  ConsumerState<MainTabView> createState() => _MainTabViewState();
}

class _MainTabViewState extends ConsumerState<MainTabView> {
  int _currentIndex = 0;
  late PageController _pageController;
  late NetworkViewModelAdvanced _networkViewModel;

  // ⏱️ MEMORY FIX: Timers for proper cancellation
  Timer? _unblockTimer;
  Timer? _cameraNavTimer;
  Timer? _inboxNavTimer;
  Timer? _profileNavTimer;
  Timer? _resumeTimer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _networkViewModel = NetworkViewModelAdvanced();
    _startDataSync();
  }

  @override
  void dispose() {
    // ⏱️ MEMORY FIX: Cancel all timers to prevent memory leaks
    _unblockTimer?.cancel();
    _cameraNavTimer?.cancel();
    _inboxNavTimer?.cancel();
    _profileNavTimer?.cancel();
    _resumeTimer?.cancel();

    _pageController.dispose();
    _networkViewModel.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Listen for route changes to detect when returning to HomeView
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkIfReturnedToHomeView();
    });
  }

  void _checkIfReturnedToHomeView() {
    // Check if we're currently on HomeView and no modal is open
    // CRITICAL FIX: Only resume if we're actually on the first route (HomeView)
    // Don't resume if we've navigated to another view via Navigator.push()
    if (_currentIndex == 0 && ModalRoute.of(context)?.isFirst == true) {
      // Additional check: make sure we're not in a pushed route
      final navigator = Navigator.of(context);
      if (navigator.canPop() == false) {
        _resumeHomeViewVideos();
      } else {
        log('🚫 MainTabView: Not resuming video - navigated to another view');
      }
    }
  }

  void _resumeHomeViewVideos() {
    // 🔊 AUDIO FIX: Use GlobalPlaybackManager to resume
    GlobalPlaybackManager.instance.resumeAfterTabSwitch();
    log('▶️ MainTabView: Resumed HomeView videos');
  }

  void _startDataSync() {
    // Initialize data synchronization after login
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Initialize clean relationship service
      await CleanRelationshipService().initialize();

      final authService = ref.read(robustAuthServiceProvider);
      if (authService.isLoggedIn && authService.currentUser != null) {
        // Initialize ProfileUpdateService for cross-view updates
        try {
          final profileUpdateService = ProfileUpdateService();
          await profileUpdateService.initialize();
          log('✅ MainTabView: ProfileUpdateService initialized for user: ${authService.currentUser!.displayName}');
        } catch (e) {
          log('❌ MainTabView: Error initializing ProfileUpdateService: $e');
        }

        // Data sync will be handled by the individual views
        log('🔄 MainTabView: Starting data sync for user: ${authService.currentUser!.displayName}');
      }
    });
  }

  void _onTabTapped(int index) {
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

    // 🔊 AUDIO FIX: Block playback during tab switch using GlobalPlaybackManager
    final playbackManager = GlobalPlaybackManager.instance;
    playbackManager.block(reason: 'tabSwitch');

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
      // Unblock after animation completes
      _unblockTimer = Timer(const Duration(milliseconds: 100), () {
        playbackManager.unblock();
        // Request focus for current video if on home tab
        if (index == 0) {
          _requestFocusForCurrentVideo();
        }
      });
    });
  }

  void _requestFocusForCurrentVideo() {
    // Request focus for the current video when returning to home tab
    log('🎵 MainTabView: Requesting focus for current video');

    try {
      final playbackManager = GlobalPlaybackManager.instance;
      playbackManager.resumeAfterTabSwitch();
      log('✅ MainTabView: Called resumeAfterTabSwitch() for current video');
    } catch (e) {
      log('❌ MainTabView: Error resuming current video: $e');
    }
  }

  void _onUploadTapped() {
    // Pause HomeView videos before navigating to CameraView
    log('🚨 CAMERA NAVIGATION: Tap detected!');
    _pauseAllHomeViewVideos();

    log('🚨 CAMERA NAVIGATION: About to call Navigator.push');
    // AUDIO FIX: Add delay to ensure disposal completes before navigation
    _cameraNavTimer = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      // Navigate directly to TikTok-quality camera view
      Navigator.of(context)
          .push(
        MaterialPageRoute(
          builder: (context) => const TikTokCameraView(),
        ),
      )
          .then((_) {
        // SEAMLESS RETURN: Reactivate HomeView when returning from CameraView
        log('🔄 MainTabView: Returned from CameraView - reactivating HomeView');
        _reactivateHomeView();
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
      Navigator.of(context)
          .push(
        MaterialPageRoute(
          builder: (context) => const InboxViewOptimized(),
          fullscreenDialog: true,
        ),
      )
          .then((_) {
        // SEAMLESS RETURN: Reactivate HomeView when returning from InboxView
        log('🔄 MainTabView: Returned from InboxView - reactivating HomeView');
        _reactivateHomeView();
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
          "🔍 MainTabView: Creating User object with ID: ${authService.currentUser!.id}");
      debugPrint(
          "🔍 MainTabView: AuthService currentUser: ${authService.currentUser}");

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
          ),
        )
            .then((_) {
          // SEAMLESS RETURN: Reactivate HomeView when returning from ProfileView
          log('🔄 MainTabView: Returned from ProfileView - reactivating HomeView');
          _reactivateHomeView();
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

  void _pauseAllHomeViewVideos() {
    try {
      log('🚨 AUDIO FIX: Pausing HomeView videos for tab switch...');

      // 🔊 AUDIO FIX: Use GlobalPlaybackManager for consistent audio control
      final playbackManager = ref.read(globalPlaybackManagerProvider);
      playbackManager.pauseAllForTabSwitch(); // Pause + mute all videos
      // ❌ REMOVED: playbackManager.disposeAll() - too aggressive, causes disposal errors

      log('⏸️ MainTabView: Paused all HomeView videos (controllers kept alive)');
      debugPrint(
          '⏸️ MainTabView: Paused all HomeView videos (controllers kept alive)');
    } catch (e) {
      log('❌ MainTabView: Error pausing HomeView videos: $e');
      debugPrint('❌ MainTabView: Error pausing HomeView videos: $e');
    }
  }

  /// Reactivate HomeView when returning from other views
  void _reactivateHomeView() {
    try {
      log('🔄 MainTabView: Reactivating HomeView after return from other view');

      // 🔊 AUDIO FIX: Simply unblock and resume - no aggressive disposal
      final playbackManager = ref.read(globalPlaybackManagerProvider);
      playbackManager.resumeAfterTabSwitch();

      log('✅ MainTabView: HomeView reactivated - videos should resume automatically');
    } catch (e) {
      log('❌ MainTabView: Error reactivating HomeView: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody:
          true, // This allows content to extend behind the bottom navigation
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });

          // 🔊 AUDIO FIX: Block/unblock using GlobalPlaybackManager
          final playbackManager = GlobalPlaybackManager.instance;
          if (index != 0) {
            // Leaving home tab - block playback
            playbackManager.block(reason: 'tabSwitch');
          } else {
            // Returning to home tab - unblock and request focus
            playbackManager.unblock();
            Timer(const Duration(milliseconds: 100), () {
              _requestFocusForCurrentVideo();
            });
          }
        },
        // Disable horizontal swipe gestures when on HomeView (index 0) to allow left/right swipes for StreamerCardView
        // Disable swipe gestures when on NetworkView (index 1)
        physics: _currentIndex == 0 || _currentIndex == 1
            ? const NeverScrollableScrollPhysics()
            : const ClampingScrollPhysics(),
        children: const [
          // Home View
          HomeView(),
          // Network View
          NetworkView(),
          // Creation Screen (handled by floating action button)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_circle, size: 80, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Create Content',
                  style: TextStyle(fontSize: 24, color: Colors.grey),
                ),
                Text(
                  'Tap the + button',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          ),
          // Inbox (handled by navigation)
          Center(
            child: Icon(Icons.mail_outline, size: 80, color: Colors.grey),
          ),
          // Profile (handled by navigation)
          Center(
            child: Icon(Icons.account_circle_outlined,
                size: 80, color: Colors.grey),
          ),
        ],
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
      ),
    );
  }
}
