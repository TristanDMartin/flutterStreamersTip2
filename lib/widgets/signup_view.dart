import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    _setSystemUIOverlayStyle();
  }

  void _setSystemUIOverlayStyle() {
    // Force immediate system UI update
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
    );

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
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
    final authService = ref.watch(robustAuthServiceProvider);
    ref.listen(robustAuthServiceProvider, (previous, next) {
      if (next.isLoggedIn && mounted) {
        debugPrint("✅ User registered and authenticated");
        Navigator.of(context).pop();
      }
    });

    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      backgroundColor: const Color(0xFF1C135D),
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
            GestureDetector(
              onTap: () {
                FocusScope.of(context).unfocus();
              },
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 20),
                        _buildSignupForm(),
                        const SizedBox(height: 16),
                        _buildSignInSection(),
                        const SizedBox(height: 20),
                      ],
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
                        "Creating account...",
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
    );
  }

  Widget _buildHeader() {
    return const SizedBox.shrink();
  }

  Widget _buildSignupForm() {
    return Column(
      children: [
        // App Logo
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
        const SizedBox(height: 24),
        const Text(
          "Create Account",
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "Join StreamersTip today",
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        _buildTextField(
          controller: _emailController,
          hint: "Email",
          icon: Icons.email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _usernameController,
          hint: "Username",
          icon: Icons.person,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _passwordController,
          hint: "Password",
          icon: Icons.lock,
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
          icon: Icons.lock_outline,
          isPassword: true,
          obscureOverride: _obscureConfirmPassword,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _handleSignUp(),
        ),
        const SizedBox(height: 32),
        _buildSignUpButton(),
      ],
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
    final obscure = obscureOverride ?? (isPassword && _obscurePassword);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
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
                    obscure ? Icons.visibility : Icons.visibility_off,
                    color: Colors.white.withValues(alpha: 0.7),
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
    final password = _passwordController.text;
    final requirements = _checkPasswordRequirements(password);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _passwordStrength == PasswordStrength.strong
              ? Colors.green
              : _passwordStrength == PasswordStrength.medium
                  ? Colors.orange
                  : Colors.red.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                "Password Strength: ",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _passwordStrength.label,
                style: TextStyle(
                  color: _passwordStrength.color,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle : Icons.cancel,
            color: met ? Colors.green : Colors.red.withValues(alpha: 0.5),
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: met ? Colors.white : Colors.white.withValues(alpha: 0.5),
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
    final isEnabled = _emailController.text.isNotEmpty &&
        _usernameController.text.isNotEmpty &&
        _passwordController.text.isNotEmpty &&
        _confirmPasswordController.text.isNotEmpty &&
        _passwordStrength == PasswordStrength.strong &&
        !authService.shouldShowLoading;

    return Opacity(
      opacity: isEnabled ? 1.0 : 0.5,
      child: GestureDetector(
        onTap: isEnabled ? _handleSignUp : null,
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
          ),
          child: const Center(
            child: Text(
              "Create Account",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Already have an account?",
          style: TextStyle(
            fontSize: 14,
            color: Colors.white,
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const EmailLoginView()),
            );
          },
          child: const Text(
            "Sign in",
            style: TextStyle(
              fontSize: 14,
              color: Colors.pink,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
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
        return Colors.red;
      case PasswordStrength.medium:
        return Colors.orange;
      case PasswordStrength.strong:
        return Colors.green;
    }
  }
}
