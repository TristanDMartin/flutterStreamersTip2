import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/firebase_app_check_startup.dart';
import 'account_local_data_teardown.dart';
import 'production_monitoring_service.dart';
import 'robust_auth_service.dart';
import 'tiktok_account_switcher.dart';
import '../utils/user_facing_error.dart';

enum AccountDeletionOutcome {
  success,
  cancelled,
  failed,
}

class AccountDeletionResult {
  const AccountDeletionResult({
    required this.outcome,
    this.message,
  });

  final AccountDeletionOutcome outcome;
  final String? message;

  bool get isSuccess => outcome == AccountDeletionOutcome.success;
}

class AccountDeletionService {
  AccountDeletionService({
    FirebaseFunctions? functions,
  })  : _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;

  Future<AccountDeletionResult> deleteCurrentAccount({
    required BuildContext context,
    required WidgetRef ref,
  }) async {
    final firebase_auth.User? user =
        firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const AccountDeletionResult(
        outcome: AccountDeletionOutcome.failed,
        message: 'No signed-in account found.',
      );
    }
    final String userId = user.uid;
    final RobustAuthenticationService authService =
        ref.read(robustAuthServiceProvider);
    try {
      final AppCheckReadiness appCheck =
          await ensureAppCheckReadyForFirestore();
      if (!appCheck.isReady && isAppCheckEnabledForBuild()) {
        await ProductionMonitoringService.instance.recordAppCheckBlocked(
          'delete_account',
        );
        return AccountDeletionResult(
          outcome: AccountDeletionOutcome.failed,
          message: 'Security verification failed. Please restart the app.',
        );
      }
      final HttpsCallable callable = _functions.httpsCallable('deleteAccount');
      await callable.call(<String, dynamic>{'confirm': true});
    } catch (e) {
      debugPrint('❌ AccountDeletionService cloud delete failed: $e');
      return AccountDeletionResult(
        outcome: AccountDeletionOutcome.failed,
        message: UserFacingError.message(e),
      );
    }
    await AccountLocalDataTeardown.executeAfterAccountDeletion(
      userId: userId,
    );
    try {
      final TikTokAccountSwitcher accountSwitcher = TikTokAccountSwitcher();
      await accountSwitcher.initialize();
      await accountSwitcher.removeAccountByUid(userId);
    } catch (e) {
      debugPrint('⚠️ AccountDeletionService saved-account cleanup: $e');
    }
    await _signOutAfterDeletion(authService);
    return const AccountDeletionResult(
      outcome: AccountDeletionOutcome.success,
      message: 'Account deleted successfully',
    );
  }

  Future<void> _signOutAfterDeletion(
    RobustAuthenticationService authService,
  ) async {
    try {
      await authService.signOut();
    } catch (e) {
      debugPrint('⚠️ AccountDeletionService auth service sign-out: $e');
    }
  }
}
