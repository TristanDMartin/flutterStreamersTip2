import 'dart:async';
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/st_theme_tokens.dart';
import '../services/robust_auth_service.dart';
import '../utils/auth_post_login_navigation.dart';
import '../utils/password_validation.dart';
import '../qa/qa_keys.dart';
import 'auth_page_shell.dart';
import 'email_verification_view.dart';
import 'email_login_view.dart';

class SignupView extends ConsumerStatefulWidget {
  final VoidCallback? dismiss;

  const SignupView({
    super.key,
    this.dismiss,
  });

  @override
  ConsumerState<SignupView> createState() => _SignupViewState();
}

class _SignupViewState extends ConsumerState<SignupView> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _showAlert = false;
  String _alertMessage = "";
  PasswordStrength _passwordStrength = PasswordStrength.none;
  Timer? _passwordStrengthDebounce;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_schedulePasswordStrengthUpdate);
    _emailController.addListener(_onAnyFieldChanged);
    _usernameController.addListener(_onAnyFieldChanged);
    _confirmPasswordController.addListener(_onAnyFieldChanged);
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
    );
  }

  void _onAnyFieldChanged() {
    if (mounted) {
      setState(() {});
    }
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
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    );
  }

  @override
  void dispose() {
    _passwordStrengthDebounce?.cancel();
    _passwordController.removeListener(_schedulePasswordStrengthUpdate);
    _emailController.removeListener(_onAnyFieldChanged);
    _usernameController.removeListener(_onAnyFieldChanged);
    _confirmPasswordController.removeListener(_onAnyFieldChanged);
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _resetSystemUIOverlayStyle();
    super.dispose();
  }

  void _resetSystemUIOverlayStyle() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
    );

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.black,
      ),
    );
  }

  void _schedulePasswordStrengthUpdate() {
    _passwordStrengthDebounce?.cancel();
    _passwordStrengthDebounce = Timer(const Duration(milliseconds: 140), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _passwordStrength =
            _calculatePasswordStrength(_passwordController.text);
      });
    });
  }

  PasswordStrength _calculatePasswordStrength(String password) {
    if (password.isEmpty) {
      return PasswordStrength.none;
    }
    final Map<String, bool> requirements =
        PasswordRequirements.checklist(password);
    final int metCount = requirements.values.where((bool met) => met).length;
    if (metCount == requirements.length) {
      return PasswordStrength.strong;
    }
    if (metCount >= 5) {
      return PasswordStrength.medium;
    }
    return PasswordStrength.weak;
  }

  @override
  Widget build(BuildContext context) {
    final authService = ref.watch(robustAuthServiceProvider);
    ref.listen(robustAuthServiceProvider, (previous, next) {
      if (next.isLoggedIn && mounted) {
        final firebase_auth.User? u =
            firebase_auth.FirebaseAuth.instance.currentUser;
        if (u != null && !u.emailVerified) {
          return;
        }
        debugPrint("✅ User authenticated, resolving post-auth destination");
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          await navigateAfterAuthenticated(context);
        });
      }
    });

    return AuthPageShell(
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      minHeightBottomPadding: 20,
      showLoading: authService.shouldShowLoading,
      loadingText: 'Creating account...',
      showAlert: _showAlert,
      alertMessage: _alertMessage,
      onDismissAlert: () => setState(() => _showAlert = false),
      content: Column(
        children: <Widget>[
          _buildSignupForm(),
          const SizedBox(height: 20),
          _buildSignInSection(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildTopBarRow() {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
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
                  widget.dismiss ?? () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back, size: 24),
            ),
          ),
          Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: isDark ? 0.38 : 0.72),
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
                      Icons.person_add_alt_1_rounded,
                      color: scheme.primary,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "New account",
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
    );
  }

  Widget _buildSignupForm() {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return _buildGlassPanel(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTopBarRow(),
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
            "Create Account",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Join StreamersTip today",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              height: 1.45,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 28),
          _buildTextField(
            qaFieldKey: QaKeys.authSignupEmail,
            controller: _emailController,
            hint: "Email",
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            qaFieldKey: QaKeys.authSignupUsername,
            controller: _usernameController,
            hint: "Username",
            icon: Icons.person_outline_rounded,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            qaFieldKey: QaKeys.authSignupPassword,
            controller: _passwordController,
            hint: "Password",
            icon: Icons.lock_outline_rounded,
            isPassword: true,
            textInputAction: TextInputAction.next,
          ),
          if (_passwordController.text.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildPasswordRequirements(),
          ],
          const SizedBox(height: 16),
          _buildTextField(
            qaFieldKey: QaKeys.authSignupConfirmPassword,
            controller: _confirmPasswordController,
            hint: "Confirm Password",
            icon: Icons.lock_outline_rounded,
            isPassword: true,
            obscureOverride: _obscureConfirmPassword,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _handleSignUp(),
          ),
          const SizedBox(height: 28),
          _buildSignUpButton(),
        ],
      ),
    );
  }

  Widget _buildTextField({
    Key? qaFieldKey,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool? obscureOverride,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    void Function(String)? onSubmitted,
  }) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color fill = scheme.surfaceContainerHighest.withValues(
      alpha: isDark ? 0.55 : 0.75,
    );
    final Color border = scheme.outline.withValues(alpha: 0.4);
    final Color iconFg = scheme.onSurface.withValues(alpha: 0.65);
    final obscure = obscureOverride ?? (isPassword && _obscurePassword);
    return Container(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border, width: 1),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: TextField(
        key: qaFieldKey,
        controller: controller,
        obscureText: obscure,
        keyboardType: isPassword ? TextInputType.visiblePassword : keyboardType,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        autocorrect: !isPassword,
        enableSuggestions: !isPassword,
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
                    obscure ? Icons.visibility : Icons.visibility_off,
                    color: iconFg,
                  ),
                  onPressed: () {
                    setState(() {
                      if (obscureOverride != null) {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      } else {
                        _obscurePassword = !_obscurePassword;
                      }
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordRequirements() {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final password = _passwordController.text;
    final Map<String, bool> requirements =
        PasswordRequirements.checklist(password);
    final Color borderColor = _passwordStrength == PasswordStrength.strong
        ? StThemeColors.successGreen
        : _passwordStrength == PasswordStrength.medium
            ? StThemeColors.warningAmber
            : scheme.error.withValues(alpha: 0.55);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "Password strength: ",
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                _passwordStrength.label,
                style: TextStyle(
                  color: _passwordStrength.color,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildRequirementItem(
            "At least 8 characters",
            requirements['length']!,
          ),
          _buildRequirementItem(
            "One uppercase letter",
            requirements['uppercase']!,
          ),
          _buildRequirementItem(
            "One lowercase letter",
            requirements['lowercase']!,
          ),
          _buildRequirementItem("One number", requirements['number']!),
          _buildRequirementItem(
            "One special character (!@#\$%^&*)",
            requirements['special']!,
          ),
          _buildRequirementItem(
            'Not a common password',
            requirements['notWeak']!,
          ),
          _buildRequirementItem(
            'No triple repeated characters (aaa)',
            requirements['notTripleRepeat']!,
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementItem(String text, bool met) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle : Icons.cancel,
            color: met
                ? StThemeColors.successGreen
                : scheme.error.withValues(alpha: 0.55),
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: met ? scheme.onSurface : scheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignUpButton() {
    final authService = ref.watch(robustAuthServiceProvider);
    final bool isEnabled = _emailController.text.isNotEmpty &&
        _usernameController.text.isNotEmpty &&
        _passwordController.text.isNotEmpty &&
        _confirmPasswordController.text.isNotEmpty &&
        _passwordStrength == PasswordStrength.strong &&
        !authService.shouldShowLoading;
    return Opacity(
      opacity: isEnabled ? 1.0 : 0.5,
      child: Semantics(
        key: QaKeys.authSignupSubmit,
        button: true,
        enabled: isEnabled,
        label: 'Create account',
        child: _PressableSignupButton(
          enabled: isEnabled,
          onTap: _handleSignUp,
          child: Container(
            width: double.infinity,
            height: 54,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isEnabled
                    ? const <Color>[Color(0xFF955CFF), Color(0xFF3D99F7)]
                    : const <Color>[Color(0xFF7158A6), Color(0xFF4D6690)],
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
                  ? const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x44318FFF),
                        blurRadius: 24,
                        offset: Offset(0, 10),
                      ),
                    ]
                  : const <BoxShadow>[],
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const <Widget>[
                  Icon(Icons.person_add_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Text(
                    "Create Account",
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

  Future<void> _handleSignUp() async {
    final email = _emailController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    if (email.isEmpty || username.isEmpty || password.isEmpty) {
      setState(() {
        _alertMessage = "Please fill in all fields";
        _showAlert = true;
      });
      return;
    }
    if (!_isValidEmail(email)) {
      setState(() {
        _alertMessage = "Please enter a valid email address";
        _showAlert = true;
      });
      return;
    }
    if (username.length < 3) {
      setState(() {
        _alertMessage = "Username must be at least 3 characters";
        _showAlert = true;
      });
      return;
    }
    final RegExp usernameChars = RegExp(r'^[a-zA-Z0-9_]+$');
    if (!usernameChars.hasMatch(username)) {
      setState(() {
        _alertMessage =
            'Username can only contain letters, numbers, and underscores.';
        _showAlert = true;
      });
      return;
    }
    if (password != confirmPassword) {
      setState(() {
        _alertMessage = "Passwords do not match";
        _showAlert = true;
      });
      return;
    }
    if (!PasswordRequirements.meetsSignupPolicy(password)) {
      setState(() {
        _alertMessage = PasswordRequirements.signupRejectReason(password) ??
            'Please meet all password requirements';
        _showAlert = true;
      });
      return;
    }

    try {
      final authService = ref.read(robustAuthServiceProvider);
      final result = await authService.debouncedSignUpWithEmail(
        email: email,
        password: password,
        displayName: username,
        username: username,
      );
      if (!result.success && mounted) {
        setState(() {
          _alertMessage = _getUserFriendlyErrorMessage(result.error ?? '');
          _showAlert = true;
        });
      } else if (result.success && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => EmailVerificationView(
              email: email,
              onVerified: () {
                debugPrint("✅ Email verified, user can access app");
              },
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("❌ Sign-up error: $e");
      if (mounted) {
        setState(() {
          _alertMessage = _getUserFriendlyErrorMessage(e.toString());
          _showAlert = true;
        });
      }
    }
  }

  Widget _buildSignInSection() {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Already have an account?",
          style: TextStyle(
            fontSize: 14,
            color: scheme.onSurfaceVariant,
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const EmailLoginView()),
            );
          },
          child: Text(
            "Sign in",
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
              boxShadow: <BoxShadow>[
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

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  String _getUserFriendlyErrorMessage(String error) {
    if (error.contains('email-already-in-use')) {
      return 'This email is already registered';
    } else if (error.contains('invalid-email')) {
      return 'Invalid email format';
    } else if (error.contains('weak-password')) {
      return 'Password is too weak';
    } else if (error.contains('username') && error.contains('taken')) {
      return 'This username is already taken';
    } else if (error.contains('network')) {
      return 'Network error. Please check your connection';
    } else {
      return 'Sign-up failed. Please try again';
    }
  }
}

class _PressableSignupButton extends StatefulWidget {
  const _PressableSignupButton({
    required this.child,
    required this.onTap,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback onTap;
  final bool enabled;

  @override
  State<_PressableSignupButton> createState() => _PressableSignupButtonState();
}

class _PressableSignupButtonState extends State<_PressableSignupButton> {
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
        onTap: widget.enabled ? widget.onTap : null,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        child: widget.child,
      ),
    );
  }
}

enum PasswordStrength {
  none,
  weak,
  medium,
  strong;

  String get label {
    switch (this) {
      case PasswordStrength.none:
        return 'None';
      case PasswordStrength.weak:
        return 'Weak';
      case PasswordStrength.medium:
        return 'Medium';
      case PasswordStrength.strong:
        return 'Strong';
    }
  }

  Color get color {
    switch (this) {
      case PasswordStrength.none:
        return Colors.grey;
      case PasswordStrength.weak:
        return StThemeColors.errorRed;
      case PasswordStrength.medium:
        return StThemeColors.warningAmber;
      case PasswordStrength.strong:
        return StThemeColors.successGreen;
    }
  }
}
