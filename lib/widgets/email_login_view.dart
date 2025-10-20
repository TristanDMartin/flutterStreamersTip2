import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/robust_auth_service.dart';
import 'signup_view.dart';
import 'forgot_password_view.dart';

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
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _showAlert = false;
  String _alertMessage = "";

  @override
  void initState() {
    super.initState();
    _setSystemUIOverlayStyle();
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
        debugPrint("✅ User authenticated, navigating back");
        Navigator.of(context).pop();
      }
    });

    return Material(
      color: Colors.transparent,
      child: Scaffold(
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
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        _buildHeader(),
                        const Spacer(),
                        _buildLoginForm(),
                        const Spacer(),
                        _buildSignUpSection(),
                        const SizedBox(height: 16),
                      ],
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
            child: SizedBox.shrink(), // Empty space for balance
          ),
          const SizedBox(width: 48), // Balance the back button
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
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
          "Sign In",
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "Enter your email/username and password",
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        _buildTextField(
          controller: _emailController,
          hint: "Email or Username",
          icon: Icons.person,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _passwordController,
          hint: "Password",
          icon: Icons.lock,
          isPassword: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _handleSignIn(),
        ),
        const SizedBox(height: 32),
        _buildSignInButton(),
        const SizedBox(height: 16),
        _buildForgotPasswordSection(),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    void Function(String)? onSubmitted,
  }) {
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
        obscureText: isPassword && _obscurePassword,
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
            horizontal: 16,
            vertical: 16,
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
      child: GestureDetector(
        onTap: isEnabled ? _handleSignIn : null,
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
              "Sign In",
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

  Future<void> _handleSignIn() async {
    final emailOrUsername = _emailController.text.trim();
    final password = _passwordController.text;
    if (emailOrUsername.isEmpty || password.isEmpty) {
      setState(() {
        _alertMessage = "Please enter both email/username and password";
        _showAlert = true;
      });
      return;
    }

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
          fontSize: 16,
          color: Colors.blue,
          fontWeight: FontWeight.w500,
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
            color: Colors.white,
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
              color: Colors.pink,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
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
