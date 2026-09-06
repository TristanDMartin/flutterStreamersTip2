import 'package:flutter/widgets.dart';

/// High-level auth shell state for login/logout transitions.
enum AuthTransitionState {
  authenticated,
  unauthenticated,
  signingOut,
  signingIn,
  checkingAuth,
}

/// Whether the app shell should treat the user as logged in.
bool resolveAuthShellLoggedIn({
  required bool loggedInFlag,
  required AuthTransitionState transitionState,
}) {
  return loggedInFlag &&
      transitionState != AuthTransitionState.signingOut &&
      transitionState != AuthTransitionState.signingIn &&
      transitionState != AuthTransitionState.checkingAuth;
}

/// Final auth transition after a debounced sign-in attempt completes.
AuthTransitionState resolveDebouncedAuthTransition({
  required bool resultSuccess,
  required bool isLoggedInFlag,
}) {
  if (resultSuccess || isLoggedInFlag) {
    return AuthTransitionState.authenticated;
  }
  return AuthTransitionState.unauthenticated;
}

/// Firebase [StreamBuilder] can briefly report [ConnectionState.waiting] on
/// rebuild even when [initialData] is already available. Treat that as active
/// so the auth shell does not flash back to splash.
ConnectionState resolveEffectiveAuthConnectionState({
  required ConnectionState authConnectionState,
  required bool hasAuthSnapshotData,
  bool hasFirebaseUser = false,
}) {
  if (authConnectionState == ConnectionState.waiting &&
      (hasAuthSnapshotData || hasFirebaseUser)) {
    return ConnectionState.active;
  }
  return authConnectionState;
}

/// Whether the root shell should show the loading/splash state instead of auth.
bool resolveStartupShowsAuthLoading({
  required bool isSigningOut,
  required bool hasFirebaseUser,
  required bool isCheckingAuth,
  required bool isOauthInProgress,
  required bool isSigningIn,
  required ConnectionState authConnectionState,
  bool hadPriorSession = false,
}) {
  if (isSigningOut) {
    return true;
  }
  if (hasFirebaseUser) {
    // Firebase session is authoritative — never block the shell on splash while
    // robust auth hydrates profile data or the auth stream reconnects.
    return false;
  }
  // Signed-out users see the auth shell immediately; child screens own spinners.
  if (isOauthInProgress) {
    return false;
  }
  if (isSigningIn) {
    return false;
  }
  // Returning users: stay on splash until Firebase confirms signed-in or out.
  if (hadPriorSession &&
      (isCheckingAuth || authConnectionState == ConnectionState.waiting)) {
    return true;
  }
  return false;
}

/// Client Firestore cannot create `users/{uid}` until the password email is
/// verified (`hasVerifiedEmail`). Identity fields are also blocked on create.
bool emailSignupMayWriteUserDocument({required bool emailVerified}) {
  return emailVerified;
}
