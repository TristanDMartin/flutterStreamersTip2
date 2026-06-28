import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Thrown when the user cancels a re-authentication prompt.
class AccountReauthenticationCancelled implements Exception {
  const AccountReauthenticationCancelled();
}

/// Re-authenticates the current Firebase user before sensitive actions.
class AccountReauthenticationService {
  const AccountReauthenticationService();

  Future<void> reauthenticateCurrentUser(BuildContext context) async {
    final firebase_auth.User? user =
        firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('No signed-in user to re-authenticate.');
    }
    final String providerId = _resolveProviderId(user);
    switch (providerId) {
      case 'google.com':
        await _reauthenticateWithGoogle(user);
        return;
      case 'apple.com':
        await _reauthenticateWithApple(user);
        return;
      case 'password':
        await _reauthenticateWithPassword(context, user);
        return;
      default:
        throw UnsupportedError(
          'Re-authentication is not supported for this sign-in method.',
        );
    }
  }

  String _resolveProviderId(firebase_auth.User user) {
    if (user.providerData.isEmpty) {
      return 'password';
    }
    return user.providerData.first.providerId;
  }

  Future<void> _reauthenticateWithGoogle(firebase_auth.User user) async {
    final GoogleSignIn googleSignIn = GoogleSignIn();
    await googleSignIn.signOut();
    final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      throw const AccountReauthenticationCancelled();
    }
    if (googleUser.email != user.email) {
      throw StateError('Please sign in with ${user.email} to continue.');
    }
    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;
    final firebase_auth.AuthCredential credential =
        firebase_auth.GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    await user.reauthenticateWithCredential(credential);
  }

  Future<void> _reauthenticateWithApple(firebase_auth.User user) async {
    final bool isAvailable = await SignInWithApple.isAvailable();
    if (!isAvailable) {
      throw UnsupportedError('Apple Sign-In is not available on this device.');
    }
    final AuthorizationCredentialAppleID appleCredential =
        await SignInWithApple.getAppleIDCredential(
      scopes: <AppleIDAuthorizationScopes>[
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );
    final firebase_auth.OAuthCredential credential =
        firebase_auth.OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      accessToken: appleCredential.authorizationCode,
    );
    await user.reauthenticateWithCredential(credential);
  }

  Future<void> _reauthenticateWithPassword(
    BuildContext context,
    firebase_auth.User user,
  ) async {
    final String? email = user.email;
    if (email == null || email.isEmpty) {
      throw StateError('This account does not have an email password.');
    }
    final String? password = await _promptForPassword(context, email);
    if (password == null || password.isEmpty) {
      throw const AccountReauthenticationCancelled();
    }
    final firebase_auth.AuthCredential credential =
        firebase_auth.EmailAuthProvider.credential(
      email: email,
      password: password,
    );
    await user.reauthenticateWithCredential(credential);
  }

  Future<String?> _promptForPassword(
    BuildContext context,
    String email,
  ) async {
    final TextEditingController controller = TextEditingController();
    final String? password = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        final ColorScheme cs = Theme.of(ctx).colorScheme;
        final TextTheme tt = Theme.of(ctx).textTheme;
        return AlertDialog(
          backgroundColor: cs.surfaceContainerHigh,
          title: Text(
            'Confirm Your Password',
            style: tt.titleLarge?.copyWith(color: cs.onSurface),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Enter the password for $email to continue.',
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                obscureText: true,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onSubmitted: (String value) => Navigator.of(ctx).pop(value),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel', style: TextStyle(color: cs.primary)),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text),
              child: Text(
                'Continue',
                style: TextStyle(
                  color: cs.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return password;
  }
}
