import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/robust_auth_service.dart';
import 'signup_view.dart';
import 'forgot_password_dialog.dart';

class RobustEmailLoginView extends ConsumerStatefulWidget {
  final VoidCallback? dismiss;
  
  const RobustEmailLoginView({
    super.key,
    this.dismiss,
  });

  @override
  ConsumerState<RobustEmailLoginView> createState() => _RobustEmailLoginViewState();
}

class _RobustEmailLoginViewState extends ConsumerState<RobustEmailLoginView> {
  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _identifierFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  
  bool _isPasswordVisible = false;
  bool _saveToiCloud = true;
  String? _errorMessage;
  bool _showSignup = false;
  
  // Request tracking
  Timer? _debounceTimer;
  
  // Constants
  static const Duration _debounceDelay = Duration(milliseconds: 300);

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    _identifierFocusNode.dispose();
    _passwordFocusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = ref.watch(robustAuthServiceProvider);
    final isLoading = authService.shouldShowLoading;
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.white),
          onPressed: widget.dismiss ?? () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1a1a2e),
              Color(0xFF16213e),
              Color(0xFF0f3460),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Column(
              children: [
                // Title
                const Text(
                  "Sign in with email or username",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 32),
                
                // Identifier Field (Email or Username)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _identifierController,
                    focusNode: _identifierFocusNode,
                    enabled: !isLoading,
                    decoration: InputDecoration(
                      hintText: 'Email or username',
                      helperText: 'Enter your email address or username',
                      helperStyle: TextStyle(color: Colors.grey[300], fontSize: 12),
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      filled: true,
                      fillColor: Colors.grey.withValues(alpha:0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(16),
                      prefixIcon: const Icon(Icons.person, color: Colors.grey),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    textCapitalization: TextCapitalization.none,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => _validateForm(),
                    onSubmitted: (_) => _continueWithEmail(),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Password Field
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _passwordController,
                    focusNode: _passwordFocusNode,
                    enabled: !isLoading,
                    obscureText: !_isPasswordVisible,
                    decoration: InputDecoration(
                      hintText: 'Password',
                      helperText: _getPasswordHelperText(),
                      helperStyle: TextStyle(color: _getPasswordHelperColor(), fontSize: 12),
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      filled: true,
                      fillColor: Colors.grey.withValues(alpha:0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(16),
                      prefixIcon: const Icon(Icons.lock, color: Colors.grey),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                    ),
                    textInputAction: TextInputAction.done,
                    onChanged: (_) => _validateForm(),
                    onSubmitted: (_) => _continueWithEmail(),
                  ),
                ),
                
                // Error Message
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha:0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withValues(alpha:0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                
                const SizedBox(height: 24),
                
                // Continue Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _canContinue() && !isLoading ? _debouncedContinueWithEmail : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _canContinue() && !isLoading 
                            ? const Color(0xFF1670de) 
                            : Colors.grey.withValues(alpha:0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Continue',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Forgot Password Button
                if (!_showSignup) ...[
                  Center(
                    child: TextButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => const ForgotPasswordDialog(),
                        );
                      },
                      child: const Text(
                        'Forgot Password?',
                        style: TextStyle(
                          color: Color(0xFF1670de),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                
                // Sign up link
                if (!_showSignup) ...[
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _showSignup = true;
                      });
                    },
                    child: const Text(
                      "Don't have an account? Sign up",
                      style: TextStyle(
                        color: Color(0xFF1670de),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ] else ...[
                  const SignupView(),
                ],
                
                const Spacer(),
                
                // iCloud save option
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _saveToiCloud,
                        onChanged: isLoading ? null : (value) {
                          setState(() {
                            _saveToiCloud = value ?? true;
                          });
                        },
                        activeColor: const Color(0xFF1670de),
                      ),
                      const Expanded(
                        child: Text(
                          'Save login info to iCloud for easy access across devices',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _canContinue() {
    final identifier = _identifierController.text.trim();
    final password = _passwordController.text.trim();
    
    return identifier.isNotEmpty && 
           password.isNotEmpty && 
           password.length >= 6;
  }

  void _validateForm() {
    setState(() {
      // Clear error when user starts typing
      if (_errorMessage != null) {
        _errorMessage = null;
      }
    });
  }

  String _getPasswordHelperText() {
    final length = _passwordController.text.length;
    if (length == 0) return 'Enter your password';
    if (length < 6) return 'Password must be at least 6 characters';
    return 'Password looks good';
  }

  Color _getPasswordHelperColor() {
    final length = _passwordController.text.length;
    if (length == 0) return Colors.grey[300]!;
    if (length < 6) return Colors.orange[300]!;
    return Colors.green[300]!;
  }

  /// Debounced continue with email - prevents multiple rapid taps
  void _debouncedContinueWithEmail() {
    // Cancel any existing debounce timer
    _debounceTimer?.cancel();
    
    // Start new debounce timer
    _debounceTimer = Timer(_debounceDelay, () {
      _continueWithEmail();
    });
  }

  Future<void> _continueWithEmail() async {
    if (!_canContinue()) return;
    
    final identifier = _identifierController.text.trim();
    final password = _passwordController.text.trim();
    
    // debugPrint("📧 Continuing with email/username: $identifier");
    
    // Clear previous errors immediately
    setState(() {
      _errorMessage = null;
    });
    
    try {
      final authService = ref.read(robustAuthServiceProvider.notifier);
      
      AuthRequestResult result;
      
      if (identifier.contains("@")) {
        // It's an email - use Firebase email auth
    debugPrint("📧 Detected email input, using email authentication");
        result = await authService.debouncedSignInWithEmail(identifier, password);
      } else {
        // It's a username - use username authentication
    debugPrint("👤 Detected username input, using username authentication");
        result = await authService.debouncedSignInWithUsername(identifier, password);
      }
      
      // Only process result if this is still the current request
      if (result.success) {
    debugPrint("✅ Authentication successful (request: ${result.requestId})");
        if (mounted) {
          Navigator.of(context).pop();
        }
      } else {
    debugPrint("❌ Authentication failed: ${result.error} (request: ${result.requestId})");
        if (mounted) {
          setState(() {
            _errorMessage = _getUserFriendlyErrorMessage(result.error ?? 'Unknown error');
          });
        }
      }
    } catch (e) {
    // debugPrint("❌ Authentication error: $e");
      if (mounted) {
        setState(() {
          _errorMessage = _getUserFriendlyErrorMessage(e.toString());
        });
      }
    }
  }

  String _getUserFriendlyErrorMessage(String error) {
    if (error.contains('user-not-found') || error.contains('Username not found')) {
      return 'No account found for that email/username';
    } else if (error.contains('wrong-password') || error.contains('Incorrect password')) {
      return 'Incorrect password. Try again.';
    } else if (error.contains('too-many-requests')) {
      return 'Too many attempts. Try again later.';
    } else if (error.contains('invalid-email')) {
      return 'Please enter a valid email address';
    } else if (error.contains('user-disabled')) {
      return 'This account has been disabled';
    } else if (error.contains('network-request-failed')) {
      return 'Network error. Check your connection.';
    } else if (error.contains('Request cancelled')) {
      return 'Request cancelled';
    } else {
      return 'Sign in failed. Please try again.';
    }
  }
}
