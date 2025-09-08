import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/robust_auth_service.dart';
import 'robust_instant_response_button.dart';
import 'forgot_password_dialog.dart';

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
  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _identifierFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  
  bool _isPasswordVisible = false;
  bool _saveToiCloud = true;
  String? _errorMessage;
  
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
                      fillColor: Colors.grey.withOpacity(0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(16),
                      prefixIcon: const Icon(Icons.person, color: Colors.grey),
                    ),
                    style: const TextStyle(color: Colors.white),
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.none,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (_) => _validateForm(),
                    onSubmitted: (_) => _passwordFocusNode.requestFocus(),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Password Field with Visibility Toggle
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
                      helperStyle: TextStyle(
                        color: _getPasswordHelperColor(),
                        fontSize: 12,
                      ),
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      filled: true,
                      fillColor: Colors.grey.withOpacity(0.1),
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
                    style: const TextStyle(color: Colors.white),
                    textInputAction: TextInputAction.done,
                    maxLength: 18, // Hard limit
                    inputFormatters: [
                      FilteringTextInputFormatter.deny(RegExp(r'\s')), // No spaces
                    ],
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
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.red, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                
                const SizedBox(height: 24),
                
                // iCloud Toggle
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Switch(
                        value: _saveToiCloud,
                        onChanged: (value) {
                          setState(() {
                            _saveToiCloud = value;
                          });
                        },
                        activeThumbColor: const Color(0xFF1670de),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Save login info on your iCloud devices…',
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Continue Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: RobustAuthButton(
                    text: 'Continue',
                    onPressed: _canContinue() ? _debouncedContinueWithEmail : null,
                    isLoading: isLoading,
                    enabled: _canContinue(),
                    loadingText: 'Signing in...',
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Forgot Password Button
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
                
                // Sign up link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                    GestureDetector(
                      onTap: () {
                        // TODO: Navigate to signup
                      },
                      child: const Text(
                        'Sign up',
                        style: TextStyle(
                          color: Color(0xFF1670de),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const Spacer(),
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
    
    if (identifier.isEmpty || password.isEmpty) return false;
    
    // Check if identifier is valid
    if (identifier.contains("@")) {
      // Email validation
      if (!_isValidEmail(identifier)) return false;
    } else {
      // Username validation (basic)
      if (identifier.length < 3) return false;
    }
    
    // Check password rules
    return _isValidPassword(password);
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);
  }

  bool _isValidPassword(String password) {
    if (password.length < 8 || password.length > 18) return false;
    
    // Check for 3 of 4 character classes
    int classes = 0;
    if (RegExp(r'[a-z]').hasMatch(password)) classes++; // lowercase
    if (RegExp(r'[A-Z]').hasMatch(password)) classes++; // uppercase
    if (RegExp(r'[0-9]').hasMatch(password)) classes++; // digit
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) classes++; // symbol
    
    return classes >= 3;
  }

  String _getPasswordHelperText() {
    final password = _passwordController.text;
    if (password.isEmpty) {
      return '8-18 characters, 3 of 4: lowercase, uppercase, digit, symbol';
    }
    
    if (password.length < 8) {
      return 'Minimum 8 characters required';
    }
    
    if (password.length > 18) {
      return 'Maximum 18 characters allowed';
    }
    
    int classes = 0;
    if (RegExp(r'[a-z]').hasMatch(password)) classes++;
    if (RegExp(r'[A-Z]').hasMatch(password)) classes++;
    if (RegExp(r'[0-9]').hasMatch(password)) classes++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) classes++;
    
    if (classes < 3) {
      return 'Need 3 of 4 character types ($classes/4)';
    }
    
    return 'Password looks good!';
  }

  Color _getPasswordHelperColor() {
    final password = _passwordController.text;
    if (password.isEmpty) return Colors.grey[300]!;
    
    if (_isValidPassword(password)) {
      return Colors.green[300]!;
    }
    
    return Colors.orange[300]!;
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
    
    print("📧 Continuing with email/username: $identifier");
    
    // Clear previous errors immediately
    setState(() {
      _errorMessage = null;
    });
    
    try {
      final authService = ref.read(robustAuthServiceProvider.notifier);
      
      AuthRequestResult result;
      
      if (identifier.contains("@")) {
        // It's an email - use Firebase email auth
        print("📧 Detected email input, using email authentication");
        result = await authService.debouncedSignInWithEmail(identifier, password);
      } else {
        // It's a username - use username authentication
        print("👤 Detected username input, using username authentication");
        result = await authService.debouncedSignInWithUsername(identifier, password);
      }
      
      // Only process result if this is still the current request
      if (result.success) {
        print("✅ Authentication successful (request: ${result.requestId})");
        if (mounted) {
          Navigator.of(context).pop();
        }
      } else {
        print("❌ Authentication failed: ${result.error} (request: ${result.requestId})");
        if (mounted) {
          setState(() {
            _errorMessage = _getUserFriendlyErrorMessage(result.error ?? 'Unknown error');
          });
        }
      }
    } catch (e) {
      print("❌ Authentication error: $e");
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
      return 'Invalid email address';
    } else if (error.contains('user-disabled')) {
      return 'This account has been disabled';
    } else if (error.contains('No email associated with this username')) {
      return 'No email found for this username';
    } else if (error.contains('Request cancelled')) {
      return 'Request cancelled';
    } else if (error.contains('network-request-failed')) {
      return 'Network error. Check your connection.';
    } else {
      return 'Authentication failed. Please check your credentials';
    }
  }

  void _validateForm() {
    setState(() {
      // This will trigger a rebuild to update button state and helper text
    });
  }
}