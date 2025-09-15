import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'enhanced_launch_screen.dart';
import 'splash_screen.dart';
import '../services/robust_auth_service.dart';
import '../widgets/auth_modal_view.dart';
import '../pages/main_tab_view.dart';

/// Comprehensive app startup wrapper that handles launch screen and authentication flow
class AppStartupWrapper extends ConsumerStatefulWidget {
  const AppStartupWrapper({super.key});

  @override
  ConsumerState<AppStartupWrapper> createState() => _AppStartupWrapperState();
}

class _AppStartupWrapperState extends ConsumerState<AppStartupWrapper> {
  bool _showLaunchScreen = true;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Wait for launch screen to complete
    await Future.delayed(const Duration(milliseconds: 3000));
    
    if (mounted) {
      setState(() {
        _showLaunchScreen = false;
      });
      
      // Small delay before showing auth check
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  void _onLaunchComplete() {
    if (mounted) {
      setState(() {
        _showLaunchScreen = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show launch screen first
    if (_showLaunchScreen) {
      return EnhancedLaunchScreen(
        onLaunchComplete: _onLaunchComplete,
        launchDuration: const Duration(milliseconds: 3000),
        showLoadingIndicator: true,
      );
    }

    // Show loading while checking authentication
    if (_isInitializing) {
      return _buildLoadingScreen();
    }

    // Check authentication status and show appropriate screen
    return Consumer(
      builder: (context, ref, child) {
        final authService = ref.watch(robustAuthServiceProvider);
        
        // Show loading while checking auth
        if (authService.shouldShowLoading) {
          return _buildLoadingScreen();
        }
        
        // Show main app if logged in
        if (authService.isLoggedIn) {
          return const MainTabView();
        }
        
        // Show auth modal if not logged in
        return const AuthModalView();
      },
    );
  }

  Widget _buildLoadingScreen() {
    return const SplashScreen(
      duration: Duration(seconds: 3),
    );
  }
}

/// Alternative startup wrapper with custom launch duration
class CustomAppStartupWrapper extends ConsumerStatefulWidget {
  final Duration launchDuration;
  final bool showLoadingIndicator;
  final Widget? customLoadingWidget;

  const CustomAppStartupWrapper({
    super.key,
    this.launchDuration = const Duration(milliseconds: 3000),
    this.showLoadingIndicator = true,
    this.customLoadingWidget,
  });

  @override
  ConsumerState<CustomAppStartupWrapper> createState() => _CustomAppStartupWrapperState();
}

class _CustomAppStartupWrapperState extends ConsumerState<CustomAppStartupWrapper> {
  bool _showLaunchScreen = true;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Wait for launch screen to complete
    await Future.delayed(widget.launchDuration);
    
    if (mounted) {
      setState(() {
        _showLaunchScreen = false;
      });
      
      // Small delay before showing auth check
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  void _onLaunchComplete() {
    if (mounted) {
      setState(() {
        _showLaunchScreen = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show launch screen first
    if (_showLaunchScreen) {
      return EnhancedLaunchScreen(
        onLaunchComplete: _onLaunchComplete,
        launchDuration: widget.launchDuration,
        showLoadingIndicator: widget.showLoadingIndicator,
      );
    }

    // Show loading while checking authentication
    if (_isInitializing) {
      return widget.customLoadingWidget ?? _buildLoadingScreen();
    }

    // Check authentication status and show appropriate screen
    return Consumer(
      builder: (context, ref, child) {
        final authService = ref.watch(robustAuthServiceProvider);
        
        // Show loading while checking auth
        if (authService.shouldShowLoading) {
          return widget.customLoadingWidget ?? _buildLoadingScreen();
        }
        
        // Show main app if logged in
        if (authService.isLoggedIn) {
          return const MainTabView();
        }
        
        // Show auth modal if not logged in
        return const AuthModalView();
      },
    );
  }

  Widget _buildLoadingScreen() {
    return const SplashScreen(
      duration: Duration(seconds: 3),
    );
  }
}
