import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/tiktok_account_switcher.dart';

/// Provider for TikTok-style account switcher
final accountSwitcherProvider = ChangeNotifierProvider<TikTokAccountSwitcher>((ref) {
  final switcher = TikTokAccountSwitcher();
  // Initialize the switcher
  switcher.initialize();
  return switcher;
});

/// Provider for saved accounts list
final savedAccountsProvider = Provider<List<SavedAccount>>((ref) {
  final switcher = ref.watch(accountSwitcherProvider);
  return switcher.savedAccounts;
});

/// Provider for current account
final currentAccountProvider = Provider<SavedAccount?>((ref) {
  final switcher = ref.watch(accountSwitcherProvider);
  return switcher.currentAccount;
});

/// Provider for switching state
final isSwitchingAccountProvider = Provider<bool>((ref) {
  final switcher = ref.watch(accountSwitcherProvider);
  return switcher.isSwitching;
});

/// Provider for multiple accounts check
final hasMultipleAccountsProvider = Provider<bool>((ref) {
  final switcher = ref.watch(accountSwitcherProvider);
  final savedAccounts = switcher.savedAccounts;
  // Only show switcher if we have more than 1 account
  return savedAccounts.length > 1;
});
