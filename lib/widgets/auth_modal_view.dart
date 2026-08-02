import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/firebase_bootstrap.dart';
import '../qa/qa_keys.dart';
import '../services/robust_auth_service.dart';
import '../utils/auth_post_login_navigation.dart';
import '../views/terms_and_privacy_view.dart';
import '../constants/app_colors.dart';
import 'auth/auth_brand_header.dart';
import 'auth/auth_cinematic_shell.dart';
import '../features/onboarding_tippy/tippy_onboarding_view.dart';
import 'auth/auth_get_started_button.dart';
import 'auth/auth_glass_panel.dart';
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
  String _alertMessage = '';
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
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.black,
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
    final RobustAuthenticationService authService =
        ref.watch(robustAuthServiceProvider);
    ref.listen<RobustAuthenticationService>(
      robustAuthServiceProvider,
      (RobustAuthenticationService? previous, RobustAuthenticationService next) {
        final bool wasLoggedIn = previous?.isLoggedIn ?? false;
        if (!wasLoggedIn && next.isLoggedIn && mounted) {
          if (!FirebaseBootstrap.isReady) {
            return;
          }
          final firebase_auth.User? user =
              firebase_auth.FirebaseAuth.instance.currentUser;
          debugPrint(
            'AUTH POST-LOGIN: social/email shell detected login '
            'uid=${user?.uid ?? 'null'}',
          );
          if (user == null) {
            return;
          }
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted) {
              return;
            }
            await navigateAfterAuthenticated(context);
          });
        }
      },
    );

    return AuthCinematicShell(
      showLoading: authService.isAuthSubmitting,
      loadingText: 'Signing in...',
      showAlert: _showAlert,
      alertMessage: _alertMessage,
      onDismissAlert: () => setState(() => _showAlert = false),
      header: widget.dismiss == null ? null : _buildDismissHeader(),
      content: AnimatedOpacity(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOut,
        opacity: _isContentVisible ? 1 : 0,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          offset: _isContentVisible ? Offset.zero : const Offset(0, 0.03),
          child: Column(
            children: <Widget>[
              const SizedBox(height: 12),
              _buildAnimatedSection(
                delay: 0,
                child: const AuthBrandHeader(),
              ),
              const SizedBox(height: 28),
              _buildAnimatedSection(
                delay: 40,
                child: _buildWelcomeCopy(),
              ),
              const SizedBox(height: 28),
              _buildAnimatedSection(
                delay: 80,
                child: _buildAuthButtons(authService),
              ),
              const SizedBox(height: 28),
              _buildAnimatedSection(
                delay: 140,
                child: Column(
                  children: <Widget>[
                    _buildTermsAndPrivacy(),
                    const SizedBox(height: 8),
                    _buildSignUpSection(),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDismissHeader() {
    return SizedBox(
      height: 44,
      child: Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: widget.dismiss,
          child: const Text(
            'Cancel',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeCopy() {
    return Column(
      children: <Widget>[
        const Text(
          'Welcome Back',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Sign in to continue growing your audience.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.78),
            fontSize: 15,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildAuthButtons(RobustAuthenticationService authService) {
    return AuthGlassPanel(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildAuthButton(
            key: QaKeys.authEmailUsernameOption,
            icon: Icons.mail_outline_rounded,
            text: 'Continue with Email',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) => EmailLoginView(
                    dismiss: () => Navigator.of(context).pop(),
                  ),
                ),
              );
            },
            disabled: authService.isAuthSubmitting,
          ),
          if (_shouldShowAppleSignIn) ...<Widget>[
            const SizedBox(height: 14),
            _buildAppleSignInButton(authService),
          ],
          const SizedBox(height: 14),
          _buildAuthButton(
            icon: Icons.g_mobiledata_rounded,
            text: 'Continue with Google',
            onTap: _signInWithGoogle,
            disabled: authService.isAuthSubmitting,
          ),
        ],
      ),
    );
  }

  bool get _shouldShowAppleSignIn =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  Widget _buildAppleSignInButton(RobustAuthenticationService authService) {
    return _buildAuthButton(
      key: QaKeys.authAppleOption,
      icon: Icons.apple,
      text: 'Continue with Apple',
      onTap: _signInWithApple,
      disabled: authService.isAuthSubmitting,
    );
  }

  Widget _buildAuthButton({
    Key? key,
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    bool disabled = false,
  }) {
    return Opacity(
      opacity: disabled ? 0.5 : 1.0,
      child: _PressableAuthButton(
        key: key,
        enabled: !disabled,
        onTap: onTap,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: <Color>[
                AppColors.primary,
                Color(0xFF7768DF),
                Color(0xFF4897D2),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.38),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: const Color(0xFF4897D2).withValues(alpha: 0.28),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: 22, color: Colors.white),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize:
                        !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
                            ? 16
                            : 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                    color: Colors.white,
                    height: 1.15,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedSection({
    required Widget child,
    required int delay,
  }) {
    final Duration duration = Duration(milliseconds: 420 + delay);
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

  Widget _buildTermsAndPrivacy() {
    final TextStyle muted = TextStyle(
      fontSize: 12,
      color: Colors.white.withValues(alpha: 0.62),
    );
    return Column(
      children: <Widget>[
        Text('By continuing, you agree to our', style: muted),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            TextButton(
              onPressed: _openTermsOfService,
              child: const Text(
                'Terms of Service',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text('and', style: muted),
            TextButton(
              onPressed: _openPrivacyPolicy,
              child: const Text(
                'Privacy Policy',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSignUpSection() {
    return Column(
      children: <Widget>[
        Text(
          'New to StreamersTip?',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.72),
          ),
        ),
        const SizedBox(height: 10),
        AuthGetStartedButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (BuildContext context) =>
                    const TippyOnboardingView(),
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _signInWithGoogle() async {
    debugPrint('🟢 Google sign-in tapped');
    final RobustAuthenticationService authService =
        ref.read(robustAuthServiceProvider);
    if (authService.isAuthSubmitting) {
      return;
    }
    try {
      final AuthRequestResult result =
          await authService.debouncedSignInWithGoogle();
      await _completeSocialSignIn(result, providerLabel: 'Google');
    } catch (e) {
      debugPrint('❌ Google sign-in error: $e');
      if (mounted) {
        setState(() {
          _alertMessage = _getUserFriendlyErrorMessage(e.toString());
          _showAlert = true;
        });
      }
    }
  }

  Future<void> _signInWithApple() async {
    debugPrint('🍎 Apple sign-in tapped');
    final RobustAuthenticationService authService =
        ref.read(robustAuthServiceProvider);
    if (authService.isAuthSubmitting) {
      return;
    }
    try {
      final AuthRequestResult result =
          await authService.debouncedSignInWithApple();
      await _completeSocialSignIn(result, providerLabel: 'Apple');
    } catch (e) {
      debugPrint('❌ Apple sign-in error: $e');
      if (mounted) {
        setState(() {
          _alertMessage = _getUserFriendlyErrorMessage(e.toString());
          _showAlert = true;
        });
      }
    }
  }

  Future<void> _completeSocialSignIn(
    AuthRequestResult result, {
    required String providerLabel,
  }) async {
    if (!FirebaseBootstrap.isReady) {
      if (mounted) {
        setState(() {
          _alertMessage = 'Still connecting. Please try again in a moment.';
          _showAlert = true;
        });
      }
      return;
    }
    final firebase_auth.User? firebaseUser =
        firebase_auth.FirebaseAuth.instance.currentUser;
    debugPrint(
      'AUTH POST-LOGIN: $providerLabel result.success=${result.success} '
      'resultUid=${result.user?.id ?? 'null'} '
      'firebaseCurrentUid=${firebaseUser?.uid ?? 'null'}',
    );
    if (!result.success && mounted) {
      final String error = result.error ?? '';
      final bool isCancelled = error.toLowerCase().contains('cancelled');
      if (isCancelled && firebaseUser == null) {
        debugPrint('AUTH POST-LOGIN: $providerLabel cancelled');
        return;
      }
      if (firebaseUser == null) {
        debugPrint('❌ $providerLabel sign-in failed: $error');
        setState(() {
          _alertMessage = _getUserFriendlyErrorMessage(error);
          _showAlert = true;
        });
        return;
      }
      debugPrint(
        'AUTH POST-LOGIN: $providerLabel reported failure but Firebase '
        'session exists uid=${firebaseUser.uid}',
      );
    }
    debugPrint(
      '✅ $providerLabel sign-in completed — waiting for auth gate '
      'uid=${firebaseUser?.uid ?? 'null'}',
    );
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
    launchUrl(Uri.parse('https://www.streamerstip.com/privacy'));
  }
}

class _PressableAuthButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool enabled;

  const _PressableAuthButton({
    super.key,
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
    if (!widget.enabled) {
      return;
    }
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
        behavior: HitTestBehavior.opaque,
        onTap: widget.enabled ? widget.onTap : null,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        child: widget.child,
      ),
    );
  }
}

