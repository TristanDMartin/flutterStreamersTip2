import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/robust_auth_service.dart';
import '../services/pending_auth_redirect_service.dart';
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
  bool _isContentVisible = false;

  @override
  void initState() {
    super.initState();
    _setSystemUIOverlayStyle();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isContentVisible = true;
        });
      }
    });
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
        debugPrint("✅ User authenticated, resolving post-auth destination");
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          PendingAuthRedirectService.instance.consumeOrGoHome(context);
        });
      }
    });

    return Material(
      color: Colors.transparent,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF6D43F3), Color(0xFF2A1A77), Color(0xFF150E46)],
            ),
          ),
          child: Stack(
            children: [
              _buildBackgroundDecor(),
              SafeArea(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOut,
                  opacity: _isContentVisible ? 1 : 0,
                  child: AnimatedSlide(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                    offset: _isContentVisible
                        ? Offset.zero
                        : const Offset(0, 0.03),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          _buildHeader(),
                          const Spacer(),
                          _buildAnimatedSection(
                            delay: 0,
                            child: _buildAppLogoSection(),
                          ),
                          const Spacer(),
                          _buildAnimatedSection(
                            delay: 80,
                            child: _buildAuthButtons(authService),
                          ),
                          const Spacer(),
                          _buildAnimatedSection(
                            delay: 140,
                            child: Column(
                              children: [
                                _buildTermsAndPrivacy(),
                                _buildSignUpSection(),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
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
            style: TextStyle(
              color: Color(0xFFC6D4FF),
              fontWeight: FontWeight.w600,
            ),
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
    return _buildGlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        children: [
          Container(
            width: 120,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bolt_rounded, color: Color(0xFFFFD76A), size: 16),
                SizedBox(width: 6),
                Text(
                  "Welcome Back",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Image.asset(
            'assets/logo.png',
            width: 120,
            height: 120,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              debugPrint('❌ Error loading logo: $error');
              debugPrint('❌ Stack trace: $stackTrace');
              return ShaderMask(
                shaderCallback: (Rect rect) {
                  return const LinearGradient(
                    colors: [
                      Color(0xFFFFD76A),
                      Color(0xFF9F80FF),
                      Color(0xFF52B6FF),
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
          const SizedBox(height: 18),
          const Text(
            "StreamersTip",
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "Connect with your favorite streamers, communities, and live moments in one place.",
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFFE1E6FF),
              height: 1.45,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAuthButtons(RobustAuthenticationService authService) {
    return _buildGlassPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Choose a sign-in method",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "Pick email for account access or Google for the fastest setup.",
            style: TextStyle(
              color: Color(0xCCDFE5FF),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
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
          const SizedBox(height: 14),
          _buildAuthButton(
            icon: Icons.language,
            text: "Continue with Google",
            backgroundColor: Colors.white,
            textColor: Colors.black,
            onTap: _signInWithGoogle,
            disabled: authService.shouldShowLoading,
          ),
        ],
      ),
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
      child: _PressableAuthButton(
        enabled: !disabled,
        onTap: onTap,
        child: Container(
          width: double.infinity,
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF955CFF), Color(0xFF3D99F7)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x332C8FFF),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
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
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
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

  Widget _buildAnimatedSection({
    required Widget child,
    required int delay,
  }) {
    final duration = Duration(milliseconds: 420 + delay);
    return AnimatedOpacity(
      duration: duration,
      curve: Curves.easeOut,
      opacity: _isContentVisible ? 1 : 0,
      child: AnimatedSlide(
        duration: duration,
        curve: Curves.easeOutCubic,
        offset: _isContentVisible ? Offset.zero : const Offset(0, 0.05),
        child: child,
      ),
    );
  }

  Widget _buildBackgroundDecor() {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -30,
            child: _buildGlowOrb(
              size: 220,
              colors: const [Color(0x55B27BFF), Color(0x00B27BFF)],
            ),
          ),
          Positioned(
            top: 180,
            left: -70,
            child: _buildGlowOrb(
              size: 180,
              colors: const [Color(0x4447C4FF), Color(0x0047C4FF)],
            ),
          ),
          Positioned(
            bottom: -60,
            right: -10,
            child: _buildGlowOrb(
              size: 180,
              colors: const [Color(0x33FF6DB2), Color(0x00FF6DB2)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlowOrb({
    required double size,
    required List<Color> colors,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: colors),
      ),
    );
  }

  Widget _buildGlassPanel({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            color: Colors.white.withValues(alpha: 0.08),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x26000000),
                blurRadius: 32,
                offset: Offset(0, 18),
              ),
            ],
          ),
          child: child,
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
            color: Color(0xBFD6DBFF),
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
                color: Color(0xBFD6DBFF),
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
            color: Color(0xFFDDE3FF),
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
      final result = await authService.debouncedSignInWithGoogle();
      if (!result.success && mounted) {
        debugPrint("❌ Google sign-in failed: ${result.error}");
        setState(() {
          _alertMessage = _getUserFriendlyErrorMessage(result.error ?? '');
          _showAlert = true;
        });
        return;
      }

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

class _PressableAuthButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool enabled;

  const _PressableAuthButton({
    required this.child,
    required this.onTap,
    this.enabled = true,
  });

  @override
  State<_PressableAuthButton> createState() => _PressableAuthButtonState();
}

class _PressableAuthButtonState extends State<_PressableAuthButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!widget.enabled) return;
    setState(() {
      _pressed = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.985 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        child: widget.child,
      ),
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
          color: Color(0xFFFF6AA2),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
