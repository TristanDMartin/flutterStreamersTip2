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
  bool _showAlert = false;
  String _alertMessage = "";
  Brightness? _appliedSystemUiBrightness;

  @override
  void initState() {
    super.initState();
    ref.listenManual<RobustAuthenticationService>(
      robustAuthServiceProvider,
      (RobustAuthenticationService? previous,
          RobustAuthenticationService next) {
        if (!next.isLoggedIn || !mounted) {
          return;
        }
        final firebase_auth.User? user =
            firebase_auth.FirebaseAuth.instance.currentUser;
        if (user != null && !user.emailVerified) {
          return;
        }
        debugPrint('✅ User authenticated, resolving post-auth destination');
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) {
            return;
          }
          await navigateAfterAuthenticated(context);
        });
      },
    );
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _applySystemUiForTheme();
  }

  void _applySystemUiForTheme() {
    final ThemeData theme = Theme.of(context);
    final Brightness brightness = theme.brightness;
    if (_appliedSystemUiBrightness == brightness) {
      return;
    }
    _appliedSystemUiBrightness = brightness;
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

  @override
  Widget build(BuildContext context) {
    final bool showLoading = ref.watch(
      robustAuthServiceProvider.select(
        (RobustAuthenticationService auth) => auth.shouldShowLoading,
      ),
    );

    return AuthPageShell(
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      minHeightBottomPadding: 20,
      showLoading: showLoading,
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
          _SignupAuthTextField(
            qaFieldKey: QaKeys.authSignupEmail,
            controller: _emailController,
            hint: 'Email',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          _SignupAuthTextField(
            qaFieldKey: QaKeys.authSignupUsername,
            controller: _usernameController,
            hint: 'Username',
            icon: Icons.person_outline_rounded,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          _SignupAuthTextField(
            qaFieldKey: QaKeys.authSignupPassword,
            controller: _passwordController,
            hint: 'Password',
            icon: Icons.lock_outline_rounded,
            isPassword: true,
            textInputAction: TextInputAction.next,
          ),
          _SignupPasswordRequirementsPanel(
            passwordController: _passwordController,
          ),
          const SizedBox(height: 16),
          _SignupAuthTextField(
            qaFieldKey: QaKeys.authSignupConfirmPassword,
            controller: _confirmPasswordController,
            hint: 'Confirm Password',
            icon: Icons.lock_outline_rounded,
            isPassword: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _handleSignUp(),
          ),
          const SizedBox(height: 28),
          _SignupSubmitButton(
            emailController: _emailController,
            usernameController: _usernameController,
            passwordController: _passwordController,
            confirmPasswordController: _confirmPasswordController,
            onSubmit: _handleSignUp,
          ),
        ],
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
        await navigateAfterAuthenticated(context);
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
    if (error.contains('email-already-in-use') ||
        error.contains('already registered') ||
        error.contains('already in use')) {
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

PasswordStrength _calculateSignupPasswordStrength(String password) {
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

class _SignupAuthTextField extends StatefulWidget {
  const _SignupAuthTextField({
    this.qaFieldKey,
    required this.controller,
    required this.hint,
    required this.icon,
    this.isPassword = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
  });

  final Key? qaFieldKey;
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool isPassword;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final void Function(String)? onSubmitted;

  @override
  State<_SignupAuthTextField> createState() => _SignupAuthTextFieldState();
}

class _SignupAuthTextFieldState extends State<_SignupAuthTextField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color fill = scheme.surfaceContainerHighest.withValues(
      alpha: isDark ? 0.55 : 0.75,
    );
    final Color border = scheme.outline.withValues(alpha: 0.4);
    final Color focusedBorder = scheme.primary.withValues(alpha: 0.7);
    final Color iconFg = scheme.onSurface.withValues(alpha: 0.65);
    final BorderRadius borderRadius = BorderRadius.circular(18);
    OutlineInputBorder outlineBorder(
      Color color, {
      double width = 1,
    }) {
      return OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: scheme.shadow.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: TextField(
        key: widget.qaFieldKey,
        controller: widget.controller,
        obscureText: widget.isPassword && _obscureText,
        keyboardType: widget.isPassword
            ? TextInputType.visiblePassword
            : widget.keyboardType,
        textInputAction: widget.textInputAction,
        onSubmitted: widget.onSubmitted,
        autocorrect: !widget.isPassword,
        enableSuggestions: !widget.isPassword,
        style: TextStyle(color: scheme.onSurface),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: TextStyle(
            color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
          ),
          prefixIcon: Icon(widget.icon, color: iconFg),
          suffixIcon: widget.isPassword
              ? IconButton(
                  icon: Icon(
                    _obscureText ? Icons.visibility : Icons.visibility_off,
                    color: iconFg,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureText = !_obscureText;
                    });
                  },
                )
              : null,
          filled: true,
          fillColor: fill,
          border: outlineBorder(border),
          enabledBorder: outlineBorder(border),
          focusedBorder: outlineBorder(focusedBorder, width: 1.5),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 18,
          ),
        ),
      ),
    );
  }
}

class _SignupPasswordRequirementsPanel extends StatefulWidget {
  const _SignupPasswordRequirementsPanel({
    required this.passwordController,
  });

  final TextEditingController passwordController;

  @override
  State<_SignupPasswordRequirementsPanel> createState() =>
      _SignupPasswordRequirementsPanelState();
}

class _SignupPasswordRequirementsPanelState
    extends State<_SignupPasswordRequirementsPanel> {
  Timer? _debounce;
  PasswordStrength _strength = PasswordStrength.none;
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    widget.passwordController.addListener(_handlePasswordChanged);
    _syncFromController();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.passwordController.removeListener(_handlePasswordChanged);
    super.dispose();
  }

  void _handlePasswordChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 140), _syncFromController);
  }

  void _syncFromController() {
    if (!mounted) {
      return;
    }
    final String password = widget.passwordController.text;
    final bool nextVisible = password.isNotEmpty;
    final PasswordStrength nextStrength =
        _calculateSignupPasswordStrength(password);
    if (nextVisible == _isVisible && nextStrength == _strength) {
      return;
    }
    setState(() {
      _isVisible = nextVisible;
      _strength = nextStrength;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) {
      return const SizedBox.shrink();
    }
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Map<String, bool> requirements =
        PasswordRequirements.checklist(widget.passwordController.text);
    final Color borderColor = _strength == PasswordStrength.strong
        ? StThemeColors.successGreen
        : _strength == PasswordStrength.medium
            ? StThemeColors.warningAmber
            : scheme.error.withValues(alpha: 0.55);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  'Password strength: ',
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  _strength.label,
                  style: TextStyle(
                    color: _strength.color,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SignupRequirementItem(
              text: 'At least 8 characters',
              met: requirements['length']!,
            ),
            _SignupRequirementItem(
              text: 'One uppercase letter',
              met: requirements['uppercase']!,
            ),
            _SignupRequirementItem(
              text: 'One lowercase letter',
              met: requirements['lowercase']!,
            ),
            _SignupRequirementItem(
              text: 'One number',
              met: requirements['number']!,
            ),
            _SignupRequirementItem(
              text: 'One special character (!@#\$%^&*)',
              met: requirements['special']!,
            ),
            _SignupRequirementItem(
              text: 'Not a common password',
              met: requirements['notWeak']!,
            ),
            _SignupRequirementItem(
              text: 'No triple repeated characters (aaa)',
              met: requirements['notTripleRepeat']!,
            ),
          ],
        ),
      ),
    );
  }
}

class _SignupRequirementItem extends StatelessWidget {
  const _SignupRequirementItem({
    required this.text,
    required this.met,
  });

  final String text;
  final bool met;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
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
}

class _SignupSubmitButton extends ConsumerWidget {
  const _SignupSubmitButton({
    required this.emailController,
    required this.usernameController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.onSubmit,
  });

  final TextEditingController emailController;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isLoading = ref.watch(
      robustAuthServiceProvider.select(
        (RobustAuthenticationService auth) => auth.shouldShowLoading,
      ),
    );
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        emailController,
        usernameController,
        passwordController,
        confirmPasswordController,
      ]),
      builder: (BuildContext context, Widget? child) {
        final PasswordStrength strength =
            _calculateSignupPasswordStrength(passwordController.text);
        final bool isEnabled = emailController.text.isNotEmpty &&
            usernameController.text.isNotEmpty &&
            passwordController.text.isNotEmpty &&
            confirmPasswordController.text.isNotEmpty &&
            strength == PasswordStrength.strong &&
            !isLoading;
        return Opacity(
          opacity: isEnabled ? 1.0 : 0.5,
          child: Semantics(
            key: QaKeys.authSignupSubmit,
            button: true,
            enabled: isEnabled,
            label: 'Create account',
            child: _PressableSignupButton(
              enabled: isEnabled,
              onTap: onSubmit,
              child: Container(
                width: double.infinity,
                height: 54,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isEnabled
                        ? const <Color>[Color(0xFF955CFF), Color(0xFF3D99F7)]
                        : const <Color>[
                            Color(0xFF7158A6),
                            Color(0xFF4D6690),
                          ],
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
                      Icon(
                        Icons.person_add_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Create Account',
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
      },
    );
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
