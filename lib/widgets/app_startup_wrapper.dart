import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/robust_auth_service.dart';
import '../widgets/auth_modal_view.dart';
import '../pages/main_tab_view.dart';

/// App startup wrapper that handles authentication flow
class AppStartupWrapper extends ConsumerStatefulWidget {
  const AppStartupWrapper({super.key});

  @override
  ConsumerState<AppStartupWrapper> createState() => _AppStartupWrapperState();
}

class _AppStartupWrapperState extends ConsumerState<AppStartupWrapper> {
  @override
  Widget build(BuildContext context) {
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
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6137EB), Color(0xFF1C135D)],
          ),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      ),
    );
  }
}

