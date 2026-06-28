import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../routing/app_routes.dart';
import '../services/unified_avatar_service.dart' as nav;
import '../widgets/auth_modal_view.dart';
import '../widgets/tiktok_account_switcher_modal.dart';
import 'account_deletion_service.dart';
import 'robust_auth_service.dart';
import 'tiktok_account_switcher.dart';

enum AddAccountOutcome {
  success,
  cancelled,
  failed,
  alreadyCurrent,
}

class AddAccountResult {
  const AddAccountResult({
    required this.outcome,
    this.message,
    this.stayedOnOriginalAccount = true,
  });

  final AddAccountOutcome outcome;
  final String? message;
  final bool stayedOnOriginalAccount;

  bool get isSuccess => outcome == AddAccountOutcome.success;
}

class AccountManagementService {
  const AccountManagementService();

  Future<void> showAccountSwitcher(BuildContext context) async {
    final TikTokAccountSwitcher accountSwitcher = TikTokAccountSwitcher();
    await accountSwitcher.initialize();
    await accountSwitcher.addCurrentAccount();
    if (!context.mounted) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => const TikTokAccountSwitcherModal(),
    );
  }

  Future<AddAccountResult> addAccount({
    required BuildContext context,
    required WidgetRef ref,
  }) async {
    final TikTokAccountSwitcher accountSwitcher = TikTokAccountSwitcher();
    await accountSwitcher.initialize();
    await accountSwitcher.addCurrentAccount();
    final SavedAccount? originalAccount = accountSwitcher.currentAccount;
    if (originalAccount == null) {
      return const AddAccountResult(
        outcome: AddAccountOutcome.failed,
        message: 'Sign in before adding another account.',
      );
    }
    if (!context.mounted) {
      return const AddAccountResult(outcome: AddAccountOutcome.cancelled);
    }
    final String? providerId = _resolveProviderId();
    if (providerId == 'google.com') {
      return _addGoogleAccount(
        context: context,
        ref: ref,
        accountSwitcher: accountSwitcher,
        originalAccount: originalAccount,
      );
    }
    return _addAccountViaAuthModal(
      context: context,
      ref: ref,
      accountSwitcher: accountSwitcher,
      originalAccount: originalAccount,
    );
  }

  Future<AddAccountResult> _addGoogleAccount({
    required BuildContext context,
    required WidgetRef ref,
    required TikTokAccountSwitcher accountSwitcher,
    required SavedAccount originalAccount,
  }) async {
    final bool success = await accountSwitcher.performGoogleSignIn(
      addOnly: true,
    );
    if (!context.mounted) {
      return const AddAccountResult(outcome: AddAccountOutcome.cancelled);
    }
    if (!success) {
      return const AddAccountResult(
        outcome: AddAccountOutcome.failed,
        message: 'Failed to add account. Please try again.',
      );
    }
    await accountSwitcher.addCurrentAccount();
    await accountSwitcher.triggerDataRefreshWithRef(ref);
    final firebase_auth.User? currentUser =
        firebase_auth.FirebaseAuth.instance.currentUser;
    final bool stayedOnOriginal =
        currentUser?.uid == originalAccount.uid;
    return AddAccountResult(
      outcome: AddAccountOutcome.success,
      message: stayedOnOriginal
          ? 'Account added successfully.'
          : 'Account added. You are signed in to the new account.',
      stayedOnOriginalAccount: stayedOnOriginal,
    );
  }

  Future<AddAccountResult> _addAccountViaAuthModal({
    required BuildContext context,
    required WidgetRef ref,
    required TikTokAccountSwitcher accountSwitcher,
    required SavedAccount originalAccount,
  }) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext ctx) => const AuthModalView(),
        fullscreenDialog: true,
      ),
    );
    if (!context.mounted) {
      return const AddAccountResult(outcome: AddAccountOutcome.cancelled);
    }
    final firebase_auth.User? currentUser =
        firebase_auth.FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const AddAccountResult(
        outcome: AddAccountOutcome.cancelled,
        message: 'Account addition was cancelled.',
      );
    }
    if (currentUser.uid == originalAccount.uid) {
      return const AddAccountResult(
        outcome: AddAccountOutcome.alreadyCurrent,
        message: 'You are already using this account.',
      );
    }
    await accountSwitcher.addCurrentAccount();
    bool stayedOnOriginal = false;
    if (originalAccount.provider == 'google.com') {
      final bool restored = await accountSwitcher.switchToAccount(
        originalAccount,
      );
      stayedOnOriginal = restored;
      if (restored) {
        await accountSwitcher.triggerDataRefreshWithRef(ref);
      } else {
        await accountSwitcher.triggerDataRefreshWithRef(ref);
      }
    } else {
      stayedOnOriginal = false;
      await accountSwitcher.triggerDataRefreshWithRef(ref);
    }
    return AddAccountResult(
      outcome: AddAccountOutcome.success,
      message: stayedOnOriginal
          ? 'Account added successfully.'
          : 'Account added and signed in.',
      stayedOnOriginalAccount: stayedOnOriginal,
    );
  }

  Future<bool> signOut({
    required BuildContext context,
    required WidgetRef ref,
    bool showAccountSwitcher = true,
  }) async {
    final TikTokAccountSwitcher accountSwitcher = TikTokAccountSwitcher();
    await accountSwitcher.initialize();
    final bool hasSavedAccounts = accountSwitcher.savedAccounts.isNotEmpty;
    final RobustAuthenticationService authService =
        ref.read(robustAuthServiceProvider);
    await authService.signOut();
    if (context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.root,
        (Route<dynamic> route) => false,
      );
    }
    if (!showAccountSwitcher || !hasSavedAccounts) {
      return true;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      final BuildContext? rootContext =
          nav.NavigationService.navigatorKey.currentContext;
      if (rootContext == null || !rootContext.mounted) {
        return;
      }
      await showModalBottomSheet<void>(
        context: rootContext,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (BuildContext ctx) => const TikTokAccountSwitcherModal(),
      );
    });
    return true;
  }

  Future<AccountDeletionResult> deleteAccount({
    required BuildContext context,
    required WidgetRef ref,
  }) {
    return AccountDeletionService().deleteCurrentAccount(
      context: context,
      ref: ref,
    );
  }

  String? _resolveProviderId() {
    final firebase_auth.User? user =
        firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null || user.providerData.isEmpty) {
      return 'password';
    }
    return user.providerData.first.providerId;
  }
}
