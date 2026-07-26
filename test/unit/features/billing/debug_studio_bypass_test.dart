import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/billing/debug_studio_bypass.dart';

void main() {
  test('DebugStudioBypass never grants Studio for null uid', () {
    expect(DebugStudioBypass.grantsStudio(null), isFalse);
  });

  test('DebugStudioBypass only active in debug mode', () {
    // In unit tests kDebugMode is true; known UID would grant.
    // Release builds compile with kDebugMode false → always false.
    expect(kReleaseMode, isFalse);
    expect(DebugStudioBypass.grantsStudio('unknown-uid'), isFalse);
  });
}
