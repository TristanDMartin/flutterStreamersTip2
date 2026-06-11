import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/services/auth_transition_state.dart';

void main() {
  group('AuthTransitionState', () {
    test('defines logout and login transition states', () {
      expect(AuthTransitionState.signingOut.name, 'signingOut');
      expect(AuthTransitionState.signingIn.name, 'signingIn');
      expect(AuthTransitionState.authenticated.name, 'authenticated');
      expect(AuthTransitionState.unauthenticated.name, 'unauthenticated');
      expect(AuthTransitionState.checkingAuth.name, 'checkingAuth');
    });
  });

  group('resolveAuthShellLoggedIn', () {
    test('logged out flag never shows shell login', () {
      expect(
        resolveAuthShellLoggedIn(
          loggedInFlag: false,
          transitionState: AuthTransitionState.authenticated,
        ),
        isFalse,
      );
    });
  });
}
