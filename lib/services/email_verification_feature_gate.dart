import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../utils/auth_post_login_navigation.dart';
import '../widgets/email_verification_required_sheet.dart';

enum EmailVerificationGatedFeature {
  directMessages,
  tipping,
  withdrawals,
}

abstract final class EmailVerificationFeatureGate {
  static bool isBlocked(EmailVerificationGatedFeature feature) {
    return firebaseUserNeedsEmailVerification(FirebaseAuth.instance.currentUser);
  }

  static String titleFor(EmailVerificationGatedFeature feature) {
    return switch (feature) {
      EmailVerificationGatedFeature.directMessages => 'Verify email to message',
      EmailVerificationGatedFeature.tipping => 'Verify email to send tips',
      EmailVerificationGatedFeature.withdrawals =>
        'Verify email to withdraw earnings',
    };
  }

  static String messageFor(EmailVerificationGatedFeature feature) {
    return switch (feature) {
      EmailVerificationGatedFeature.directMessages =>
        'Direct messages are available after you verify your email. '
            'Check your inbox for the verification link.',
      EmailVerificationGatedFeature.tipping =>
        'Tips help support creators. Verify your email before sending a tip.',
      EmailVerificationGatedFeature.withdrawals =>
        'Withdrawals require a verified email for account security.',
    };
  }

  /// Returns true when the gated action may proceed.
  static Future<bool> ensureAllowed(
    BuildContext context,
    EmailVerificationGatedFeature feature,
  ) async {
    if (!isBlocked(feature)) {
      return true;
    }
    final bool verified = await showEmailVerificationRequiredSheet(
      context: context,
      feature: feature,
    );
    return verified;
  }

  static Future<bool> ensureCanSendDirectMessage(BuildContext context) {
    return ensureAllowed(context, EmailVerificationGatedFeature.directMessages);
  }

  static Future<bool> ensureCanTip(BuildContext context) {
    return ensureAllowed(context, EmailVerificationGatedFeature.tipping);
  }

  static Future<bool> ensureCanWithdraw(BuildContext context) {
    return ensureAllowed(context, EmailVerificationGatedFeature.withdrawals);
  }

  static Future<bool> refreshVerificationStatus() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return false;
    }
    try {
      await user.reload();
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
    } catch (_) {}
    return !firebaseUserNeedsEmailVerification(
      FirebaseAuth.instance.currentUser,
    );
  }
}
