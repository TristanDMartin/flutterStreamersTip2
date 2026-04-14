import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/pending_auth_redirect_service.dart';
import '../services/robust_auth_service.dart';
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
    _setSystemUIOverlayStyle();
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
              GestureDetector(
                onTap: () {
                  FocusScope.of(context).unfocus();
                },
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
                    child: SafeArea(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 8,
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight:
                                MediaQuery.of(context).size.height -
                                MediaQuery.of(context).padding.top -
                                16,
                          ),
                          child: Column(
                            children: [
                              _buildHeader(),
                              const SizedBox(height: 28),
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
                    ),
                  ),
                ),
              ),
              if (authService.shouldShowLoading)
                Container(
                  color: Colors.black.withValues(alpha: 0.3),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
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
              if (_showAlert) ...[
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
                        "Error",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      content: Text(
                        _alertMessage.isEmpty
                            ? "Something went wrong."
                            : _alertMessage,
                        style: const TextStyle(
                          color: Colors.white70,
                          height: 1.3,
                        ),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: widget.dismiss ?? () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.arrow_back,
              color: Colors.white,
              size: 24,
            ),
          ),
          const Expanded(
            child: Text(
              "Sign In",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 48), // Balance the back button
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return _buildGlassPanel(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
      child: Form(
        key: _formKey,
        autovalidateMode: _hasAttemptedSubmit
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        child: Column(
          children: [
            Container(
              width: 116,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_open_rounded,
                      color: Color(0xFF9BD1FF), size: 16),
                  SizedBox(width: 6),
                  Text(
                    "Secure Login",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.25,
                      color: Colors.white,
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
            const Text(
              "Sign In",
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Enter your email or username to jump back into your stream community.",
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFFE1E6FF),
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
              autofillHints: const [AutofillHints.username, AutofillHints.email],
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
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFFDDE3FF),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: TextFormField(
        focusNode: focusNode,
        controller: controller,
        obscureText: isPassword && _obscurePassword,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        autofillHints: autofillHints,
        validator: validator,
        onEditingComplete: onEditingComplete,
        onFieldSubmitted: onSubmitted,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
          ),
          prefixIcon: Icon(icon, color: Colors.white.withValues(alpha: 0.7)),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    color: Colors.white.withValues(alpha: 0.7),
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
                    ? const [Color(0xFFAB6CFF), Color(0xFF41A5FF)]
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
    if (input.contains('@')) {
      final emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
      if (!emailPattern.hasMatch(input)) {
        return 'Enter a valid email address';
      }
    } else if (input.length < 3) {
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
      final isEmail = emailOrUsername.contains('@');
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
                onVerified: (bool verified) {
                  if (verified && mounted) {
                    Navigator.of(context).pop(); // Pop verification view
                    // Auth state listener will handle the rest
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
    return TextButton(
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const ForgotPasswordView(),
          ),
        );
      },
      child: const Text(
        "Forgot Password?",
        style: TextStyle(
          fontSize: 14,
          color: Color(0xFF9BD1FF),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildSignUpSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Don't have an account?",
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFFDDE3FF),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pushReplacement(
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
        ),
      ],
    );
  }

  Widget _buildBackgroundDecor() {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -90,
            right: -20,
            child: _buildGlowOrb(
              size: 220,
              colors: const [Color(0x55B27BFF), Color(0x00B27BFF)],
            ),
          ),
          Positioned(
            top: 220,
            left: -70,
            child: _buildGlowOrb(
              size: 180,
              colors: const [Color(0x4447C4FF), Color(0x0047C4FF)],
            ),
          ),
          Positioned(
            bottom: -50,
            right: -10,
            child: _buildGlowOrb(
              size: 170,
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
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
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

  String _getUserFriendlyErrorMessage(String error) {
    if (error.contains('user-not-found') ||
        error.contains('Username not found')) {
      return 'No account found with this email/username';
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
