import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/robust_auth_service.dart';
import 'signup_view.dart';
import 'email_login_view.dart';

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
  Widget build(BuildContext context) {
    final authService = ref.watch(robustAuthServiceProvider);

    return Material(
      color: Colors.black,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
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
                color: Colors.black.withValues(alpha:0.3),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                    content: Text(
                      _alertMessage.isEmpty ? "Something happened." : _alertMessage,
                      style: const TextStyle(color: Colors.white70, height: 1.3),
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
    return const Column(
      children: [
        Icon(
          Icons.play_circle_fill,
          size: 80,
          color: Colors.white,
        ),
        SizedBox(height: 16),
        Text(
          "StreamersTip",
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 16),
        Text(
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

        // Test Login Button (for development)
        _buildAuthButton(
          icon: Icons.bug_report,
          text: "Test Login (technqs)",
          backgroundColor: const Color(0xFF9248D2),
          textColor: Colors.white,
          onTap: _testLogin,
          disabled: authService.shouldShowLoading,
        ),
        const SizedBox(height: 16),

        // Bypass Login Button (for development)
        _buildAuthButton(
          icon: Icons.rocket_launch,
          text: "Bypass Login (Dev)",
          backgroundColor: const Color(0xFF1670DE),
          textColor: Colors.white,
          onTap: _bypassLogin,
          disabled: authService.shouldShowLoading,
        ),
        
        const SizedBox(height: 16),
        
        // TODO: Add bypass login for development if needed

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
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.transparent, width: 1),
          ),
          child: Row(
            children: [
              Icon(icon, size: 24, color: textColor),
              const SizedBox(width: 12),
              Text(
                text,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
              const Spacer(),
            ],
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
                // TODO: Show terms
              },
              child: const Text(
                "Terms of Service",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue,
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
                // TODO: Show privacy policy
              },
              child: const Text(
                "Privacy Policy",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue,
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
    } catch (e) {
      if (mounted) {
        setState(() {
          _alertMessage = e.toString();
          _showAlert = true;
        });
      }
    }
  }

  Future<void> _testLogin() async {
    debugPrint("🧪 Test login tapped");
    try {
      final authService = ref.read(robustAuthServiceProvider);
      
      // Show loading state
      if (mounted) {
        setState(() {
          _alertMessage = "Creating test account and signing in...";
          _showAlert = true;
        });
      }
      
      final result = await authService.quickTestLogin();
      
      if (result.success) {
        debugPrint("✅ Test login successful");
        // Success - the auth state listener will handle navigation
        if (mounted) {
          setState(() {
            _showAlert = false;
          });
        }
      } else {
        debugPrint("❌ Test login failed: ${result.error}");
        if (mounted) {
          setState(() {
            _alertMessage = "Test login failed: ${result.error ?? 'Unknown error'}\n\nThis will create a new account if it doesn't exist.";
            _showAlert = true;
          });
        }
      }
    } catch (e) {
      debugPrint("❌ Test login error: $e");
      if (mounted) {
        setState(() {
          _alertMessage = "Test login error: $e\n\nThis will create a new account if it doesn't exist.";
          _showAlert = true;
        });
      }
    }
  }

  Future<void> _bypassLogin() async {
    debugPrint("🚀 Bypass login tapped");
    try {
      final authService = ref.read(robustAuthServiceProvider);
      
      // Show loading state
      if (mounted) {
        setState(() {
          _alertMessage = "Bypassing authentication for development...";
          _showAlert = true;
        });
      }
      
      final result = await authService.bypassLogin();
      
      if (result.success) {
        debugPrint("✅ Bypass login successful");
        // Success - the auth state listener will handle navigation
        if (mounted) {
          setState(() {
            _showAlert = false;
          });
        }
      } else {
        debugPrint("❌ Bypass login failed: ${result.error}");
        if (mounted) {
          setState(() {
            _alertMessage = "Bypass login failed: ${result.error ?? 'Unknown error'}";
            _showAlert = true;
          });
        }
      }
    } catch (e) {
      debugPrint("❌ Bypass login error: $e");
      if (mounted) {
        setState(() {
          _alertMessage = "Bypass login error: $e";
          _showAlert = true;
        });
      }
    }
  }

  // TODO: Add bypass login method for development if needed
}

class _SignupLink extends StatelessWidget {
  const _SignupLink();

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const SignupView()),
      ),
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
