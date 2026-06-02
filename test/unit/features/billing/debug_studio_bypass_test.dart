import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/billing/debug_studio_bypass.dart';

void main() {
  test('grantsStudio is false in release for known bypass uids', () {
    if (!kDebugMode) {
      expect(
        DebugStudioBypass.grantsStudio('bU0RxyZ2L4ULAv1Co5L4f825yV73'),
        isFalse,
      );
    }
  });

  test('grantsStudio is false for unknown uid', () {
    expect(DebugStudioBypass.grantsStudio('unknown-uid'), isFalse);
  });
}
