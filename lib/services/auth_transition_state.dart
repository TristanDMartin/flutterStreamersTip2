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

/// Whether the root shell should show the loading/splash state instead of auth.
bool resolveStartupShowsAuthLoading({
  required bool isSigningOut,
  required bool hasFirebaseUser,
  required bool isCheckingAuth,
  required bool isOauthInProgress,
  required ConnectionState authConnectionState,
}) {
  if (isSigningOut) {
    return true;
  }
  if (hasFirebaseUser) {
    return false;
  }
  // OAuth keeps AuthModalView mounted; it shows its own themed overlay.
  if (isOauthInProgress) {
    return false;
  }
  if (isCheckingAuth) {
    return true;
  }
  return authConnectionState == ConnectionState.waiting;
}
