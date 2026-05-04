import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/st_theme_tokens.dart';
import '../services/robust_auth_service.dart';
import '../services/pending_auth_redirect_service.dart';
import '../views/terms_and_privacy_view.dart';
import 'email_login_view.dart';
import 'privacy_policy_view.dart';
import 'signup_view.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isContentVisible = true;
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _applySystemUiForTheme();
  }

  void _applySystemUiForTheme() {
    final ThemeData theme = Theme.of(context);
    final Brightness brightness = theme.brightness;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarColor: theme.colorScheme.surface,
        systemNavigationBarIconBrightness: brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
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
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;
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
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? <Color>[
                      StThemeColors.darkBackground,
                      scheme.surfaceContainerLow,
                      scheme.surface,
                    ]
                  : <Color>[
                      scheme.primary.withValues(alpha: 0.45),
                      scheme.surfaceContainerLow,
                      scheme.surface,
                    ],
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
                  color: scheme.scrim.withValues(alpha: 0.35),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            scheme.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Signing in...",
                          style: TextStyle(
                            color: scheme.onSurface,
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
                      backgroundColor: scheme.surfaceContainerHigh,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      title: Text(
                        "Notice",
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      content: Text(
                        _alertMessage.isEmpty
                            ? "Something happened."
                            : _alertMessage,
                        style: TextStyle(
                          color: scheme.onSurface.withValues(alpha: 0.75),
                          height: 1.3,
                        ),
                      ),
                      actions: [
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: scheme.primary,
                          ),
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
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextStyle titleStyle = TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: scheme.onSurface,
    );
    final Widget title = Text("Sign In", style: titleStyle);
    if (widget.dismiss == null) {
      return SizedBox(height: 48, child: Center(child: title));
    }
    return Row(
      children: [
        TextButton(
          onPressed: widget.dismiss,
          child: Text(
            "Cancel",
            style: TextStyle(
              color: scheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Spacer(),
        title,
        const Spacer(),
        const SizedBox(width: 72),
      ],
    );
  }

  Widget _buildAppLogoSection() {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return _buildGlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        children: [
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
          Text(
            "StreamersTip",
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthButtons(RobustAuthenticationService authService) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return _buildGlassPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Choose a sign-in method",
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Pick email for account access or Google for the fastest setup.",
            style: TextStyle(
              color: scheme.onSurfaceVariant,
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
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color primarySoft = scheme.primary.withValues(alpha: 0.14);
    final Color secondarySoft = scheme.secondary.withValues(alpha: 0.1);
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -30,
            child: _buildGlowOrb(
              size: 220,
              colors: [primarySoft, primarySoft.withValues(alpha: 0)],
            ),
          ),
          Positioned(
            top: 180,
            left: -70,
            child: _buildGlowOrb(
              size: 180,
              colors: [secondarySoft, secondarySoft.withValues(alpha: 0)],
            ),
          ),
          Positioned(
            bottom: -60,
            right: -10,
            child: _buildGlowOrb(
              size: 180,
              colors: [
                scheme.primary.withValues(alpha: 0.08),
                Colors.transparent,
              ],
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
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color panelFill = isDark
        ? scheme.surface.withValues(alpha: 0.42)
        : scheme.surface.withValues(alpha: 0.72);
    final Color panelBorder = scheme.outline.withValues(alpha: isDark ? 0.35 : 0.45);
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            color: panelFill,
            border: Border.all(color: panelBorder),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: isDark ? 0.45 : 0.12),
                blurRadius: 32,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildTermsAndPrivacy() {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextStyle muted = TextStyle(
      fontSize: 12,
      color: scheme.onSurfaceVariant,
    );
    return Column(
      children: [
        Text("By continuing, you agree to our", style: muted),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: _openTermsOfService,
              child: Text(
                "Terms of Service",
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text("and", style: muted),
            TextButton(
              onPressed: _openPrivacyPolicy,
              child: Text(
                "Privacy Policy",
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.primary,
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
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Don't have an account?",
          style: TextStyle(
            fontSize: 14,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 4),
        _SignupLink(scheme: scheme),
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

  void _openTermsOfService() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const TermsAndPrivacyView(),
      ),
    );
  }

  void _openPrivacyPolicy() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const PrivacyPolicyView(),
      ),
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
  const _SignupLink({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const SignupView()),
        );
      },
      child: Text(
        "Sign up",
        style: TextStyle(
          fontSize: 14,
          color: scheme.secondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
