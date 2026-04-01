import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../services/tiktok_account_switcher.dart';

class AccountSwitcherState {
  const AccountSwitcherState({
    required this.savedAccounts,
    required this.currentAccount,
    required this.isSwitching,
  });

  final List<SavedAccount> savedAccounts;
  final SavedAccount? currentAccount;
  final bool isSwitching;

  bool get hasMultipleAccounts => savedAccounts.length > 1;

  static AccountSwitcherState fromSwitcher(TikTokAccountSwitcher switcher) {
    return AccountSwitcherState(
      savedAccounts: List<SavedAccount>.unmodifiable(switcher.savedAccounts),
      currentAccount: switcher.currentAccount,
      isSwitching: switcher.isSwitching,
    );
  }
}

class AccountSwitcherNotifier extends Notifier<AccountSwitcherState> {
  late final TikTokAccountSwitcher _switcher;
  VoidCallback? _listener;

  @override
  AccountSwitcherState build() {
    _switcher = TikTokAccountSwitcher();
    _listener = () => state = AccountSwitcherState.fromSwitcher(_switcher);
    _switcher.addListener(_listener!);
    ref.onDispose(() {
      final VoidCallback? listener = _listener;
      if (listener != null) {
        _switcher.removeListener(listener);
      }
      _listener = null;
    });
    _switcher.initialize().then((_) {
      final VoidCallback? listener = _listener;
      if (listener == null) return;
      listener();
    });
    return AccountSwitcherState.fromSwitcher(_switcher);
  }

  Future<void> addCurrentAccount() => _switcher.addCurrentAccount();

  Future<bool> switchToAccount(SavedAccount account) =>
      _switcher.switchToAccount(account);
}

/// Provider for TikTok-style account switcher
final NotifierProvider<AccountSwitcherNotifier, AccountSwitcherState>
    accountSwitcherProvider =
    NotifierProvider<AccountSwitcherNotifier, AccountSwitcherState>(
        AccountSwitcherNotifier.new);

/// Provider for saved accounts list
final savedAccountsProvider = Provider<List<SavedAccount>>((ref) {
  final AccountSwitcherState state = ref.watch(accountSwitcherProvider);
  return state.savedAccounts;
});

/// Provider for current account
final currentAccountProvider = Provider<SavedAccount?>((ref) {
  final AccountSwitcherState state = ref.watch(accountSwitcherProvider);
  return state.currentAccount;
});

/// Provider for switching state
final isSwitchingAccountProvider = Provider<bool>((ref) {
  final AccountSwitcherState state = ref.watch(accountSwitcherProvider);
  return state.isSwitching;
});

/// Provider for multiple accounts check
final hasMultipleAccountsProvider = Provider<bool>((ref) {
  final AccountSwitcherState state = ref.watch(accountSwitcherProvider);
  return state.hasMultipleAccounts;
});
