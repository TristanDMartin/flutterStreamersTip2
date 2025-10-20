import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'email_login_view.dart';

class ResetPasswordView extends ConsumerStatefulWidget {
  final String email;
  final String verificationCode;

  const ResetPasswordView({
    super.key,
    required this.email,
    required this.verificationCode,
  });

  @override
  ConsumerState<ResetPasswordView> createState() => _ResetPasswordViewState();
}

class _ResetPasswordViewState extends ConsumerState<ResetPasswordView> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _showAlert = false;
  String _alertMessage = "";
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _setSystemUIOverlayStyle();
  }

  void _setSystemUIOverlayStyle() {
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
                        const SizedBox(height: 40),
                        _buildForm(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
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
            if (_isLoading)
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
                        "Updating password...",
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
          ],
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
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.arrow_back,
              color: Colors.white,
              size: 24,
            ),
          ),
          const Expanded(
            child: SizedBox.shrink(),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.lock_reset,
            size: 60,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          "Create new password",
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          "Your new password must be different from previously used passwords.",
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        _buildPasswordTextField(),
        const SizedBox(height: 16),
        _buildConfirmPasswordTextField(),
        const SizedBox(height: 32),
        _buildResetButton(),
      ],
    );
  }

  Widget _buildPasswordTextField() {
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
        controller: _passwordController,
        obscureText: !_showPassword,
        textInputAction: TextInputAction.next,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: "New Password",
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
          ),
          prefixIcon: Icon(
            Icons.lock_outline,
            color: Colors.white.withValues(alpha: 0.7),
          ),
          suffixIcon: IconButton(
            icon: Icon(
              _showPassword ? Icons.visibility_off : Icons.visibility,
              color: Colors.white.withValues(alpha: 0.7),
            ),
            onPressed: () {
              setState(() {
                _showPassword = !_showPassword;
              });
            },
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmPasswordTextField() {
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
        controller: _confirmPasswordController,
        obscureText: !_showConfirmPassword,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _handleResetPassword(),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: "Confirm New Password",
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
          ),
          prefixIcon: Icon(
            Icons.lock_outline,
            color: Colors.white.withValues(alpha: 0.7),
          ),
          suffixIcon: IconButton(
            icon: Icon(
              _showConfirmPassword ? Icons.visibility_off : Icons.visibility,
              color: Colors.white.withValues(alpha: 0.7),
            ),
            onPressed: () {
              setState(() {
                _showConfirmPassword = !_showConfirmPassword;
              });
            },
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildResetButton() {
    final isEnabled = _passwordController.text.isNotEmpty &&
        _confirmPasswordController.text.isNotEmpty &&
        _passwordController.text == _confirmPasswordController.text &&
        !_isLoading;

    return Opacity(
      opacity: isEnabled ? 1.0 : 0.5,
      child: GestureDetector(
        onTap: isEnabled ? _handleResetPassword : null,
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
          child: Center(
            child: Text(
              _isLoading ? "Updating..." : "Update Password",
              style: const TextStyle(
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

  void _handleResetPassword() async {
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (password.isEmpty || confirmPassword.isEmpty) {
      setState(() {
        _alertMessage = "Please fill in all fields";
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

    if (password.length < 8) {
      setState(() {
        _alertMessage = "Password must be at least 8 characters long";
        _showAlert = true;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Update password using Firebase
      await FirebaseAuth.instance.currentUser?.updatePassword(password);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Show success dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1C1C1E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              "Success!",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: const Text(
              "Your password has been updated successfully.",
              style: TextStyle(
                color: Colors.white70,
                height: 1.3,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Navigate back to login
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) => const EmailLoginView(),
                    ),
                    (route) => false,
                  );
                },
                child: const Text("OK"),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint("❌ Error updating password: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _alertMessage = _getErrorMessage(e.toString());
          _showAlert = true;
        });
      }
    }
  }

  String _getErrorMessage(String error) {
    if (error.contains('weak-password')) {
      return 'Password is too weak. Please choose a stronger password';
    } else if (error.contains('requires-recent-login')) {
      return 'Please log in again before changing your password';
    } else if (error.contains('network')) {
      return 'Network error. Please check your connection';
    } else {
      return 'Failed to update password. Please try again';
    }
  }
}
