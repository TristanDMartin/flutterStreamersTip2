import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/services/auth_transition_state.dart';
import 'package:streamers_tip/widgets/app_startup_wrapper.dart';

void main() {
  group('resolveStartupShell', () {
    test('shows loading while Firebase is still initializing', () {
      expect(
        resolveStartupShell(
          firebaseInitialized: false,
          startupGracePeriodElapsed: true,
          authConnectionState: ConnectionState.waiting,
          hasFirebaseUser: false,
          isSigningOut: false,
          isCheckingAuth: false,
          isOauthInProgress: false,
        ),
        StartupShell.loading,
      );
    });

    test('shows home whenever Firebase has a signed-in user', () {
      expect(
        resolveStartupShell(
          firebaseInitialized: true,
          startupGracePeriodElapsed: true,
          authConnectionState: ConnectionState.active,
          hasFirebaseUser: true,
          isSigningOut: false,
          isCheckingAuth: false,
          isOauthInProgress: false,
        ),
        StartupShell.home,
      );
    });

    test('shows auth when Firebase confirms there is no user', () {
      expect(
        resolveStartupShell(
          firebaseInitialized: true,
          startupGracePeriodElapsed: true,
          authConnectionState: ConnectionState.active,
          hasFirebaseUser: false,
          isSigningOut: false,
          isCheckingAuth: false,
          isOauthInProgress: false,
        ),
        StartupShell.auth,
      );
    });

    test('shows loading while Firebase auth emits its first event', () {
      expect(
        resolveStartupShell(
          firebaseInitialized: true,
          startupGracePeriodElapsed: true,
          authConnectionState: ConnectionState.waiting,
          hasFirebaseUser: false,
          isSigningOut: false,
          isCheckingAuth: false,
          isOauthInProgress: false,
        ),
        StartupShell.loading,
      );
    });

    test('shows auth while OAuth handoff is in progress', () {
      expect(
        resolveStartupShell(
          firebaseInitialized: true,
          startupGracePeriodElapsed: true,
          authConnectionState: ConnectionState.active,
          hasFirebaseUser: false,
          isSigningOut: false,
          isCheckingAuth: false,
          isOauthInProgress: true,
        ),
        StartupShell.auth,
      );
    });

    test('shows auth during OAuth even when Firebase connection is waiting',
        () {
      expect(
        resolveStartupShell(
          firebaseInitialized: true,
          startupGracePeriodElapsed: true,
          authConnectionState: ConnectionState.waiting,
          hasFirebaseUser: false,
          isSigningOut: false,
          isCheckingAuth: false,
          isOauthInProgress: true,
        ),
        StartupShell.auth,
      );
    });

    test('shows loading while auth session is being checked', () {
      expect(
        resolveStartupShell(
          firebaseInitialized: true,
          startupGracePeriodElapsed: true,
          authConnectionState: ConnectionState.active,
          hasFirebaseUser: false,
          isSigningOut: false,
          isCheckingAuth: true,
          isOauthInProgress: false,
        ),
        StartupShell.loading,
      );
    });

    test('does not expose home during sign out', () {
      expect(
        resolveStartupShell(
          firebaseInitialized: true,
          startupGracePeriodElapsed: true,
          authConnectionState: ConnectionState.active,
          hasFirebaseUser: true,
          isSigningOut: true,
          isCheckingAuth: false,
          isOauthInProgress: false,
        ),
        StartupShell.loading,
      );
    });
  });

  group('resolveStartupShowsAuthLoading', () {
    test('does not swap to splash during OAuth handoff', () {
      expect(
        resolveStartupShowsAuthLoading(
          isSigningOut: false,
          hasFirebaseUser: false,
          isCheckingAuth: false,
          isOauthInProgress: true,
          authConnectionState: ConnectionState.active,
        ),
        isFalse,
      );
    });
  });
}
