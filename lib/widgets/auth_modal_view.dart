import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/robust_auth_service.dart';
import 'email_login_view.dart';
import 'signup_view.dart';
// import '../views/terms_of_service_view.dart'; // Removed - unused
// import '../views/privacy_policy_view.dart'; // Removed - unused

class AuthModalView extends ConsumerStatefulWidget {
  final VoidCallback? dismiss;

  const AuthModalView({
    super.key,
    this.dismiss,
  });

  @override
  ConsumerState<AuthModalView> createState() => _AuthModalViewState();
}

class _AuthModalViewState extends ConsumerState<AuthModalView> {
  bool _showAlert = false;
  String _alertMessage = "";

  @override
  void initState() {
    super.initState();
    _setSystemUIOverlayStyle();
  }

  void _setSystemUIOverlayStyle() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF1C135D),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }

  @override
  void dispose() {
    _resetSystemUIOverlayStyle();
    super.dispose();
  }

  void _resetSystemUIOverlayStyle() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = ref.watch(robustAuthServiceProvider);

    // Listen to auth state changes to navigate when user signs in
    ref.listen(robustAuthServiceProvider, (previous, next) {
      // Check if user is now logged in
      if (next.isLoggedIn && mounted) {
        // User is authenticated, the AppStartupWrapper will handle navigation
        // No need to manually navigate here since the parent widget will rebuild
        debugPrint(
            "✅ User authenticated, AppStartupWrapper will handle navigation");
      }
    });

    return Material(
      color: Colors.transparent,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF6137EB), Color(0xFF1C135D)],
            ),
          ),
          child: Stack(
            children: [
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      // Header
                      _buildHeader(),
                      const Spacer(),
                      // App Logo/Title
                      _buildAppLogoSection(),
                      const Spacer(),
                      // Authentication Buttons
                      _buildAuthButtons(authService),
                      const Spacer(),
                      // Terms and Privacy
                      _buildTermsAndPrivacy(),
                      // Sign Up
                      _buildSignUpSection(),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // Loading Overlay
              if (authService.shouldShowLoading)
                Container(
                  color: Colors.black.withValues(alpha: 0.3),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                        SizedBox(height: 16),
                        Text(
                          "Signing in...",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // ===== Alert Dialog Overlay (added) =====
              if (_showAlert) ...[
                // Tap outside to dismiss
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => setState(() => _showAlert = false),
                    child: Container(color: Colors.black54),
                  ),
                ),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: AlertDialog(
                      backgroundColor: const Color(0xFF1C1C1E),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      title: const Text(
                        "Notice",
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                      content: Text(
                        _alertMessage.isEmpty
                            ? "Something happened."
                            : _alertMessage,
                        style:
                            const TextStyle(color: Colors.white70, height: 1.3),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => setState(() => _showAlert = false),
                          child: const Text("OK"),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              // ===== End Alert Dialog Overlay =====
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        TextButton(
          onPressed: widget.dismiss,
          child: const Text(
            "Cancel",
            style: TextStyle(color: Colors.blue),
          ),
        ),
        const Spacer(),
        const Text(
          "Sign In",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const Spacer(),
        // Invisible spacer to balance the layout
        const Text(
          "Cancel",
          style: TextStyle(color: Colors.transparent),
        ),
      ],
    );
  }

  Widget _buildAppLogoSection() {
    return Column(
      children: [
        Image.asset(
          'assets/logo.png',
          width: 120,
          height: 120,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('❌ Error loading logo: $error');
            debugPrint('❌ Stack trace: $stackTrace');
            // Fallback to gradient icon if logo fails to load
            return ShaderMask(
              shaderCallback: (Rect rect) {
                return const LinearGradient(
                  colors: [
                    Color(0xFF9248D2),
                    Color(0xFF7768DF),
                    Color(0xFF1670DE),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(rect);
              },
              blendMode: BlendMode.srcIn,
              child: const Icon(
                Icons.play_circle_filled,
                size: 120,
                color: Colors.white,
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        const Text(
          "StreamersTip",
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          "Connect with your favorite streamers",
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildAuthButtons(RobustAuthenticationService authService) {
    return Column(
      children: [
        // Email/Username Button
        _buildAuthButton(
          icon: Icons.person,
          text: "Sign in with Email/Username",
          backgroundColor: Colors.white,
          textColor: Colors.black,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => EmailLoginView(
                  dismiss: () => Navigator.of(context).pop(),
                ),
              ),
            );
          },
          disabled: authService.shouldShowLoading,
        ),
        const SizedBox(height: 16),

        // Google Button
        _buildAuthButton(
          icon: Icons.language,
          text: "Continue with Google",
          backgroundColor: Colors.white,
          textColor: Colors.black,
          onTap: _signInWithGoogle,
          disabled: authService.shouldShowLoading,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildAuthButton({
    required IconData icon,
    required String text,
    required Color backgroundColor,
    required Color textColor,
    required VoidCallback onTap,
    bool disabled = false,
  }) {
    return Opacity(
      opacity: disabled ? 0.5 : 1.0,
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: Container(
          width: double.infinity,
          height: 48, // Match ProfileView button height
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF955CFF),
                Color(0xFF3D99F7)
              ], // Match ProfileView gradient
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius:
                BorderRadius.circular(24), // Match ProfileView pill shape
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: Colors.white),
                const SizedBox(width: 12),
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTermsAndPrivacy() {
    return Column(
      children: [
        const Text(
          "By continuing, you agree to our",
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () {
                _showTermsDialog();
              },
              child: const Text(
                "Terms of Service",
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6137EB),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Text(
              "and",
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            TextButton(
              onPressed: () {
                _showPrivacyDialog();
              },
              child: const Text(
                "Privacy Policy",
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6137EB),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSignUpSection() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Don't have an account?",
          style: TextStyle(
            fontSize: 14,
            color: Colors.white,
          ),
        ),
        SizedBox(width: 4),
        _SignupLink(),
      ],
    );
  }

  // Authentication Methods
  Future<void> _signInWithGoogle() async {
    debugPrint("🟢 Google sign-in tapped");
    try {
      final authService = ref.read(robustAuthServiceProvider);
      await authService.debouncedSignInWithGoogle();
      // Success - the auth state listener will handle navigation
      debugPrint("✅ Google sign-in completed successfully");
    } catch (e) {
      debugPrint("❌ Google sign-in error: $e");
      if (mounted) {
        setState(() {
          _alertMessage = _getUserFriendlyErrorMessage(e.toString());
          _showAlert = true;
        });
      }
    }
  }

  String _getUserFriendlyErrorMessage(String error) {
    if (error.contains('sign_in_canceled') || error.contains('cancelled')) {
      return 'Sign-in was cancelled';
    } else if (error.contains('network_error') || error.contains('network')) {
      return 'Network error. Please check your connection';
    } else if (error.contains('sign_in_failed')) {
      return 'Sign-in failed. Please try again';
    } else {
      return 'Sign-in failed. Please try again';
    }
  }

  void _showTermsDialog() {
    // Navigator.of(context).push(
    //   MaterialPageRoute(
    //     builder: (context) => const TermsOfServiceView(),
    //   ),
    // );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Terms of service coming soon!')),
    );
  }

  void _showPrivacyDialog() {
    // Navigator.of(context).push(
    //   MaterialPageRoute(
    //     builder: (context) => const PrivacyPolicyView(),
    //   ),
    // );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Privacy policy coming soon!')),
    );
  }
}

class _SignupLink extends StatelessWidget {
  const _SignupLink();

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const SignupView()),
        );
      },
      child: const Text(
        "Sign up",
        style: TextStyle(
          fontSize: 14,
          color: Colors.pink,
        ),
      ),
    );
  }
}
