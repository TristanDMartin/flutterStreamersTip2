import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/robust_auth_service.dart';
import '../views/terms_of_service_view.dart';
import '../views/privacy_policy_view.dart';
import 'email_login_view.dart';

class LoginView extends ConsumerStatefulWidget {
  final VoidCallback? dismiss;

  const LoginView({
    super.key,
    this.dismiss,
  });

  @override
  ConsumerState<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends ConsumerState<LoginView> {
  bool _showEmailLogin = false;
  bool _showAlert = false;
  String _alertMessage = "";
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    // Listen to auth state changes to navigate when user signs in
    ref.listen(robustAuthServiceProvider, (previous, next) {
      // Check if user is now logged in
      if (next.isLoggedIn && mounted) {
        // User is authenticated, dismiss login screen
        widget.dismiss?.call();
      }
    });
    
    // Show EmailLoginView if requested
    if (_showEmailLogin) {
      return EmailLoginView(
        dismiss: () {
          setState(() {
            _showEmailLogin = false;
          });
        },
      );
    }
    
    return Scaffold(
      backgroundColor: Colors.transparent,
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
          child: Stack(
            children: [
              Column(
                children: [
                  // Top Navigation Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        const Spacer(),
                        
                        IconButton(
                          onPressed: () {
                            // Help/support functionality can be added here
                          },
                          icon: const Icon(
                            Icons.help_outline,
                            size: 18,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Main Content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          const SizedBox(height: 40),
                          
                          // Title
                          const Text(
                            "Log in to StreamersTip",
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          
                          const SizedBox(height: 32),
                          
                          // Login Buttons Stack
                          Column(
                            children: [
                              // Phone/Email/Username Button
                              LoginButton(
                                iconName: Icons.person,
                                text: "Use email / username",
                                onTap: () {
                                  setState(() {
                                    _showEmailLogin = true;
                                  });
                                },
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // Google Button
                              LoginButton(
                                iconName: Icons.language,
                                text: _isLoading ? "Signing in..." : "Continue with Google",
                                onTap: _isLoading ? null : _signInWithGoogle,
                                isLoading: _isLoading,
                              ),
                              
                              const SizedBox(height: 16),
                            ],
                          ),
                          
                          const Spacer(),
                          
                          // Terms and Privacy
                          Column(
                            children: [
                              const Text(
                                "By continuing, you agree to our",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              
                              const SizedBox(height: 8),
                              
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (context) => const TermsOfServiceView(),
                                        ),
                                      );
                                    },
                                    child: const Text(
                                      "Terms of Service",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF6137EB),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  
                                  const Text(
                                    "and acknowledge that you have read our",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (context) => const PrivacyPolicyView(),
                                        ),
                                      );
                                    },
                                    child: const Text(
                                      "Privacy Policy",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF6137EB),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              
                              const Text(
                                "to learn how we collect, use, and share your data.",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 28),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              
              // Alert Dialog Overlay
              if (_showAlert) ...[
                // Tap outside to dismiss
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
                        "Notice",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                      content: Text(
                        _alertMessage.isEmpty ? "Something happened." : _alertMessage,
                        style: const TextStyle(color: Colors.white70, height: 1.3),
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

  Future<void> _signInWithGoogle() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
      _showAlert = false; // Clear any previous alerts
    });
    
        try {
          final authService = ref.read(robustAuthServiceProvider);
          await authService.debouncedSignInWithGoogle();
      
      // Don't manually navigate here - let the auth state listener handle it
      // The auth state listener will trigger when Firebase auth state changes
      
    } catch (e) {
      if (mounted) {
        setState(() {
          _alertMessage = _getUserFriendlyErrorMessage(e.toString());
          _showAlert = true;
          _isLoading = false;
        });
      }
    }
  }

  String _getUserFriendlyErrorMessage(String error) {
    if (error.contains('sign_in_canceled') || error.contains('cancelled')) {
      return 'Sign-in was cancelled';
    } else if (error.contains('network_error') || error.contains('network')) {
      return 'Network error. Please check your connection';
    } else if (error.contains('sign_in_failed')) {
      return 'Sign-in failed. Please try again';
    } else {
      return 'Sign-in failed. Please try again';
    }
  }

}

// MARK: - Login Button Component
class LoginButton extends StatelessWidget {
  final IconData iconName;
  final String text;
  final VoidCallback? onTap;
  final bool isLoading;

  const LoginButton({
    super.key,
    required this.iconName,
    required this.text,
    this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 48, // Match ProfileView button height
        decoration: BoxDecoration(
          gradient: onTap != null ? const LinearGradient(
            colors: [Color(0xFF955CFF), Color(0xFF3D99F7)], // Match ProfileView gradient
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ) : const LinearGradient(
            colors: [Color(0xFF666666), Color(0xFF555555)], // Disabled gradient
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(24), // Match ProfileView pill shape
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading) ...[
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
              ] else ...[
                Icon(
                  iconName,
                  size: 20,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
              ],
              
              Text(
                text,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
