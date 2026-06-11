import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:streamers_tip/features/billing/subscription_repository.dart';

void main() {
  test('fetchEntitlements parses site API response', () async {
    final MockClient client = MockClient((http.Request request) async {
      expect(
        request.url.path,
        '/api/user/entitlements',
      );
      expect(request.headers['Authorization'], 'Bearer test-token');
      return http.Response(
        jsonEncode(<String, dynamic>{
          'tier': 'pro',
          'subscriptionStatus': 'active',
          'isPaid': true,
          'entitlements': <String, dynamic>{
            'maxPlatforms': 5,
            'monthlyAiCredits': 500,
            'canBulkPublish': true,
          },
          'usage': <String, dynamic>{
            'monthlyCreditsRemaining': 100,
          },
        }),
        200,
      );
    });
    final SubscriptionRepository repo = SubscriptionRepository(
      siteApiBase: 'https://streamerstip.com',
      httpClient: client,
      tokenProvider: () async => 'test-token',
      cacheTtl: Duration.zero,
    );
    final snapshot = await repo.fetchEntitlements();
    expect(snapshot.tierApi, 'pro');
    expect(snapshot.entitlements.monthlyAiCredits, 500);
    expect(snapshot.usage.monthlyCreditsRemaining, 100);
    repo.dispose();
  });
}
