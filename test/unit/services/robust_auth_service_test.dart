import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/services/auth_transition_state.dart';

void main() {
  group('resolveAuthShellLoggedIn', () {
    test('authenticated session is visible to app shell', () {
      expect(
        resolveAuthShellLoggedIn(
          loggedInFlag: true,
          transitionState: AuthTransitionState.authenticated,
        ),
        isTrue,
      );
    });

    test('signingIn hides shell login even when flag is set', () {
      expect(
        resolveAuthShellLoggedIn(
          loggedInFlag: true,
          transitionState: AuthTransitionState.signingIn,
        ),
        isFalse,
      );
    });

    test('checkingAuth hides shell login while startup resolves', () {
      expect(
        resolveAuthShellLoggedIn(
          loggedInFlag: true,
          transitionState: AuthTransitionState.checkingAuth,
        ),
        isFalse,
      );
    });

    test('promoted authenticated session exits auth shell', () {
      const bool loggedInFlag = true;
      const AuthTransitionState signingIn = AuthTransitionState.signingIn;
      const AuthTransitionState authenticated =
          AuthTransitionState.authenticated;

      expect(
        resolveAuthShellLoggedIn(
          loggedInFlag: loggedInFlag,
          transitionState: signingIn,
        ),
        isFalse,
      );
      expect(
        resolveAuthShellLoggedIn(
          loggedInFlag: loggedInFlag,
          transitionState: authenticated,
        ),
        isTrue,
      );
    });
  });

  group('resolveDebouncedAuthTransition', () {
    test('failed debounce with existing login stays authenticated', () {
      expect(
        resolveDebouncedAuthTransition(
          resultSuccess: false,
          isLoggedInFlag: true,
        ),
        AuthTransitionState.authenticated,
      );
    });

    test('failed debounce without login returns unauthenticated', () {
      expect(
        resolveDebouncedAuthTransition(
          resultSuccess: false,
          isLoggedInFlag: false,
        ),
        AuthTransitionState.unauthenticated,
      );
    });

    test('successful debounce returns authenticated', () {
      expect(
        resolveDebouncedAuthTransition(
          resultSuccess: true,
          isLoggedInFlag: false,
        ),
        AuthTransitionState.authenticated,
      );
    });
  });
}
