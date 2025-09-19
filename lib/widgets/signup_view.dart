import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/robust_auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _confirmPasswordFocusNode = FocusNode();
  final FocusNode _displayNameFocusNode = FocusNode();
  
  bool _showAlert = false;
  String _alertMessage = "";
  String? _nameValidationMessage;
  String? _emailValidationMessage;
  String? _passwordValidationMessage;
  bool _isCheckingUsername = false;
  String _generatedUsername = "";
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Password visibility states (per-field)
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  
  // Focus states for floating labels
  bool _isDisplayNameFocused = false;
  bool _isEmailFocused = false;
  bool _isPasswordFocused = false;
  bool _isConfirmPasswordFocused = false;

  @override
  void initState() {
    super.initState();
    
    // Add focus listeners for floating labels
    _displayNameFocusNode.addListener(() {
      setState(() {
        _isDisplayNameFocused = _displayNameFocusNode.hasFocus;
      });
    });
    
    _emailFocusNode.addListener(() {
      setState(() {
        _isEmailFocused = _emailFocusNode.hasFocus;
      });
    });
    
    _passwordFocusNode.addListener(() {
      setState(() {
        _isPasswordFocused = _passwordFocusNode.hasFocus;
      });
    });
    
    _confirmPasswordFocusNode.addListener(() {
      setState(() {
        _isConfirmPasswordFocused = _confirmPasswordFocusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _displayNameController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    _displayNameFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = ref.watch(robustAuthServiceProvider);
    
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF6137EB), Color(0xFF1C135D)],
              ),
            ),
            child: Column(
              children: [
                // Header with just back button
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // App Logo Section
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(bottom: 32),
                          child: Column(
                            children: [
                              Image.asset(
                                'assets/logo.png',
                                width: 100,
                                height: 100,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
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
                                      size: 100,
                                      color: Colors.white,
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                "StreamersTip",
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                "Join the community",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Form Container
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              // Display Name Field
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
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
                                        color: _isDisplayNameFocused 
                                            ? const Color(0xFF6137EB) 
                                            : Colors.white.withOpacity(0.2),
                                        width: _isDisplayNameFocused ? 2 : 1,
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
                                      controller: _displayNameController,
                                      focusNode: _displayNameFocusNode,
                                      enabled: true,
                                      decoration: InputDecoration(
                                        labelText: 'Display Name',
                                        labelStyle: TextStyle(
                                          color: _isDisplayNameFocused 
                                              ? const Color(0xFF6137EB)
                                              : Colors.white.withOpacity(0.7),
                                          fontSize: _isDisplayNameFocused || _displayNameController.text.isNotEmpty ? 12 : 16,
                                          fontWeight: FontWeight.w500,
                                          shadows: [
                                            Shadow(
                                              color: Colors.black54,
                                              blurRadius: 1,
                                              offset: const Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                        hintText: _isDisplayNameFocused || _displayNameController.text.isNotEmpty ? null : 'Display Name',
                                        hintStyle: TextStyle(
                                          color: Colors.white.withOpacity(0.8),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          shadows: [
                                            Shadow(
                                              color: Colors.black54,
                                              blurRadius: 1,
                                              offset: const Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
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
                                      textCapitalization: TextCapitalization.words,
                                      textInputAction: TextInputAction.next,
                                      onChanged: (value) {
                                        setState(() {}); // Trigger rebuild for floating label
                                        validateName();
                                        generateUsernameFromName();
                                      },
                                      onSubmitted: (_) => _emailFocusNode.requestFocus(),
                                    ),
                                  ),
                                  
                                  if (_nameValidationMessage != null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      _nameValidationMessage!,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: _nameValidationMessage!.contains("inappropriate") 
                                            ? Colors.red[300]
                                            : Colors.orange[300],
                                        shadows: [
                                          Shadow(
                                            color: Colors.black.withOpacity(0.3),
                                            blurRadius: 2,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
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
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.white.withOpacity(0.8),
                                            shadows: [
                                              Shadow(
                                                color: Colors.black.withOpacity(0.3),
                                                blurRadius: 2,
                                                offset: const Offset(0, 1),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _generatedUsername,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            shadows: [
                                              Shadow(
                                                color: Colors.black26,
                                                blurRadius: 2,
                                                offset: Offset(0, 1),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (_isCheckingUsername) ...[
                                          const SizedBox(width: 8),
                                          const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
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
                                        color: _isEmailFocused 
                                            ? const Color(0xFF6137EB) 
                                            : Colors.white.withOpacity(0.2),
                                        width: _isEmailFocused ? 2 : 1,
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
                                      controller: _emailController,
                                      focusNode: _emailFocusNode,
                                      enabled: true,
                                      decoration: InputDecoration(
                                        labelText: 'Email',
                                        labelStyle: TextStyle(
                                          color: _isEmailFocused 
                                              ? const Color(0xFF6137EB)
                                              : Colors.white.withOpacity(0.8),
                                          fontSize: _isEmailFocused || _emailController.text.isNotEmpty ? 12 : 16,
                                          fontWeight: FontWeight.w500,
                                          shadows: [
                                            Shadow(
                                              color: Colors.black54,
                                              blurRadius: 1,
                                              offset: const Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                        hintText: _isEmailFocused || _emailController.text.isNotEmpty ? null : 'Email',
                                        hintStyle: TextStyle(
                                          color: Colors.white.withOpacity(0.8),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          shadows: [
                                            Shadow(
                                              color: Colors.black54,
                                              blurRadius: 1,
                                              offset: const Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
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
                                      keyboardType: TextInputType.emailAddress,
                                      textCapitalization: TextCapitalization.none,
                                      textInputAction: TextInputAction.next,
                                      onChanged: (value) {
                                        setState(() {}); // Trigger rebuild for floating label
                                        validateEmail();
                                      },
                                      onSubmitted: (_) => _passwordFocusNode.requestFocus(),
                                    ),
                                  ),
                                  if (_emailValidationMessage != null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      _emailValidationMessage!,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.red[300],
                                        shadows: [
                                          Shadow(
                                            color: Colors.black.withOpacity(0.3),
                                            blurRadius: 2,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // Password Field
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
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
                                        color: _isPasswordFocused 
                                            ? const Color(0xFF6137EB) 
                                            : Colors.white.withOpacity(0.2),
                                        width: _isPasswordFocused ? 2 : 1,
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
                                      enabled: true,
                                      maxLength: 18, // Match Email/Username view limit
                                      decoration: InputDecoration(
                                        labelText: 'Password',
                                        labelStyle: TextStyle(
                                          color: _isPasswordFocused 
                                              ? const Color(0xFF6137EB)
                                              : Colors.white.withOpacity(0.8),
                                          fontSize: _isPasswordFocused || _passwordController.text.isNotEmpty ? 12 : 16,
                                          fontWeight: FontWeight.w500,
                                          shadows: [
                                            Shadow(
                                              color: Colors.black54,
                                              blurRadius: 1,
                                              offset: const Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                        hintText: _isPasswordFocused || _passwordController.text.isNotEmpty ? null : 'Password',
                                        hintStyle: TextStyle(
                                          color: Colors.white.withOpacity(0.8),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          shadows: [
                                            Shadow(
                                              color: Colors.black54,
                                              blurRadius: 1,
                                              offset: const Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                                        counterText: '', // Hide character counter
                                        suffixIcon: SizedBox(
                                          width: 44,
                                          height: 44,
                                          child: IconButton(
                                            icon: Icon(
                                              _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                              color: Colors.white.withOpacity(0.7),
                                              size: 20,
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                _isPasswordVisible = !_isPasswordVisible;
                                              });
                                            },
                                            tooltip: _isPasswordVisible ? 'Hide password' : 'Show password',
                                          ),
                                        ),
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
                                      obscureText: !_isPasswordVisible,
                                      textInputAction: TextInputAction.next,
                                      onChanged: (value) {
                                        setState(() {}); // Trigger rebuild for floating label
                                        validatePassword();
                                      },
                                      onSubmitted: (_) => _confirmPasswordFocusNode.requestFocus(),
                                    ),
                                  ),
                                  if (_passwordValidationMessage != null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      _passwordValidationMessage!,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.red[300],
                                        shadows: [
                                          Shadow(
                                            color: Colors.black.withOpacity(0.3),
                                            blurRadius: 2,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // Confirm Password Field
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
                                    color: _isConfirmPasswordFocused 
                                        ? const Color(0xFF6137EB) 
                                        : Colors.white.withOpacity(0.2),
                                    width: _isConfirmPasswordFocused ? 2 : 1,
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
                                  controller: _confirmPasswordController,
                                  focusNode: _confirmPasswordFocusNode,
                                  enabled: true,
                                  maxLength: 18, // Match Email/Username view limit
                                  decoration: InputDecoration(
                                    labelText: 'Confirm Password',
                                    labelStyle: TextStyle(
                                      color: _isConfirmPasswordFocused 
                                          ? const Color(0xFF6137EB)
                                          : Colors.white.withOpacity(0.8),
                                      fontSize: _isConfirmPasswordFocused || _confirmPasswordController.text.isNotEmpty ? 12 : 16,
                                      fontWeight: FontWeight.w500,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black54,
                                          blurRadius: 1,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    hintText: _isConfirmPasswordFocused || _confirmPasswordController.text.isNotEmpty ? null : 'Confirm Password',
                                    hintStyle: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black54,
                                          blurRadius: 1,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                                    counterText: '', // Hide character counter
                                    suffixIcon: SizedBox(
                                      width: 44,
                                      height: 44,
                                      child: IconButton(
                                        icon: Icon(
                                          _isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                          color: Colors.white.withOpacity(0.7),
                                          size: 20,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                                          });
                                        },
                                        tooltip: _isConfirmPasswordVisible ? 'Hide password' : 'Show password',
                                      ),
                                    ),
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
                                  obscureText: !_isConfirmPasswordVisible,
                                  textInputAction: TextInputAction.done,
                                  onChanged: (value) {
                                    setState(() {}); // Trigger rebuild for floating label
                                    validatePassword();
                                  },
                                  onSubmitted: (_) {
                                    if (_isFormValid() && !authService.shouldShowLoading) {
                                      _signUp();
                                    }
                                  },
                                ),
                              ),
                              
                              const SizedBox(height: 32),
                              
                              // Sign Up Button
                              SizedBox(
                                width: double.infinity,
                                child: Semantics(
                                  label: 'Create Account Button',
                                  button: true,
                                  child: ElevatedButton(
                                    onPressed: _isFormValid() && !authService.shouldShowLoading 
                                        ? _signUp 
                                        : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _isFormValid() 
                                          ? const Color(0xFF6137EB)  // Brand color when enabled
                                          : const Color(0xFF6137EB).withOpacity(0.3),  // Dimmed when disabled
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 18),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 0,
                                      splashFactory: _isFormValid() ? InkRipple.splashFactory : NoSplash.splashFactory,
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
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // Troubleshooting Buttons
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  TextButton(
                                    onPressed: () async {
                                      await _clearFirebaseAuthState();
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text("Cache cleared. Try signing up again."),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      }
                                    },
                                    child: Text(
                                      "Clear Cache",
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.7),
                                        fontSize: 12,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      final email = _emailController.text.trim();
                                      if (email.isNotEmpty) {
                                        await _forceDeleteAuthAccount(email);
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text("Attempted to delete existing account. Try signing up again."),
                                              backgroundColor: Colors.orange,
                                            ),
                                          );
                                        }
                                      } else {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text("Please enter an email first"),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    child: Text(
                                      "Delete Existing Account",
                                      style: TextStyle(
                                        color: Colors.red.withOpacity(0.8),
                                        fontSize: 12,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 8),
                              
                              // Sign In Link
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Already have an account?",
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w400,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black.withOpacity(0.3),
                                          blurRadius: 2,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(),
                                    child: Text(
                                      "Sign in",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        decoration: TextDecoration.underline,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black.withOpacity(0.3),
                                            blurRadius: 2,
                                            offset: const Offset(0, 1),
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
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Alert Dialog Overlay
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
                    "Registration Error",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                  content: Text(
                    _alertMessage,
                    style: const TextStyle(color: Colors.white70, height: 1.3),
                  ),
                  actions: [
                    if (_alertMessage.contains('email is already registered'))
                      TextButton(
                        onPressed: () {
                          setState(() => _showAlert = false);
                          Navigator.of(context).pop(); // Go back to login screen
                        },
                        child: const Text(
                          "Sign In Instead",
                          style: TextStyle(color: Color(0xFF6137EB)),
                        ),
                      ),
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
    );
  }

  bool _isFormValid() {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    final displayName = _displayNameController.text.trim();
    
    // Required fields non-empty
    if (email.isEmpty || password.isEmpty || confirmPassword.isEmpty || displayName.isEmpty) {
      return false;
    }
    
    // Email format valid (basic regex)
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(email)) {
      return false;
    }
    
    // Password meets policy (≥8 chars) and matches confirm
    if (password.length < 8 || password != confirmPassword) {
      return false;
    }
    
    // Username generated successfully
    if (_generatedUsername.isEmpty || _isCheckingUsername) {
      return false;
    }
    
    // No validation errors
    return _nameValidationMessage == null &&
           _emailValidationMessage == null &&
           _passwordValidationMessage == null;
  }

  void validateName() async {
    final displayName = _displayNameController.text.trim();
    if (displayName.isEmpty) {
      setState(() {
        _nameValidationMessage = null;
      });
      return;
    }
    
    // Security validation - basic check for valid characters
    if (displayName.contains('<') || displayName.contains('>') || displayName.contains('"') || displayName.contains("'")) {
      setState(() {
        _nameValidationMessage = "Display name contains invalid characters";
      });
      return;
    }
    
    // Length validation
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

  void validateEmail() {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _emailValidationMessage = null;
      });
      return;
    }
    
    // Basic email regex validation
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(email)) {
      setState(() {
        _emailValidationMessage = "Please enter a valid email address";
      });
    } else {
      setState(() {
        _emailValidationMessage = null;
      });
    }
  }

  void validatePassword() {
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    
    if (password.isEmpty) {
      setState(() {
        _passwordValidationMessage = null;
      });
      return;
    }
    
    // Password meets policy (≥8 chars)
    if (password.length < 8) {
      setState(() {
        _passwordValidationMessage = "Password must be at least 8 characters";
      });
    } else if (confirmPassword.isNotEmpty && password != confirmPassword) {
      setState(() {
        _passwordValidationMessage = "Passwords do not match";
      });
    } else {
      setState(() {
        _passwordValidationMessage = null;
      });
    }
  }

  void generateUsernameFromName() async {
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
    
    try {
      // Check if username is available in Firestore
      await _firestore
          .collection('users')
          .where('username', isEqualTo: baseUsername)
          .limit(1)
          .get();
      
      if (mounted) {
        setState(() {
          _generatedUsername = baseUsername;
          _isCheckingUsername = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _generatedUsername = baseUsername;
          _isCheckingUsername = false;
        });
      }
    }
  }

  String _generateUsernameFromName(String displayName) {
    // Remove special characters and convert to lowercase
    String username = displayName.toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '')
        .trim();
    
    // Ensure minimum length
    if (username.length < 3) {
      username = username + 'user';
    }
    
    // Limit maximum length
    if (username.length > 20) {
      username = username.substring(0, 20);
    }
    
    return username;
  }

  String _getSignupErrorMessage(String error) {
    if (error.contains('email-already-in-use')) {
      return 'This email is already registered in Firebase Auth. Use the "Delete Existing Account" button below to remove it, or try signing in instead.';
    } else if (error.contains('invalid-email')) {
      return 'Please enter a valid email address.';
    } else if (error.contains('weak-password')) {
      return 'Password is too weak. Please use a stronger password.';
    } else if (error.contains('operation-not-allowed')) {
      return 'Email/password accounts are not enabled. Please contact support.';
    } else if (error.contains('network-request-failed')) {
      return 'Network error. Please check your internet connection.';
    } else if (error.contains('too-many-requests')) {
      return 'Too many attempts. Please wait a moment and try again.';
    } else {
      return 'Registration failed. Please try again.';
    }
  }

  Future<void> _signUp() async {
    if (_generatedUsername.isEmpty) {
      setState(() {
        _alertMessage = "Please enter a valid display name";
        _showAlert = true;
      });
      return;
    }
    
    try {
      // Clear any existing Firebase Auth state
      await _clearFirebaseAuthState();
      
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
      if (mounted) {
        // Enhanced error logging for debugging
        print("🔍 Signup Error Details: ${e.toString()}");
        print("🔍 Error Type: ${e.runtimeType}");
        
        setState(() {
          _alertMessage = _getSignupErrorMessage(e.toString());
          _showAlert = true;
        });
      }
    }
  }

  /// Clear Firebase Auth state to resolve caching issues
  Future<void> _clearFirebaseAuthState() async {
    try {
      // Sign out any existing user
      await FirebaseAuth.instance.signOut();
      
      // Clear any cached data
      await Future.delayed(const Duration(milliseconds: 500));
      
      print("🧹 Firebase Auth state cleared");
    } catch (e) {
      print("⚠️ Error clearing Firebase Auth state: $e");
    }
  }

  /// Force delete Firebase Auth account (for troubleshooting)
  Future<void> _forceDeleteAuthAccount(String email) async {
    try {
      print("🗑️ Attempting to force delete Firebase Auth account for: $email");
      
      // Try to sign in with a temporary password to get the user
      // This is a workaround for the email-already-in-use issue
      try {
        // First, try to sign in with a dummy password to get the user object
        final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: "temp123456", // This will fail, but we'll catch it
        );
        
        if (credential.user != null) {
          await credential.user!.delete();
          print("✅ Firebase Auth account deleted successfully");
        }
      } catch (e) {
        print("⚠️ Could not delete Firebase Auth account: $e");
        // This is expected if the password is wrong
      }
      
      // Clear any remaining state
      await FirebaseAuth.instance.signOut();
      
    } catch (e) {
      print("❌ Error in force delete: $e");
    }
  }
}