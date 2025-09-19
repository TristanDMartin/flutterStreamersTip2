import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/robust_auth_service.dart';
import 'signup_view.dart';

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
  Timer? _debounceTimer;
  final Duration _debounceDelay = const Duration(milliseconds: 500);
  String? _errorMessage;

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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6137EB), Color(0xFF1C135D)],
          ),
        ),
        child: Column(
          children: [
            // Header with back button
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: widget.dismiss ?? () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.chevron_left, color: Colors.white),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),
            
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
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
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.15),
                            Colors.white.withOpacity(0.05),
                          ],
                        ),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _identifierController,
                        focusNode: _identifierFocusNode,
                        enabled: !isLoading,
                        decoration: InputDecoration(
                          hintText: 'Email or username',
                          helperText: 'Enter your email address or username',
                          helperStyle: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(16),
                          prefixIcon: const Icon(Icons.person, color: Colors.white70),
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          shadows: [
                            Shadow(
                              color: Colors.black54,
                              blurRadius: 2,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        textInputAction: TextInputAction.next,
                        textCapitalization: TextCapitalization.none,
                        keyboardType: TextInputType.emailAddress,
                        onChanged: (_) => _validateForm(),
                        onSubmitted: (_) => _passwordFocusNode.requestFocus(),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Password Field with Visibility Toggle
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.15),
                            Colors.white.withOpacity(0.05),
                          ],
                        ),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _passwordController,
                        focusNode: _passwordFocusNode,
                        enabled: !isLoading,
                        decoration: InputDecoration(
                          hintText: 'Password',
                          helperText: _getPasswordHelperText(),
                          helperStyle: TextStyle(
                            color: _getPasswordHelperColor(),
                            fontSize: 12,
                          ),
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(16),
                          prefixIcon: const Icon(Icons.lock, color: Colors.white70),
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          shadows: [
                            Shadow(
                              color: Colors.black54,
                              blurRadius: 2,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        textInputAction: TextInputAction.done,
                        maxLength: 18, // Hard limit
                        inputFormatters: [
                          FilteringTextInputFormatter.deny(RegExp(r'\s')), // No spaces
                        ],
                        onChanged: (_) => _validateForm(),
                        onSubmitted: (_) => _continueWithEmail(),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Error Message
                    if (_errorMessage != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.withOpacity(0.3)),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    // Continue Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _canContinue() && !isLoading ? _debouncedContinueWithEmail : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _canContinue() && !isLoading 
                              ? const Color(0xFF6137EB) 
                              : Colors.grey.withOpacity(0.3),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text(
                                'Continue',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Sign up link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontWeight: FontWeight.w500,
                            shadows: [
                              Shadow(
                                color: Colors.black54,
                                blurRadius: 1,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const SignupView(),
                              ),
                            );
                          },
                          child: const Text(
                            'Sign up',
                            style: TextStyle(
                              color: Color(0xFF6137EB),
                              fontWeight: FontWeight.w600,
                              shadows: [
                                Shadow(
                                  color: Colors.black54,
                                  blurRadius: 1,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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
    if (password.isEmpty) return Colors.white.withOpacity(0.7);
    
    if (_isValidPassword(password)) {
      return Colors.green[300]!;
    }
    
    return Colors.orange[300]!;
  }

  /// Debounced continue with email - prevents multiple rapid taps
  void _debouncedContinueWithEmail() {
    // Cancel existing timer
    _debounceTimer?.cancel();
    
    // Start new debounce timer
    _debounceTimer = Timer(_debounceDelay, () {
      _continueWithEmail();
    });
  }

  Future<void> _continueWithEmail() async {
    final identifier = _identifierController.text.trim();
    final password = _passwordController.text.trim();
    
    if (identifier.isEmpty || password.isEmpty) return;
    
    final authService = ref.read(robustAuthServiceProvider.notifier);
    AuthRequestResult result;
    
    try {
      // Clear any previous error
      setState(() {
        _errorMessage = null;
      });
      
      // Determine if it's an email or username
      if (identifier.contains("@")) {
        // It's an email - use email authentication
        print("📧 Detected email input, using email authentication for: $identifier");
        result = await authService.debouncedSignInWithEmail(identifier, password);
      } else {
        // It's a username - use username authentication
        print("👤 Detected username input, using username authentication for: $identifier");
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
    if (error.contains('user-not-found')) {
      return 'No account found with this email or username';
    } else if (error.contains('wrong-password')) {
      return 'Incorrect password';
    } else if (error.contains('invalid-email')) {
      return 'Invalid email address';
    } else if (error.contains('user-disabled')) {
      return 'This account has been disabled';
    } else if (error.contains('too-many-requests')) {
      return 'Too many failed attempts. Please try again later';
    } else if (error.contains('network-request-failed')) {
      return 'Network error. Check your connection.';
    } else if (error.contains('Request cancelled')) {
      return 'Request cancelled';
    } else if (error.contains('network-request-failed')) {
      return 'Network error. Check your connection.';
    } else if (error.contains('email-already-in-use')) {
      return 'This email is already registered. Try signing in instead.';
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
