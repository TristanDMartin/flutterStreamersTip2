import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:streamers_tip/services/password_reset_request_client.dart';

void main() {
  group('requestSitePasswordReset', () {
    test('posts the identifier to the site reset endpoint', () async {
      late http.Request capturedRequest;
      final MockClient mockClient = MockClient((http.Request request) async {
        capturedRequest = request;
        return http.Response(jsonEncode(<String, bool>{'ok': true}), 200);
      });
      await requestSitePasswordReset(
        ' creator@example.com ',
        client: mockClient,
      );
      expect(capturedRequest.url.path, '/api/auth/password-reset/request');
      expect(
        jsonDecode(capturedRequest.body),
        <String, String>{'identifier': 'creator@example.com'},
      );
    });

    test('throws with the server error message on failure', () async {
      final MockClient mockClient = MockClient(
        (http.Request request) async => http.Response(
          jsonEncode(<String, Object>{
            'ok': false,
            'error': 'Unable to send reset email right now. Try again later.',
          }),
          503,
        ),
      );
      expect(
        () => requestSitePasswordReset(
          'creator@example.com',
          client: mockClient,
        ),
        throwsA(
          isA<PasswordResetRequestException>()
              .having((e) => e.statusCode, 'statusCode', 503)
              .having((e) => e.isRateLimited, 'isRateLimited', false),
        ),
      );
    });

    test('flags rate limiting', () async {
      final MockClient mockClient = MockClient(
        (http.Request request) async => http.Response('Too Many', 429),
      );
      expect(
        () => requestSitePasswordReset(
          'creator@example.com',
          client: mockClient,
        ),
        throwsA(
          isA<PasswordResetRequestException>()
              .having((e) => e.isRateLimited, 'isRateLimited', true),
        ),
      );
    });
  });
}
