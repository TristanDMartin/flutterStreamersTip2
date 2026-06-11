import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/core/firebase_app_check_startup.dart';

void main() {
  test('ensureAppCheckReadyForFirestore skips when Firebase not initialized',
      () async {
    final AppCheckReadiness readiness =
        await ensureAppCheckReadyForFirestore();
    expect(readiness.isReady, isFalse);
    expect(readiness.detail, contains('Firebase not initialized'));
  });
}
