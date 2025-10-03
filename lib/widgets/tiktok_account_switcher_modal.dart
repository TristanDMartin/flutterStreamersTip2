import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/tiktok_account_switcher.dart';
import 'instant_response_button.dart';

/// TikTok-style account switching modal with instant switching
class TikTokAccountSwitcherModal extends ConsumerStatefulWidget {
  const TikTokAccountSwitcherModal({super.key});

  @override
  ConsumerState<TikTokAccountSwitcherModal> createState() =>
      _TikTokAccountSwitcherModalState();
}

class _TikTokAccountSwitcherModalState
    extends ConsumerState<TikTokAccountSwitcherModal>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  final TikTokAccountSwitcher _accountSwitcher = TikTokAccountSwitcher();

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_fadeAnimation, _slideAnimation]),
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: _buildModal(),
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    // Start animations
    _fadeController.forward();
    _slideController.forward();

    // Initialize account switcher and add debug info
    _accountSwitcher.initialize().then((_) {
      debugPrint('🎯 TikTokAccountSwitcher initialized');
      debugPrint(
          '🎯 Saved accounts count: ${_accountSwitcher.savedAccounts.length}');
      debugPrint(
          '🎯 Current account: ${_accountSwitcher.currentAccount?.displayName}');
    });
  }

  Widget _buildModal() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A1A4D), // Dark blue
            Color(0xFF6633CC), // Purple
          ],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 20,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHandle(),
            _buildHeader(),
            const SizedBox(height: 16),
            _buildAccountList(),
            const SizedBox(height: 16),
            _buildAddAccountButton(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          const Text(
            'Switch Account',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          InstantResponseButton(
            onPressed: _closeModal,
            hapticType: HapticFeedbackType.lightImpact,
            showRippleEffect: false,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountList() {
    return Consumer(
      builder: (context, ref, child) {
        return ListenableBuilder(
          listenable: _accountSwitcher,
          builder: (context, child) {
            final accounts = _accountSwitcher.savedAccounts;

            if (accounts.isEmpty) {
              return _buildEmptyState();
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: accounts.length,
              itemBuilder: (context, index) {
                final account = accounts[index];
                return _buildAccountTile(account);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildAccountTile(SavedAccount account) {
    final isCurrent = account.isCurrent;
    final isSwitching = _accountSwitcher.isSwitching;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InstantResponseButton(
        onPressed:
            isSwitching || isCurrent ? null : () => _switchToAccount(account),
        hapticType: HapticFeedbackType.lightImpact,
        showRippleEffect: false,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isCurrent
                ? Colors.green.withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: isCurrent
                ? Border.all(
                    color: Colors.green.withValues(alpha: 0.3), width: 2)
                : Border.all(
                    color: Colors.white.withValues(alpha: 0.1), width: 1),
          ),
          child: Row(
            children: [
              // Avatar with current indicator
              Stack(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: isCurrent
                            ? [
                                Colors.green.withValues(alpha: 0.8),
                                Colors.greenAccent.withValues(alpha: 0.8)
                              ]
                            : [
                                Colors.purple.withValues(alpha: 0.8),
                                Colors.blue.withValues(alpha: 0.8)
                              ],
                      ),
                    ),
                    child: account.photoUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Image.network(
                              account.photoUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  _buildAvatarFallback(account),
                            ),
                          )
                        : _buildAvatarFallback(account),
                  ),
                  if (isCurrent)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 10,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),

              // Account info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.displayName,
                      style: TextStyle(
                        color: isCurrent ? Colors.green : Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      account.email,
                      style: TextStyle(
                        color: isCurrent
                            ? Colors.green.withValues(alpha: 0.8)
                            : Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              // Status indicator
              if (isCurrent) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: Colors.green.withValues(alpha: 0.4)),
                  ),
                  child: const Text(
                    'Current Account',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ] else if (isSwitching) ...[
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.swap_horiz,
                    color: Colors.white.withValues(alpha: 0.7),
                    size: 16,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarFallback(SavedAccount account) {
    return Center(
      child: Text(
        account.displayName.isNotEmpty
            ? account.displayName[0].toUpperCase()
            : '?',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.person_add,
            color: Colors.white.withValues(alpha: 0.5),
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'Add Another Account',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sign in with a different Google account to enable instant switching like TikTok',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _addAccount,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text('Add Account'),
          ),
        ],
      ),
    );
  }

  Widget _buildAddAccountButton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: InstantResponseButton(
        onPressed: _addAccount,
        hapticType: HapticFeedbackType.lightImpact,
        showRippleEffect: false,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add,
                color: Colors.white.withValues(alpha: 0.8),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Add Account',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _switchToAccount(SavedAccount account) async {
    HapticFeedback.lightImpact();

    // Check if this is the current account
    final currentAccount = _accountSwitcher.currentAccount;
    if (currentAccount != null && currentAccount.uid == account.uid) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('✅ You are already signed in as ${account.displayName}'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );

        // Close modal since we're already on this account
        _closeModal();
      }
      return;
    }

    // Clear any previous error state
    final success = await _accountSwitcher.switchToAccount(account);

    if (success) {
      // Trigger comprehensive data refresh with WidgetRef for instant UI updates
      await _accountSwitcher.triggerDataRefreshWithRef(ref);

      // Show success feedback
      HapticFeedback.mediumImpact();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '✅ Switched to ${account.displayName} - All data refreshed!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );

        // Close modal after successful switch
        _closeModal();
      }
    } else {
      // Show helpful message about re-authorization
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '🔄 Switching to ${account.displayName} requires signing in with that account'),
            backgroundColor: Colors.blue,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Sign In',
              textColor: Colors.white,
              onPressed: () => _showSignInPrompt(account),
            ),
          ),
        );
      }

      HapticFeedback.heavyImpact();
    }
  }

  void _showSignInPrompt(SavedAccount account) {
    // Close current modal
    _closeModal();

    // Show sign-in prompt with TikTok-style explanation
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            const Icon(Icons.swap_horiz, color: Colors.purple),
            const SizedBox(width: 8),
            Text('Switch to ${account.displayName}'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('To switch accounts like TikTok, you need to sign in with:'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.email, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(account.email)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'This will add the account for instant switching in the future!',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _triggerGoogleSignInForAccount(account);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }

  Future<void> _triggerGoogleSignInForAccount(SavedAccount account) async {
    debugPrint('🔄 Starting Google Sign-In for account: ${account.email}');

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Signing in to ${account.displayName}...',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This may take a moment...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Add a small delay to ensure the dialog is shown
      await Future.delayed(const Duration(milliseconds: 500));

      // Trigger Google Sign-In flow
      debugPrint('🔄 Calling performGoogleSignIn...');
      final success = await _accountSwitcher.performGoogleSignIn();
      debugPrint('🔄 Google Sign-In result: $success');

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        if (success) {
          debugPrint('✅ Google Sign-In successful, triggering data refresh...');

          // Trigger comprehensive data refresh for new account
          await _accountSwitcher.triggerDataRefreshWithRef(ref);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                    '✅ Successfully signed in! Account added for instant switching. All data refreshed!'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        } else {
          debugPrint('❌ Google Sign-In failed or was cancelled');

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                    '❌ Sign-in was cancelled or failed. Please try again.'),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 4),
                action: SnackBarAction(
                  label: 'Try Again',
                  textColor: Colors.white,
                  onPressed: () => _retryGoogleSignIn(account),
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error in _triggerGoogleSignInForAccount: $e');

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error during sign-in: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _retryGoogleSignIn(SavedAccount account) {
    // Hide current SnackBar and retry Google Sign-In
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    _triggerGoogleSignInForAccount(account);
  }

  Future<void> _addAccount() async {
    HapticFeedback.lightImpact();

    // Close current modal
    _closeModal();

    // Show add account dialog
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(Icons.person_add, color: Colors.purple),
              const SizedBox(width: 8),
              const Text('Add New Account'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'Add a new Google account for instant TikTok-style switching!'),
              SizedBox(height: 12),
              Text(
                'This will allow you to switch between accounts instantly, just like TikTok.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _triggerGoogleSignInForNewAccount();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
              child: const Text('Add Account'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _triggerGoogleSignInForNewAccount() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                const Text(
                  'Adding new account...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Trigger Google Sign-In flow for new account
      final success = await _accountSwitcher.performGoogleSignIn();

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        if (success) {
          // Trigger comprehensive data refresh for new account
          await _accountSwitcher.triggerDataRefreshWithRef(ref);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                    '✅ New account added! You can now switch accounts instantly. All data refreshed!'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                    '❌ Account addition was cancelled. Please try again.'),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _closeModal() {
    HapticFeedback.lightImpact();

    _slideController.reverse().then((_) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }
}
