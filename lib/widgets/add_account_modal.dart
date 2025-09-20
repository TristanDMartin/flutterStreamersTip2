import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'dart:convert';
import '../services/robust_auth_service.dart';
import 'robust_email_login_view.dart';
import 'signup_view.dart';
import 'instant_response_button.dart';

class AddAccountModal extends ConsumerStatefulWidget {
  const AddAccountModal({super.key});

  @override
  ConsumerState<AddAccountModal> createState() => _AddAccountModalState();
}

class _AddAccountModalState extends ConsumerState<AddAccountModal> {
  bool _isLoading = false;
  String? _errorMessage;
  String _selectedOption = 'google'; // 'google', 'email', 'signup'

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6137EB), Color(0xFF1C135D)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Title
          const Text(
            'Add Account',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sign in with a different account or create a new one',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          
          // Authentication Options
          _buildAuthOptions(),
          
          const SizedBox(height: 24),
          
          // Error Message
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
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
            const SizedBox(height: 16),
          ],
          
          // Action Buttons
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildAuthOptions() {
    return Column(
      children: [
        // Google Sign-In Option
        _buildAuthOption(
          icon: Icons.g_mobiledata,
          title: 'Continue with Google',
          subtitle: 'Sign in with your Google account',
          isSelected: _selectedOption == 'google',
          onTap: () {
            setState(() {
              _selectedOption = 'google';
              _errorMessage = null;
            });
          },
        ),
        
        const SizedBox(height: 12),
        
        // Email Sign-In Option
        _buildAuthOption(
          icon: Icons.email,
          title: 'Sign in with Email',
          subtitle: 'Use existing email or username',
          isSelected: _selectedOption == 'email',
          onTap: () {
            setState(() {
              _selectedOption = 'email';
              _errorMessage = null;
            });
          },
        ),
        
        const SizedBox(height: 12),
        
        // Create Account Option
        _buildAuthOption(
          icon: Icons.person_add,
          title: 'Create New Account',
          subtitle: 'Sign up with email and password',
          isSelected: _selectedOption == 'signup',
          onTap: () {
            setState(() {
              _selectedOption = 'signup';
              _errorMessage = null;
            });
          },
        ),
      ],
    );
  }

  Widget _buildAuthOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InstantResponseButton(
      onPressed: onTap,
      hapticType: HapticFeedbackType.lightImpact,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected 
              ? const Color(0xFF9248D2).withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
                ? const Color(0xFF9248D2)
                : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected 
                    ? const Color(0xFF9248D2)
                    : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? const Color(0xFF9248D2) : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isSelected 
                          ? const Color(0xFF9248D2).withValues(alpha: 0.7)
                          : Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Color(0xFF9248D2),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: InstantResponseButton(
            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
            hapticType: HapticFeedbackType.lightImpact,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: const Center(
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: InstantResponseButton(
            onPressed: _isLoading ? null : _handleContinue,
            hapticType: HapticFeedbackType.mediumImpact,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: _isLoading 
                    ? const Color(0xFF9248D2).withValues(alpha: 0.5)
                    : const Color(0xFF9248D2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Center(
                      child: Text(
                        'Continue',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleContinue() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      switch (_selectedOption) {
        case 'google':
          await _handleGoogleSignIn();
          break;
        case 'email':
          await _showEmailLogin();
          break;
        case 'signup':
          await _showSignup();
          break;
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _handleGoogleSignIn() async {
    try {
      final authService = ref.read(robustAuthServiceProvider);
      final requestId = DateTime.now().millisecondsSinceEpoch.toString();
      
      final result = await authService.signInWithGoogle(requestId);
      
      if (result.success) {
        // Save the account to saved accounts
        await _saveAccountToStorage();
        
        if (mounted) {
          Navigator.of(context).pop();
          _showSuccessMessage('Successfully signed in with Google!');
        }
      } else {
        throw Exception(result.error ?? 'Google sign-in failed');
      }
    } catch (e) {
      throw Exception('Google sign-in failed: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveAccountToStorage() async {
    try {
      final currentUser = fa.FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final prefs = await SharedPreferences.getInstance();
      final savedAccountsJson = prefs.getString('saved_accounts') ?? '[]';
      final List<dynamic> savedAccounts = json.decode(savedAccountsJson);

      // Check if account already exists
      final accountExists = savedAccounts.any((account) => account['id'] == currentUser.uid);
      
      if (!accountExists) {
        // Add new account
        savedAccounts.add({
          'id': currentUser.uid,
          'displayName': currentUser.displayName ?? 'User',
          'email': currentUser.email ?? 'user@example.com',
          'photoURL': currentUser.photoURL,
          'lastUsed': DateTime.now().toIso8601String(),
        });

        await prefs.setString('saved_accounts', json.encode(savedAccounts));
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _showEmailLogin() async {
    if (context.mounted) {
      Navigator.of(context).pop();
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => const RobustEmailLoginView(),
      );
    }
  }

  Future<void> _showSignup() async {
    if (context.mounted) {
      Navigator.of(context).pop();
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => const SignupView(),
      );
    }
  }

  void _showSuccessMessage(String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
