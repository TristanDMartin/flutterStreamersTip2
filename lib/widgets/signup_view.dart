import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/st_theme_tokens.dart';
import '../services/pending_auth_redirect_service.dart';
import '../services/robust_auth_service.dart';
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

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_validatePassword);
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
        statusBarIconBrightness: brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarColor: theme.colorScheme.surface,
        systemNavigationBarIconBrightness: brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    );
  }

  @override
  void dispose() {
    _passwordController.removeListener(_validatePassword);
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

  void _validatePassword() {
    setState(() {
      _passwordStrength = _calculatePasswordStrength(_passwordController.text);
    });
  }

  PasswordStrength _calculatePasswordStrength(String password) {
    if (password.isEmpty) return PasswordStrength.none;
    final requirements = _checkPasswordRequirements(password);
    final metCount = requirements.values.where((met) => met).length;
    if (metCount == requirements.length) return PasswordStrength.strong;
    if (metCount >= 4) return PasswordStrength.medium;
    return PasswordStrength.weak;
  }

  Map<String, bool> _checkPasswordRequirements(String password) {
    return {
      'length': password.length >= 8,
      'uppercase': password.contains(RegExp(r'[A-Z]')),
      'lowercase': password.contains(RegExp(r'[a-z]')),
      'number': password.contains(RegExp(r'[0-9]')),
      'special': password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]')),
      'notCommon': !_isCommonPassword(password),
      'notSequential': !_hasSequentialCharacters(password),
    };
  }

  bool _isCommonPassword(String password) {
    final commonPasswords = [
      'password',
      '12345678',
      'qwerty',
      'abc123',
      'password123',
      'admin',
      'letmein',
      'welcome',
      'monkey',
      '1234567890',
      'password1',
      '123456789',
    ];
    return commonPasswords.contains(password.toLowerCase());
  }

  bool _hasSequentialCharacters(String password) {
    if (password.length < 3) return false;
    for (int i = 0; i < password.length - 2; i++) {
      final char1 = password[i].toLowerCase();
      final char2 = password[i + 1].toLowerCase();
      final char3 = password[i + 2].toLowerCase();
      if (char1.codeUnitAt(0) + 1 == char2.codeUnitAt(0) &&
          char2.codeUnitAt(0) + 1 == char3.codeUnitAt(0)) {
        return true;
      }
      if (char1 == char2 && char2 == char3) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;
    final authService = ref.watch(robustAuthServiceProvider);
    ref.listen(robustAuthServiceProvider, (previous, next) {
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
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        extendBody: true,
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
              GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: Column(
                      children: [
                        _buildSignupForm(),
                        const SizedBox(height: 20),
                        _buildSignInSection(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
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
                          "Creating account...",
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
              if (_showAlert) ...[
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => setState(() => _showAlert = false),
                    child: Container(
                      color: scheme.scrim.withValues(alpha: 0.45),
                    ),
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
                        "Error",
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      content: Text(
                        _alertMessage.isEmpty
                            ? "Something went wrong."
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
            ],
          ),
        ),
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
            controller: _emailController,
            hint: "Email",
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _usernameController,
            hint: "Username",
            icon: Icons.person_outline_rounded,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          _buildTextField(
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
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
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
    final requirements = _checkPasswordRequirements(password);
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
            "Not a common password",
            requirements['notCommon']!,
          ),
          _buildRequirementItem(
            "No sequential characters",
            requirements['notSequential']!,
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
                color: met
                    ? scheme.onSurface
                    : scheme.onSurfaceVariant,
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
    if (password != confirmPassword) {
      setState(() {
        _alertMessage = "Passwords do not match";
        _showAlert = true;
      });
      return;
    }
    if (_passwordStrength != PasswordStrength.strong) {
      setState(() {
        _alertMessage = "Please meet all password requirements";
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
              onSkip: () {
                debugPrint("⚠️ User skipped email verification");
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

  Widget _buildBackgroundDecor() {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color primarySoft = scheme.primary.withValues(alpha: 0.14);
    final Color secondarySoft = scheme.secondary.withValues(alpha: 0.1);
    return IgnorePointer(
      child: Stack(
        children: <Widget>[
          Positioned(
            top: -90,
            right: -20,
            child: _buildGlowOrb(
              size: 220,
              colors: <Color>[primarySoft, primarySoft.withValues(alpha: 0)],
            ),
          ),
          Positioned(
            top: 200,
            left: -70,
            child: _buildGlowOrb(
              size: 180,
              colors: <Color>[secondarySoft, secondarySoft.withValues(alpha: 0)],
            ),
          ),
          Positioned(
            bottom: -50,
            right: -10,
            child: _buildGlowOrb(
              size: 170,
              colors: <Color>[
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
    final Color panelBorder =
        scheme.outline.withValues(alpha: isDark ? 0.35 : 0.45);
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
