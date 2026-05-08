import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/robust_auth_service.dart';
import '../utils/auth_login_input.dart';
import '../utils/auth_post_login_navigation.dart';
import 'auth_page_shell.dart';
import 'signup_view.dart';
import 'forgot_password_view.dart';
import 'two_factor_verification_view.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

class EmailLoginView extends ConsumerStatefulWidget {
  final VoidCallback? dismiss;

  const EmailLoginView({
    super.key,
    this.dismiss,
  });

  @override
  ConsumerState<EmailLoginView> createState() => _EmailLoginViewState();
}

class _EmailLoginViewState extends ConsumerState<EmailLoginView> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  bool _obscurePassword = true;
  bool _showAlert = false;
  String _alertMessage = "";
  bool _hasAttemptedSubmit = false;
  bool _isContentVisible = false;

  void _handleInputChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_handleInputChanged);
    _passwordController.addListener(_handleInputChanged);
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
        statusBarIconBrightness:
            brightness == Brightness.dark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: theme.colorScheme.surface,
        systemNavigationBarIconBrightness:
            brightness == Brightness.dark ? Brightness.light : Brightness.dark,
      ),
    );
  }

  @override
  void dispose() {
    _emailController.removeListener(_handleInputChanged);
    _passwordController.removeListener(_handleInputChanged);
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _resetSystemUIOverlayStyle();
    super.dispose();
  }

  void _resetSystemUIOverlayStyle() {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
  }

  @override
  Widget build(BuildContext context) {
    final authService = ref.watch(robustAuthServiceProvider);
    return AuthPageShell(
      contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      minHeightBottomPadding: 16,
      showLoading: authService.shouldShowLoading,
      loadingText: 'Signing in...',
      showAlert: _showAlert,
      alertMessage: _alertMessage,
      onDismissAlert: () => setState(() => _showAlert = false),
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
              _buildAnimatedSection(
                delay: 0,
                child: _buildLoginForm(),
              ),
              const SizedBox(height: 28),
              _buildAnimatedSection(
                delay: 120,
                child: _buildSignUpSection(),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return _buildGlassPanel(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
      child: Form(
        key: _formKey,
        autovalidateMode: _hasAttemptedSubmit
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        child: Column(
          children: [
            SizedBox(
              height: 44,
              width: double.infinity,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      style: IconButton.styleFrom(
                        foregroundColor: scheme.onSurface,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(44, 44),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed:
                          widget.dismiss ?? () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back, size: 24),
                    ),
                  ),
                  Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.surface.withValues(
                          alpha: isDark ? 0.38 : 0.72,
                        ),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: scheme.outline.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.lock_open_rounded,
                              color: scheme.primary,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "Secure Login",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.25,
                                color: scheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Image.asset(
              'assets/logo.png',
              width: 104,
              height: 104,
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
                    size: 104,
                    color: Colors.white,
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            Text(
              "Sign In",
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Enter your email or username to jump back into your "
              "stream community.",
              style: TextStyle(
                fontSize: 16,
                color: scheme.onSurfaceVariant,
                height: 1.45,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            _buildFieldLabel("Email or Username"),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _emailController,
              hint: "yourname or you@example.com",
              icon: Icons.person_outline_rounded,
              focusNode: _emailFocusNode,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [
                AutofillHints.username,
                AutofillHints.email
              ],
              validator: _validateEmailOrUsername,
              onEditingComplete: () {
                _passwordFocusNode.requestFocus();
              },
            ),
            const SizedBox(height: 16),
            _buildFieldLabel("Password"),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _passwordController,
              hint: "Enter your password",
              icon: Icons.lock_outline_rounded,
              focusNode: _passwordFocusNode,
              isPassword: true,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              validator: _validatePassword,
              onSubmitted: (_) => _handleSignIn(),
            ),
            const SizedBox(height: 28),
            _buildSignInButton(),
            const SizedBox(height: 10),
            _buildForgotPasswordSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String text) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: scheme.onSurfaceVariant,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    FocusNode? focusNode,
    bool isPassword = false,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    Iterable<String>? autofillHints,
    String? Function(String?)? validator,
    VoidCallback? onEditingComplete,
    void Function(String)? onSubmitted,
  }) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color fill = scheme.surfaceContainerHighest.withValues(
      alpha: isDark ? 0.55 : 0.75,
    );
    final Color border = scheme.outline.withValues(alpha: 0.4);
    final Color iconFg = scheme.onSurface.withValues(alpha: 0.65);
    return Container(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border, width: 1),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: TextFormField(
        focusNode: focusNode,
        controller: controller,
        obscureText: isPassword && _obscurePassword,
        keyboardType: isPassword ? TextInputType.visiblePassword : keyboardType,
        textInputAction: textInputAction,
        autofillHints: autofillHints,
        autocorrect: !isPassword,
        enableSuggestions: !isPassword,
        validator: validator,
        onEditingComplete: onEditingComplete,
        onFieldSubmitted: onSubmitted,
        style: TextStyle(color: scheme.onSurface),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
          ),
          prefixIcon: Icon(icon, color: iconFg),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    color: iconFg,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildSignInButton() {
    final authService = ref.watch(robustAuthServiceProvider);
    final isEnabled = _emailController.text.isNotEmpty &&
        _passwordController.text.isNotEmpty &&
        !authService.shouldShowLoading;

    return Opacity(
      opacity: isEnabled ? 1.0 : 0.5,
      child: Semantics(
        button: true,
        enabled: isEnabled,
        label: 'Sign in',
        child: _PressableAuthButton(
          enabled: isEnabled,
          onTap: _handleSignIn,
          child: Container(
            width: double.infinity,
            height: 54,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isEnabled
                    ? const [Color(0xFF955CFF), Color(0xFF3D99F7)]
                    : const [Color(0xFF7158A6), Color(0xFF4D6690)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isEnabled
                    ? Colors.white.withValues(alpha: 0.16)
                    : Colors.white.withValues(alpha: 0.08),
              ),
              boxShadow: isEnabled
                  ? const [
                      BoxShadow(
                        color: Color(0x44318FFF),
                        blurRadius: 24,
                        offset: Offset(0, 10),
                      ),
                    ]
                  : const [],
            ),
            child: const Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.login_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 10),
                  Text(
                    "Sign In",
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
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

  String? _validateEmailOrUsername(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) {
      return 'Enter your email or username';
    }
    if (AuthLoginInput.isEmailFormat(input)) {
      return null;
    }
    if (input.contains('@')) {
      return 'Enter a valid email address';
    }
    if (input.length < 3) {
      return 'Username must be at least 3 characters';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if ((value ?? '').isEmpty) {
      return 'Enter your password';
    }
    return null;
  }

  Future<void> _handleSignIn() async {
    setState(() {
      _hasAttemptedSubmit = true;
    });

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    TextInput.finishAutofillContext();
    FocusScope.of(context).unfocus();

    final emailOrUsername = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      final authService = ref.read(robustAuthServiceProvider);
      final bool isEmail = AuthLoginInput.isEmailFormat(emailOrUsername);
      late final AuthRequestResult result;
      if (isEmail) {
        debugPrint("🔐 Signing in with email: $emailOrUsername");
        result = await authService.debouncedSignInWithEmail(
          emailOrUsername,
          password,
        );
      } else {
        debugPrint("🔐 Signing in with username: $emailOrUsername");
        result = await authService.debouncedSignInWithUsername(
          emailOrUsername,
          password,
        );
      }
      if (!result.success && mounted) {
        setState(() {
          _alertMessage = _getUserFriendlyErrorMessage(result.error ?? '');
          _showAlert = true;
        });
      } else if (result.success && result.requires2FA && mounted) {
        // User requires 2FA verification
        final user = firebase_auth.FirebaseAuth.instance.currentUser;
        if (user != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => TwoFactorVerificationView(
                userId: user.uid,
                onVerified: (bool verified) async {
                  if (verified && mounted) {
                    Navigator.of(context).pop();
                    WidgetsBinding.instance.addPostFrameCallback((_) async {
                      if (!mounted) return;
                      await navigateAfterAuthenticated(context);
                    });
                  }
                },
                onCancel: () {
                  // Sign out and pop verification view
                  firebase_auth.FirebaseAuth.instance.signOut();
                  if (mounted) {
                    Navigator.of(context).pop();
                  }
                },
              ),
            ),
          );
        }
      } else if (result.success && mounted) {
        await navigateAfterAuthenticated(context);
      }
    } catch (e) {
      debugPrint("❌ Sign-in error: $e");
      if (mounted) {
        setState(() {
          _alertMessage = _getUserFriendlyErrorMessage(e.toString());
          _showAlert = true;
        });
      }
    }
  }

  Widget _buildForgotPasswordSection() {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return TextButton(
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const ForgotPasswordView(),
          ),
        );
      },
      child: Text(
        "Forgot Password?",
        style: TextStyle(
          fontSize: 14,
          color: scheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
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
        TextButton(
          onPressed: () {
            Navigator.of(context).pushReplacement(
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
        ),
      ],
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
    final Color panelBorder =
        scheme.outline.withValues(alpha: isDark ? 0.35 : 0.45);
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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
      ),
    );
  }

  String _getUserFriendlyErrorMessage(String error) {
    if (error.contains('user-not-found') ||
        error.contains('Username not found') ||
        error.contains('No account found')) {
      return 'No account found with this email or username.';
    } else if (error.contains('wrong-password') ||
        error.contains('invalid-credential')) {
      return 'Incorrect password';
    } else if (error.contains('invalid-email')) {
      return 'Invalid email format';
    } else if (error.contains('too-many-requests')) {
      return 'Too many attempts. Please try again later';
    } else if (error.contains('network')) {
      return 'Network error. Please check your connection';
    } else {
      return 'Sign-in failed. Please check your credentials';
    }
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
