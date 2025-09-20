import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'instant_response_button.dart';

class SwitchAccountModal extends ConsumerStatefulWidget {
  const SwitchAccountModal({super.key});

  @override
  ConsumerState<SwitchAccountModal> createState() => _SwitchAccountModalState();
}

class _SwitchAccountModalState extends ConsumerState<SwitchAccountModal> {
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _availableAccounts = [];

  @override
  void initState() {
    super.initState();
    _loadAvailableAccounts();
  }

  Future<void> _loadAvailableAccounts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get current user
      final currentUser = fa.FirebaseAuth.instance.currentUser;
      final currentUserId = currentUser?.uid;

      // Load saved accounts from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final savedAccountsJson = prefs.getString('saved_accounts') ?? '[]';
      final List<dynamic> savedAccounts = json.decode(savedAccountsJson);

      // Convert saved accounts to our format
      final List<Map<String, dynamic>> accounts = savedAccounts
          .map((account) => Map<String, dynamic>.from(account))
          .toList();

      // Add current account if it's not already in the list
      if (currentUserId != null) {
        final currentAccountExists = accounts.any((account) => account['id'] == currentUserId);
        if (!currentAccountExists) {
          accounts.insert(0, {
            'id': currentUserId,
            'displayName': currentUser?.displayName ?? 'Current User',
            'email': currentUser?.email ?? 'user@example.com',
            'photoURL': currentUser?.photoURL,
            'isCurrent': true,
            'lastUsed': DateTime.now().toIso8601String(),
          });
        } else {
          // Mark current account
          for (var account in accounts) {
            account['isCurrent'] = account['id'] == currentUserId;
          }
        }
      }

      // Sort by last used (most recent first)
      accounts.sort((a, b) {
        final aTime = DateTime.tryParse(a['lastUsed'] ?? '') ?? DateTime(1970);
        final bTime = DateTime.tryParse(b['lastUsed'] ?? '') ?? DateTime(1970);
        return bTime.compareTo(aTime);
      });

      _availableAccounts = accounts;

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load accounts: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

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
            'Switch Account',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose an account to switch to',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          
          // Loading or Accounts List
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          else
            _buildAccountsList(),
          
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

  Widget _buildAccountsList() {
    if (_availableAccounts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              Icons.account_circle_outlined,
              color: Colors.white.withValues(alpha: 0.5),
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'No other accounts found',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add a new account to switch between them',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: _availableAccounts.map((account) => _buildAccountItem(account)).toList(),
    );
  }

  Widget _buildAccountItem(Map<String, dynamic> account) {
    final isCurrent = account['isCurrent'] == true;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          // Account item
          Expanded(
            child: InstantResponseButton(
              onPressed: isCurrent ? null : () => _switchToAccount(account),
              hapticType: HapticFeedbackType.lightImpact,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isCurrent 
                      ? const Color(0xFF9248D2).withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isCurrent 
                        ? const Color(0xFF9248D2)
                        : Colors.white.withValues(alpha: 0.1),
                    width: isCurrent ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    // Avatar
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: const Color(0xFF9248D2),
                      backgroundImage: account['photoURL'] != null
                          ? NetworkImage(account['photoURL'])
                          : null,
                      child: account['photoURL'] == null
                          ? const Icon(Icons.person, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 16),
                    
                    // Account Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            account['displayName'] ?? 'Unknown User',
                            style: TextStyle(
                              color: isCurrent ? const Color(0xFF9248D2) : Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            account['email'] ?? 'No email',
                            style: TextStyle(
                              color: isCurrent 
                                  ? const Color(0xFF9248D2).withValues(alpha: 0.7)
                                  : Colors.white.withValues(alpha: 0.7),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Current indicator or switch button
                    if (isCurrent)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF9248D2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Current',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )
                    else
                      Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white.withValues(alpha: 0.5),
                        size: 16,
                      ),
                  ],
                ),
              ),
            ),
          ),
          
          // Remove button (only for non-current accounts)
          if (!isCurrent) ...[
            const SizedBox(width: 8),
            InstantResponseButton(
              onPressed: () => _removeAccount(account),
              hapticType: HapticFeedbackType.mediumImpact,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.red,
                  size: 20,
                ),
              ),
            ),
          ],
        ],
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
            onPressed: _isLoading ? null : _addNewAccount,
            hapticType: HapticFeedbackType.mediumImpact,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF9248D2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  'Add Account',
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

  Future<void> _switchToAccount(Map<String, dynamic> account) async {
    if (account['isCurrent'] == true) {
      // Already on this account
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Already signed in as ${account['displayName']}'),
            backgroundColor: Colors.blue,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
        // Show loading dialog
        if (context.mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF6137EB), Color(0xFF1C135D)],
                  ),
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Switching to ${account['displayName']}...',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

      // For now, we'll show a message that account switching requires re-authentication
      // In a full implementation, you would:
      // 1. Store the current account data
      // 2. Sign out current user
      // 3. Sign in with the selected account credentials
      // 4. Update the saved accounts list
      
      await Future.delayed(const Duration(seconds: 2)); // Simulate switching time

      // Update last used time for this account
      await _updateAccountLastUsed(account['id']);

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        Navigator.of(context).pop(); // Close switch account modal
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Account switching requires re-authentication. Please sign in with ${account['displayName']}'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Sign In',
              textColor: Colors.white,
              onPressed: () => _showSignInForAccount(account),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        setState(() {
          _errorMessage = 'Failed to switch account: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateAccountLastUsed(String accountId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedAccountsJson = prefs.getString('saved_accounts') ?? '[]';
      final List<dynamic> savedAccounts = json.decode(savedAccountsJson);
      
      // Update last used time for the account
      for (var account in savedAccounts) {
        if (account['id'] == accountId) {
          account['lastUsed'] = DateTime.now().toIso8601String();
          break;
        }
      }
      
      await prefs.setString('saved_accounts', json.encode(savedAccounts));
    } catch (e) {
      // Handle error silently
    }
  }

  void _showSignInForAccount(Map<String, dynamic> account) {
    // This would open the appropriate sign-in method for the account
    // For now, we'll show a placeholder
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0E1220),
        title: Text(
          'Sign in as ${account['displayName']}',
          style: const TextStyle(color: Colors.white),
        ),
        content: const Text(
          'To switch to this account, please sign in with the appropriate method (Google, Email, etc.)',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'OK',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _removeAccount(Map<String, dynamic> account) async {
    // Show confirmation dialog
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        content: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF6137EB), Color(0xFF1C135D)],
            ),
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Remove Account',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Are you sure you want to remove ${account['displayName']} from your saved accounts?',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: InstantResponseButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        hapticType: HapticFeedbackType.lightImpact,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
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
                        onPressed: () => Navigator.of(context).pop(true),
                        hapticType: HapticFeedbackType.mediumImpact,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Text(
                              'Remove',
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
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (shouldRemove == true) {
      try {
        // Remove account from saved accounts
        final prefs = await SharedPreferences.getInstance();
        final savedAccountsJson = prefs.getString('saved_accounts') ?? '[]';
        final List<dynamic> savedAccounts = json.decode(savedAccountsJson);
        
        savedAccounts.removeWhere((savedAccount) => savedAccount['id'] == account['id']);
        
        await prefs.setString('saved_accounts', json.encode(savedAccounts));
        
        // Reload accounts
        await _loadAvailableAccounts();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${account['displayName']} removed from saved accounts'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to remove account: ${e.toString()}'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  void _addNewAccount() {
    Navigator.of(context).pop();
    // This will be handled by the parent component
    // The Add Account modal will be shown from the account management menu
  }
}
