import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/simple_logout_service.dart';
import 'instant_response_button.dart';

class AccountManagementMenu extends ConsumerWidget {
  const AccountManagementMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6137EB), Color(0xFF1C135D)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // HIDDEN: Switch Account and Add Account (needs more work)
          // _buildAccountOption(
          //   context,
          //   icon: Icons.swap_horiz,
          //   title: 'Switch Account',
          //   subtitle: 'Change to another account',
          //   onTap: () => _handleSwitchAccount(context),
          // ),
          // _buildDivider(),
          // _buildAccountOption(
          //   context,
          //   icon: Icons.person_add,
          //   title: 'Add Account',
          //   subtitle: 'Add a new account',
          //   onTap: () => _handleAddAccount(context),
          // ),
          // _buildDivider(),
          _buildAccountOption(
            context,
            icon: Icons.logout,
            title: 'Log Out',
            subtitle: 'Sign out of your account',
            onTap: () => _handleLogOut(context, ref),
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  Widget _buildAccountOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InstantResponseButton(
      onPressed: onTap,
      hapticType: HapticFeedbackType.lightImpact,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDestructive
                    ? Colors.red.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isDestructive ? Colors.red : Colors.white,
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
                      color: isDestructive ? Colors.red : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isDestructive
                          ? Colors.red.withValues(alpha: 0.7)
                          : Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.white.withValues(alpha: 0.5),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  // Removed unused methods: _buildDivider, _handleSwitchAccount, _handleAddAccount
  // These were commented out in the UI and are not currently used

  void _handleLogOut(BuildContext context, WidgetRef ref) {
    Navigator.of(context).pop(); // Close the menu
    _showLogOutDialog(context, ref);
  }

  void _showLogOutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
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
                  'Log Out',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Are you sure you want to log out?',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: InstantResponseButton(
                        onPressed: () => Navigator.of(context).pop(),
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
                        onPressed: () async {
                          debugPrint('🔐 Logout button tapped!');
                          debugPrint('🔐 Closing dialog...');
                          Navigator.of(context).pop();
                          debugPrint(
                              '🔐 Dialog closed, calling SimpleLogoutService.logout...');
                          final result =
                              await SimpleLogoutService.logout(context);
                          debugPrint(
                              '🔐 SimpleLogoutService.logout completed with result: $result');
                        },
                        hapticType: HapticFeedbackType.mediumImpact,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Text(
                              'Log Out',
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
  }
}
