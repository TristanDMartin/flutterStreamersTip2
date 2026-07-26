import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/config/release_config_health.dart';

void main() {
  test('evaluate returns a snapshot without throwing', () {
    final ReleaseConfigHealth actual = ReleaseConfigHealth.evaluate();
    expect(actual.missingKeys, isA<List<String>>());
    expect(actual.warnings, isA<List<String>>());
    // Tests run without dart-defines; Giphy is expected missing.
    expect(actual.isGiphyConfigured, isFalse);
    expect(actual.missingKeys, contains('GIPHY_API_KEY'));
    // Billing has a non-empty default URL in this project.
    expect(actual.isBillingVerifyConfigured, isTrue);
  });
}
