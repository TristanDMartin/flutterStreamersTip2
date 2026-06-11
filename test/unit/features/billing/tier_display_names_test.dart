import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/billing/tier_display_names.dart';

void main() {
  test('tier display names match Pricing v2', () {
    expect(tierDisplayNameForApi('starter'), 'Creator');
    expect(tierDisplayNameForApi('pro'), 'Creator Pro');
    expect(tierDisplayNameForApi('studio'), 'Creator Studio');
  });

  test('trialing status label', () {
    expect(subscriptionStatusDisplayLabel('trialing'), 'Free trial');
  });
}
