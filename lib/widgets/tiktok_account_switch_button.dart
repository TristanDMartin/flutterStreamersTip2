import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/account_switcher_provider.dart';
import '../services/tiktok_account_switcher.dart';
import 'tiktok_account_switcher_modal.dart';
import 'instant_response_button.dart';

/// TikTok-style account switching button with instant switching
class TikTokAccountSwitchButton extends ConsumerWidget {
  final bool showLabel;
  final double size;
  final EdgeInsets? padding;

  const TikTokAccountSwitchButton({
    super.key,
    this.showLabel = false,
    this.size = 40,
    this.padding,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountSwitcher = ref.watch(accountSwitcherProvider);
    final currentAccount = ref.watch(currentAccountProvider);
    final savedAccounts = ref.watch(savedAccountsProvider);
    final hasMultipleAccounts = ref.watch(hasMultipleAccountsProvider);

    // Don't show if no multiple accounts or if we only have the current account
    if (!hasMultipleAccounts || savedAccounts.length <= 1) {
      return const SizedBox.shrink();
    }

    return InstantResponseButton(
      onPressed: () => _showAccountSwitcher(context),
      hapticType: HapticFeedbackType.lightImpact,
      showRippleEffect: false,
      child: Container(
        padding: padding ?? const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Avatar with switching indicator
            Stack(
              children: [
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6633CC), Color(0xFF1A1A4D)],
                    ),
                  ),
                  child: currentAccount?.photoUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(size / 2),
                          child: Image.network(
                            currentAccount!.photoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _buildAvatarFallback(currentAccount),
                          ),
                        )
                      : _buildAvatarFallback(currentAccount),
                ),

                // Switching indicator
                if (accountSwitcher.isSwitching)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.3),
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Multiple accounts indicator
                if (hasMultipleAccounts && !accountSwitcher.isSwitching)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 1),
                      ),
                      child: const Icon(
                        Icons.swap_horiz,
                        size: 8,
                        color: Colors.black,
                      ),
                    ),
                  ),
              ],
            ),

            // Label
            if (showLabel && currentAccount != null) ...[
              const SizedBox(height: 4),
              SizedBox(
                width: size + 16,
                child: Text(
                  currentAccount.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarFallback(SavedAccount? account) {
    final initial = account?.displayName.isNotEmpty == true
        ? account!.displayName[0].toUpperCase()
        : '?';

    return Center(
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showAccountSwitcher(BuildContext context) {
    HapticFeedback.lightImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const TikTokAccountSwitcherModal(),
    );
  }
}

/// Compact account switching button for header/toolbar
class TikTokAccountSwitchIcon extends ConsumerWidget {
  final double size;
  final Color? color;

  const TikTokAccountSwitchIcon({
    super.key,
    this.size = 24,
    this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedAccounts = ref.watch(savedAccountsProvider);
    final hasMultipleAccounts = ref.watch(hasMultipleAccountsProvider);
    final isSwitching = ref.watch(isSwitchingAccountProvider);

    if (!hasMultipleAccounts || savedAccounts.length <= 1) {
      return const SizedBox.shrink();
    }

    return InstantResponseButton(
      onPressed: () => _showAccountSwitcher(context),
      hapticType: HapticFeedbackType.lightImpact,
      showRippleEffect: false,
      child: isSwitching
          ? SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  color ?? Colors.white,
                ),
              ),
            )
          : Icon(
              Icons.swap_horiz,
              size: size,
              color: color ?? Colors.white,
            ),
    );
  }

  void _showAccountSwitcher(BuildContext context) {
    HapticFeedback.lightImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const TikTokAccountSwitcherModal(),
    );
  }
}
