import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';

import '../services/pending_auth_redirect_service.dart';
import '../widgets/email_verification_view.dart';

/// Routes after Firebase sign-in: verification gate then home / pending deep link.
Future<void> navigateAfterAuthenticated(BuildContext context) async {
  final firebase_auth.User? user =
      firebase_auth.FirebaseAuth.instance.currentUser;
  if (user == null || !context.mounted) {
    return;
  }
  await user.reload();
  final firebase_auth.User? fresh =
      firebase_auth.FirebaseAuth.instance.currentUser;
  if (fresh == null || !context.mounted) {
    return;
  }
  if (!fresh.emailVerified) {
    await Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute<void>(
        builder: (BuildContext ctx) => EmailVerificationView(
          email: fresh.email ?? '',
          onVerified: () {},
        ),
      ),
    );
    return;
  }
  PendingAuthRedirectService.instance.consumeOrGoHome(context);
}

bool firebaseUserNeedsEmailVerification(firebase_auth.User? user) {
  return user != null && !user.emailVerified;
}
