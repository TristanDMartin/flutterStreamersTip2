import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'onboarding_view.dart';
import '../services/robust_auth_service.dart';

class WelcomeView extends ConsumerStatefulWidget {
  final VoidCallback onGetStarted;
  final VoidCallback onProceedToLogin;

  const WelcomeView({
    super.key,
    required this.onGetStarted,
    required this.onProceedToLogin,
  });

  @override
  ConsumerState<WelcomeView> createState() => _WelcomeViewState();
}

class _WelcomeViewState extends ConsumerState<WelcomeView> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    // Start animations
    _pulseController.repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
            decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF7B24E1), // Purple
              Color(0xFF9248d2), // Another purple
              Color(0xFF1670de), // Blue
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top spacer for centering on tall screens
              const Spacer(flex: 1),
              
              // Logo section
              _buildLogoSection(context),
              
              // Content stack
              _buildContentStack(context),
              
              // Bottom spacer for centering on tall screens
              const Spacer(flex: 1),
              
              // Bottom safe area padding
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoSection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 80), // 80pt below top safe area
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Pulsing wave circles behind the logo
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.0 + (_pulseAnimation.value * 0.3),
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.1 * _pulseAnimation.value),
                    ),
                  ),
                );
              },
            ),
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.0 + (_pulseAnimation.value * 0.5),
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.05 * _pulseAnimation.value),
                    ),
                  ),
                );
              },
            ),
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.0 + (_pulseAnimation.value * 0.7),
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.03 * _pulseAnimation.value),
                    ),
                  ),
                );
              },
            ),
            
            // Main logo
            Semantics(
              label: 'StreamersTip logo',
              child: Container(
                width: 120,
                height: 120,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 120,
                    height: 120,
                    fit: BoxFit.contain,
                    cacheWidth: 240,
                    cacheHeight: 240,
                    errorBuilder: (context, error, stackTrace) {
                      print('Logo loading error in welcome view: $error');
                      print('Stack trace: $stackTrace');
                      return Container(
                        color: Colors.white,
                        child: const Center(
                          child: Text(
                            'LOGO',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF7B24E1),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentStack(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Logo → Headline: 24pt
          const SizedBox(height: 24),
          
          // Headline
          _buildHeadline(context),
          
          // Headline → Subheadline: 10pt
          const SizedBox(height: 10),
          
          // Subheadline
          _buildSubheadline(context),
          
          // Subheadline → Primary CTA: 48pt
          const SizedBox(height: 48),
          
          // Primary CTA
          _buildPrimaryCTA(context),
          
          // Primary CTA → Secondary: 14pt
          const SizedBox(height: 14),
          
          // Secondary action
          _buildSecondaryAction(context),
        ],
      ),
    );
  }

  Widget _buildHeadline(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => OnboardingView(
              onComplete: () {
                Navigator.of(context).pop();
              },
            ),
          ),
        );
      },
      child: Text(
        'Hello!\nI\'m StreamersTip',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: _clampFontSize(context, 28, 44), // Clamp between 28pt and 44pt
          fontWeight: FontWeight.w600, // Semibold
          color: Colors.white.withOpacity(0.96), // 96% opacity for on-brand
          height: 1.1, // Tight line height
          letterSpacing: -0.3, // -1% tracking
        ),
      ),
    );
  }

  Widget _buildSubheadline(BuildContext context) {
    return const SizedBox.shrink(); // Remove the subheadline completely
  }

  Widget _buildPrimaryCTA(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56, // 56pt height
      child: Semantics(
        label: 'Hello, StreamersTip! Starts setup',
        button: true,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28), // Perfect pill (28pt radius)
            gradient: const LinearGradient(
              colors: [
                Color(0xFF9248d2), // Purple
                Color(0xFF7768df), // Another purple
                Color(0xFF1670de), // Blue
                Color(0xFF3c8bd6), // Lighter blue
                Color(0xFF4897d2), // Lightest blue
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: () {
                // Light haptic feedback
                HapticFeedback.lightImpact();
                widget.onGetStarted();
              },
              child: const Center(
                child: Text(
                  'Hello, StreamersTip!',
                  style: TextStyle(
                    fontSize: 17.5, // 17-18pt target
                    fontWeight: FontWeight.w600, // Semibold
                    letterSpacing: 0.2,
                    color: Colors.white, // White text on gradient
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryAction(BuildContext context) {
    return Column(
      children: [
        // Proceed to Login button
        SizedBox(
          height: 44, // Minimum 44pt hit target
          child: Semantics(
            label: 'Proceed to Login',
            button: true,
            child: TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                widget.onProceedToLogin();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.white.withOpacity(0.75), // 75% opacity
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              child: Text(
                'Proceed to Login',
                style: TextStyle(
                  fontSize: 16, // Body/footnote size
                  fontWeight: FontWeight.w600, // Semibold
                  color: Colors.white.withOpacity(0.75),
                ),
              ),
            ),
          ),
        ),
        
        // Spacing between buttons
        const SizedBox(height: 8),
        
        // Dev Login button
        SizedBox(
          height: 44, // Minimum 44pt hit target
          child: Semantics(
            label: 'Log in Dev - Bypass to technqs account',
            button: true,
            child: TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                _devLogin();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.orange.withOpacity(0.9), // Orange for dev
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              child: Text(
                'Log in Dev',
                style: TextStyle(
                  fontSize: 16, // Body/footnote size
                  fontWeight: FontWeight.w600, // Semibold
                  color: Colors.orange.withOpacity(0.9),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Dev login method that bypasses authentication
  Future<void> _devLogin() async {
    try {
      final authService = ref.read(robustAuthServiceProvider);
      await authService.bypassLogin();
      
      // The AppStartupWrapper will automatically detect the login state change
      // and navigate to MainTabView, so we don't need to navigate manually here
      print("✅ Bypass login completed - AppStartupWrapper will handle navigation");
      
    } catch (e) {
      // Show error if bypass fails
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dev login failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Helper method to clamp font size based on accessibility settings
  double _clampFontSize(BuildContext context, double min, double max) {
    final textScaleFactor = MediaQuery.of(context).textScaleFactor;
    const baseSize = 36; // Base size for normal text scaling
    final scaledSize = baseSize * textScaleFactor;
    return scaledSize.clamp(min, max);
  }


}

// Accessibility-aware welcome view with proper semantics
class AccessibleWelcomeView extends StatelessWidget {
  final VoidCallback onGetStarted;
  final VoidCallback onProceedToLogin;

  const AccessibleWelcomeView({
    super.key,
    required this.onGetStarted,
    required this.onProceedToLogin,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Welcome to StreamersTip',
      child: WelcomeView(
        onGetStarted: onGetStarted,
        onProceedToLogin: onProceedToLogin,
      ),
    );
  }
}
