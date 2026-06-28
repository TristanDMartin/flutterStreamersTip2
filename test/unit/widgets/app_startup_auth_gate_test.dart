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
          isSigningIn: false,
        ),
        StartupShell.loading,
      );
    });

    test('stays on splash while prior session hint exists before Firebase', () {
      expect(
        resolveStartupShell(
          firebaseInitialized: false,
          startupGracePeriodElapsed: false,
          authConnectionState: ConnectionState.waiting,
          hasFirebaseUser: false,
          isSigningOut: false,
          isCheckingAuth: false,
          isOauthInProgress: false,
          isSigningIn: false,
        ),
        StartupShell.loading,
      );
    });

    test('shows auth while 2FA verification is pending', () {
      expect(
        resolveStartupShell(
          firebaseInitialized: true,
          startupGracePeriodElapsed: true,
          authConnectionState: ConnectionState.active,
          hasFirebaseUser: true,
          isSigningOut: false,
          isCheckingAuth: false,
          isOauthInProgress: false,
          isSigningIn: false,
          isAwaiting2FA: true,
        ),
        StartupShell.auth,
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
          isSigningIn: false,
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
          isSigningIn: false,
        ),
        StartupShell.auth,
      );
    });

    test('shows auth while Firebase auth emits its first signed-out event', () {
      expect(
        resolveStartupShell(
          firebaseInitialized: true,
          startupGracePeriodElapsed: true,
          authConnectionState: ConnectionState.waiting,
          hasFirebaseUser: false,
          isSigningOut: false,
          isCheckingAuth: false,
          isOauthInProgress: false,
          isSigningIn: false,
        ),
        StartupShell.auth,
      );
    });

    test('stays on auth when stream reconnects with waiting but has data',
        () {
      expect(
        resolveStartupShell(
          firebaseInitialized: true,
          startupGracePeriodElapsed: true,
          authConnectionState: resolveEffectiveAuthConnectionState(
            authConnectionState: ConnectionState.waiting,
            hasAuthSnapshotData: true,
          ),
          hasFirebaseUser: false,
          isSigningOut: false,
          isCheckingAuth: false,
          isOauthInProgress: false,
          isSigningIn: false,
        ),
        StartupShell.auth,
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
          isSigningIn: false,
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
          isSigningIn: false,
        ),
        StartupShell.auth,
      );
    });

    test('shows auth during email sign-up even when Firebase connection is waiting',
        () {
      expect(
        resolveStartupShell(
          firebaseInitialized: true,
          startupGracePeriodElapsed: true,
          authConnectionState: ConnectionState.waiting,
          hasFirebaseUser: false,
          isSigningOut: false,
          isCheckingAuth: false,
          isOauthInProgress: false,
          isSigningIn: true,
        ),
        StartupShell.auth,
      );
    });

    test('shows auth while auth session is checked for signed-out users', () {
      expect(
        resolveStartupShell(
          firebaseInitialized: true,
          startupGracePeriodElapsed: true,
          authConnectionState: ConnectionState.active,
          hasFirebaseUser: false,
          isSigningOut: false,
          isCheckingAuth: true,
          isOauthInProgress: false,
          isSigningIn: false,
        ),
        StartupShell.auth,
      );
    });

    test('shows home while auth stream is waiting for signed-in users', () {
      expect(
        resolveStartupShell(
          firebaseInitialized: true,
          startupGracePeriodElapsed: true,
          authConnectionState: ConnectionState.waiting,
          hasFirebaseUser: true,
          isSigningOut: false,
          isCheckingAuth: true,
          isOauthInProgress: false,
          isSigningIn: false,
        ),
        StartupShell.home,
      );
    });

    test('shows auth in degraded mode when Firebase never becomes ready', () {
      expect(
        resolveStartupShell(
          firebaseInitialized: false,
          startupGracePeriodElapsed: true,
          allowDegradedAuthShell: true,
          authConnectionState: ConnectionState.waiting,
          hasFirebaseUser: false,
          isSigningOut: false,
          isCheckingAuth: false,
          isOauthInProgress: false,
          isSigningIn: false,
        ),
        StartupShell.auth,
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
          isSigningIn: false,
        ),
        StartupShell.loading,
      );
    });
  });

  group('resolveStartupShowsAuthLoading', () {
    test('does not swap to splash during email sign-in/sign-up', () {
      expect(
        resolveStartupShowsAuthLoading(
          isSigningOut: false,
          hasFirebaseUser: false,
          isCheckingAuth: false,
          isOauthInProgress: false,
          isSigningIn: true,
          authConnectionState: ConnectionState.waiting,
        ),
        isFalse,
      );
    });

    test('does not swap to splash during OAuth handoff', () {
      expect(
        resolveStartupShowsAuthLoading(
          isSigningOut: false,
          hasFirebaseUser: false,
          isCheckingAuth: false,
          isOauthInProgress: true,
          isSigningIn: false,
          authConnectionState: ConnectionState.active,
        ),
        isFalse,
      );
    });

    test('does not block auth shell while signed-out auth is checked', () {
      expect(
        resolveStartupShowsAuthLoading(
          isSigningOut: false,
          hasFirebaseUser: false,
          isCheckingAuth: true,
          isOauthInProgress: false,
          isSigningIn: false,
          authConnectionState: ConnectionState.active,
        ),
        isFalse,
      );
    });
  });

  group('resolveEffectiveAuthConnectionState', () {
    test('treats waiting with snapshot data as active', () {
      expect(
        resolveEffectiveAuthConnectionState(
          authConnectionState: ConnectionState.waiting,
          hasAuthSnapshotData: true,
        ),
        ConnectionState.active,
      );
    });

    test('treats waiting with firebase user as active even without snapshot data',
        () {
      expect(
        resolveEffectiveAuthConnectionState(
          authConnectionState: ConnectionState.waiting,
          hasAuthSnapshotData: false,
          hasFirebaseUser: true,
        ),
        ConnectionState.active,
      );
    });

    test('keeps waiting when snapshot has no data yet', () {
      expect(
        resolveEffectiveAuthConnectionState(
          authConnectionState: ConnectionState.waiting,
          hasAuthSnapshotData: false,
        ),
        ConnectionState.waiting,
      );
    });
  });
}
