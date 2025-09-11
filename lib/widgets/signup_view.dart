import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/robust_auth_service.dart';

class SignupView extends ConsumerStatefulWidget {
  const SignupView({super.key});

  @override
  ConsumerState<SignupView> createState() => _SignupViewState();
}

class _SignupViewState extends ConsumerState<SignupView> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();
  final FocusNode _displayNameFocusNode = FocusNode();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _confirmPasswordFocusNode = FocusNode();
  
  // bool _showAlert = false;
  // String _alertMessage = "";
  String? _nameValidationMessage;
  bool _isCheckingUsername = false;
  String _generatedUsername = "";

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _displayNameController.dispose();
    _displayNameFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = ref.watch(robustAuthServiceProvider);
    
    return Scaffold(
      backgroundColor: Colors.grey.withValues(alpha: 0.1),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.black),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            
            // Title
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Text(
                "Create Account",
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Form Fields
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  // Display Name Field
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _displayNameController,
                        focusNode: _displayNameFocusNode,
                        decoration: const InputDecoration(
                          hintText: 'Display Name',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        textCapitalization: TextCapitalization.words,
                        onChanged: (value) {
                          validateName();
                          generateUsernameFromName();
                        },
                      ),
                      
                      if (_nameValidationMessage != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _nameValidationMessage!,
                          style: TextStyle(
                            fontSize: 12,
                            color: _nameValidationMessage!.contains("inappropriate") 
                                ? Colors.red 
                                : Colors.orange,
                          ),
                        ),
                      ],
                      
                      if (_generatedUsername.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              "Username will be:",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "@$_generatedUsername",
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.blue,
                              ),
                            ),
                            if (_isCheckingUsername) ...[
                              const SizedBox(width: 8),
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Email Field
                  TextField(
                    controller: _emailController,
                    focusNode: _emailFocusNode,
                    decoration: const InputDecoration(
                      hintText: 'Email',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    keyboardType: TextInputType.emailAddress,
                    textCapitalization: TextCapitalization.none,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Password Field
                  TextField(
                    controller: _passwordController,
                    focusNode: _passwordFocusNode,
                    decoration: const InputDecoration(
                      hintText: 'Password',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    obscureText: true,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Confirm Password Field
                  TextField(
                    controller: _confirmPasswordController,
                    focusNode: _confirmPasswordFocusNode,
                    decoration: const InputDecoration(
                      hintText: 'Confirm Password',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    obscureText: true,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Create Account Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isFormValid() && !authService.shouldShowLoading 
                      ? _signUp 
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: authService.shouldShowLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Create Account',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
            
            const Spacer(),
            
            // Terms of Service
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                "By creating an account, you agree to our Terms of Service and acknowledge that you have read our Privacy Policy to learn how we collect, use, and share your data.",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Sign In Link
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Already have an account?"),
                const SizedBox(width: 4),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    "Sign in",
                    style: TextStyle(color: Colors.pink),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  bool _isFormValid() {
    return _emailController.text.trim().isNotEmpty && 
           _passwordController.text.trim().isNotEmpty && 
           _displayNameController.text.trim().isNotEmpty && 
           _passwordController.text == _confirmPasswordController.text && 
           _passwordController.text.length >= 6 &&
           _emailController.text.contains("@") &&
           _nameValidationMessage == null &&
           _generatedUsername.isNotEmpty;
  }

  void validateName() {
    final displayName = _displayNameController.text.trim();
    if (displayName.isEmpty) {
      setState(() {
        _nameValidationMessage = null;
      });
      return;
    }
    
    // Basic validation - you can enhance this based on your requirements
    if (displayName.length < 2) {
      setState(() {
        _nameValidationMessage = "Display name must be at least 2 characters";
      });
    } else if (displayName.length > 30) {
      setState(() {
        _nameValidationMessage = "Display name must be less than 30 characters";
      });
    } else {
      setState(() {
        _nameValidationMessage = null;
      });
    }
  }

  void generateUsernameFromName() {
    final displayName = _displayNameController.text.trim();
    if (displayName.isEmpty) {
      setState(() {
        _generatedUsername = "";
      });
      return;
    }
    
    // Generate username from display name
    final baseUsername = _generateUsernameFromName(displayName);
    if (baseUsername.isEmpty) {
      setState(() {
        _generatedUsername = "";
      });
      return;
    }
    
    setState(() {
      _isCheckingUsername = true;
    });
    
    // Simulate username availability check
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _generatedUsername = baseUsername;
          _isCheckingUsername = false;
        });
      }
    });
  }

  String _generateUsernameFromName(String displayName) {
    // Remove special characters and convert to lowercase
    final cleanName = displayName
        .replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '')
        .toLowerCase()
        .trim();
    
    if (cleanName.isEmpty) return "";
    
    // Split by spaces and take first word
    final words = cleanName.split(' ');
    if (words.isEmpty) return "";
    
    return words.first;
  }

  Future<void> _signUp() async {
    if (_generatedUsername.isEmpty) {
      // setState(() {
      //   _alertMessage = "Please enter a valid display name";
      //   _showAlert = true;
      // });
      return;
    }
    
    try {
      final authService = ref.read(robustAuthServiceProvider.notifier);
      await authService.signUpWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        _displayNameController.text.trim(),
        _generatedUsername,
      );
      
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      // setState(() {
      //   _alertMessage = e.toString();
      //   _showAlert = true;
      // });
    }
  }
}
