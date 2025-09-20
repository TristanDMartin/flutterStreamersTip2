import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/robust_auth_service.dart';
import '../widgets/profile_view_optimized.dart';
import '../widgets/custom_bottom_nav.dart';
import '../widgets/camera_view.dart';
import '../views/network_view.dart';
import '../widgets/inbox_view_optimized.dart';
import 'home_view.dart';
import '../models/user.dart';
import '../services/network_view_model_advanced.dart';
import '../services/profile_update_service.dart';
import '../services/clean_relationship_service.dart';

class MainTabView extends ConsumerStatefulWidget {
  const MainTabView({super.key});

  @override
  ConsumerState<MainTabView> createState() => _MainTabViewState();
}

class _MainTabViewState extends ConsumerState<MainTabView> {
  int _currentIndex = 0;
  late PageController _pageController;
  late NetworkViewModelAdvanced _networkViewModel;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _networkViewModel = NetworkViewModelAdvanced();
    _startDataSync();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _networkViewModel.dispose();
    super.dispose();
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
    
    setState(() {
      _currentIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onUploadTapped() {
    // Navigate directly to camera view
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const CameraView(),
      ),
    );
  }

  void _onInboxTapped() {
    // Navigate to inbox view as full screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const InboxViewOptimized(),
        fullscreenDialog: true,
      ),
    );
  }

  void _onProfileTapped() {
    // Navigate to profile view as full screen
    final authService = ref.read(robustAuthServiceProvider);
    if (authService.currentUser != null) {
      debugPrint("🔍 MainTabView: Creating User object with ID: ${authService.currentUser!.id}");
      debugPrint("🔍 MainTabView: AuthService currentUser: ${authService.currentUser}");
      
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
      
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ProfileViewOptimized(user: user, isCurrentUser: true),
          fullscreenDialog: true,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // This allows content to extend behind the bottom navigation
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
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
            child: Icon(Icons.account_circle_outlined, size: 80, color: Colors.grey),
          ),
        ],
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Auth Status Indicator
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: ref.watch(robustAuthServiceProvider).isLoggedIn 
                  ? Colors.green 
                  : Colors.red,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              ref.watch(robustAuthServiceProvider).isLoggedIn 
                  ? 'LOGGED IN' 
                  : 'NOT LOGGED IN',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // User Info
          if (ref.watch(robustAuthServiceProvider).currentUser != null)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '@${ref.watch(robustAuthServiceProvider).currentUser!.username}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
