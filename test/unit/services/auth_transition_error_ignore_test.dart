import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/utils/auth_transition_flutter_errors.dart';

void main() {
  group('isIgnorableAuthTransitionFlutterError', () {
    test('detects deactivated widget ancestor lookup', () {
      expect(
        isIgnorableAuthTransitionFlutterError(
          "Looking up a deactivated widget's ancestor is unsafe.",
        ),
        isTrue,
      );
    });

    test('detects provider mutation during build', () {
      expect(
        isIgnorableAuthTransitionFlutterError(
          'Tried to modify a provider while the widget tree was building.',
        ),
        isTrue,
      );
    });

    test('detects AccountClient deployment failure', () {
      expect(
        isIgnorableAuthTransitionFlutterError(
          'AccountClientException(STATUS_FAILED): This API endpoint is not '
          'available in the current deployment.',
        ),
        isTrue,
      );
    });

    test('detects disposed WidgetRef usage', () {
      expect(
        isIgnorableAuthTransitionFlutterError(
          'Bad state: Cannot use "ref" after the widget was disposed.',
        ),
        isTrue,
      );
    });

    test('rejects unrelated errors', () {
      expect(
        isIgnorableAuthTransitionFlutterError('Network error'),
        isFalse,
      );
    });
  });
}
