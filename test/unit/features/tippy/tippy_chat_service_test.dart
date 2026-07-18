import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:streamers_tip/core/firebase_app_check_startup.dart';
import 'package:streamers_tip/features/tippy/tippy_chat_service.dart';

void main() {
  group('TippyChatService', () {
    TippyChatService buildService(MockClient client, {Duration? timeout}) {
      return TippyChatService(
        apiBase: 'https://staging.example.com',
        httpClient: client,
        tokenProvider: () async => 'token_123',
        appCheckReadinessProvider: ({bool forceRefresh = false}) async =>
            const AppCheckReadiness(isReady: true, detail: 'test'),
        requestTimeout: timeout ?? const Duration(seconds: 1),
      );
    }

    test('parses valid success response', () async {
      final MockClient client = MockClient((http.Request request) async {
        return http.Response(
          '{"success":true,"data":{"message":"Hello"},"credits":{"remaining":24,"used":1,"limit":250,"tier":"pro"},"requestId":"req_1"}',
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });
      final TippyChatService service = buildService(client);
      final TippyChatResult actual = await service.sendMessage(
        messages: const <TippyChatMessage>[
          TippyChatMessage(role: 'user', content: 'hi'),
        ],
      );
      expect(actual.message, 'Hello');
      expect(actual.creditsRemaining, 24);
    });

    test('sends App Check header from readiness preflight', () async {
      final MockClient client = MockClient((http.Request request) async {
        expect(request.headers['X-Firebase-AppCheck'], 'app_check_123');
        return http.Response(
          '{"success":true,"data":{"message":"Hello"},"credits":{"remaining":24,"used":1,"limit":250,"tier":"pro"},"requestId":"req_1"}',
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });
      final TippyChatService service = TippyChatService(
        apiBase: 'https://staging.example.com',
        httpClient: client,
        tokenProvider: () async => 'token_123',
        appCheckReadinessProvider: ({bool forceRefresh = false}) async =>
            const AppCheckReadiness(
          isReady: true,
          detail: 'test',
          appCheckToken: 'app_check_123',
        ),
        requestTimeout: const Duration(seconds: 1),
      );

      await service.sendMessage(
        messages: const <TippyChatMessage>[
          TippyChatMessage(role: 'user', content: 'hi'),
        ],
      );
    });

    test('refreshes App Check token after backend verification rejection',
        () async {
      final List<bool> forceRefreshCalls = <bool>[];
      final List<String?> sentAppCheckHeaders = <String?>[];
      var requestCount = 0;
      final MockClient client = MockClient((http.Request request) async {
        requestCount += 1;
        sentAppCheckHeaders.add(request.headers['X-Firebase-AppCheck']);
        if (requestCount == 1) {
          return http.Response(
            '{"success":false,"error":{"code":"APP_CHECK_INVALID","message":"App Check token is invalid.","status":401,"retryable":true},"requestId":"req_bad"}',
            401,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }
        return http.Response(
          '{"success":true,"data":{"message":"Hello after refresh"},"credits":{"remaining":24,"used":1,"limit":250,"tier":"pro"},"requestId":"req_ok"}',
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });
      final TippyChatService service = TippyChatService(
        apiBase: 'https://staging.example.com',
        httpClient: client,
        tokenProvider: () async => 'token_123',
        appCheckReadinessProvider: ({bool forceRefresh = false}) async {
          forceRefreshCalls.add(forceRefresh);
          return AppCheckReadiness(
            isReady: true,
            detail: 'test',
            appCheckToken: forceRefresh ? 'fresh_app_check' : 'stale_app_check',
          );
        },
        requestTimeout: const Duration(seconds: 1),
      );

      final TippyChatResult result = await service.sendMessage(
        messages: const <TippyChatMessage>[
          TippyChatMessage(role: 'user', content: 'hi'),
        ],
      );

      expect(result.message, 'Hello after refresh');
      expect(forceRefreshCalls, <bool>[false, true]);
      expect(sentAppCheckHeaders, <String?>[
        'stale_app_check',
        'fresh_app_check',
      ]);
    });

    test('removes leaked provider metadata prefix from chat response',
        () async {
      final MockClient client = MockClient((http.Request request) async {
        return http.Response(
          '{"success":true,"data":{"message":"model: claude-3-5-haiku-20241022\\nHere is the answer."},"credits":{"remaining":24,"used":1,"limit":250,"tier":"pro"},"requestId":"req_1"}',
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });
      final TippyChatService service = buildService(client);
      final TippyChatResult actual = await service.sendMessage(
        messages: const <TippyChatMessage>[
          TippyChatMessage(role: 'user', content: 'hi'),
        ],
      );
      expect(actual.message, 'Here is the answer.');
    });

    test('handles missing fields without crash', () async {
      final MockClient client = MockClient((http.Request request) async {
        return http.Response(
          '{"success":true,"data":{},"requestId":"req_2"}',
          200,
        );
      });
      final TippyChatService service = buildService(client);
      expect(
        () => service.sendMessage(
          messages: const <TippyChatMessage>[
            TippyChatMessage(role: 'user', content: 'hi'),
          ],
        ),
        throwsA(isA<TippyChatException>()),
      );
    });

    test('handles malformed JSON safely', () async {
      final MockClient client = MockClient((http.Request request) async {
        return http.Response('not-json', 500);
      });
      final TippyChatService service = buildService(client);
      try {
        await service.sendMessage(
          messages: const <TippyChatMessage>[
            TippyChatMessage(role: 'user', content: 'hi'),
          ],
        );
        fail('Expected TippyChatException');
      } on TippyChatException catch (err) {
        expect(err.code, 'INTERNAL_ERROR');
      }
    });

    test('maps unexpected error code to UNKNOWN_BACKEND_ERROR', () async {
      final MockClient client = MockClient((http.Request request) async {
        return http.Response(
          '{"success":false,"error":{"code":"SOMETHING_NEW","message":"Nope","status":418,"retryable":false},"requestId":"req_3"}',
          418,
        );
      });
      final TippyChatService service = buildService(client);
      try {
        await service.sendMessage(
          messages: const <TippyChatMessage>[
            TippyChatMessage(role: 'user', content: 'hi'),
          ],
        );
        fail('Expected TippyChatException');
      } on TippyChatException catch (err) {
        expect(err.code, 'UNKNOWN_BACKEND_ERROR');
        expect(err.requestId, 'req_3');
      }
    });

    test('handles credits response parsing', () async {
      final MockClient client = MockClient((http.Request request) async {
        return http.Response(
          '{"success":true,"data":{"greeting":"Welcome"},"credits":{"remaining":12,"used":3,"limit":250,"tier":"studio"},"requestId":"req_4"}',
          200,
        );
      });
      final TippyChatService service = buildService(client);
      final TippyCreditsInfo actual = await service.fetchCreditsInfo();
      expect(actual.greeting, 'Welcome');
      expect(actual.creditsRemaining, 12);
      expect(actual.tier, 'studio');
    });

    test('caption success updates cached credits', () async {
      var callCount = 0;
      final MockClient client = MockClient((http.Request request) async {
        callCount += 1;
        if (callCount == 1) {
          return http.Response(
            '{"success":true,"data":{"greeting":"Welcome"},"credits":{"remaining":12,"used":3,"limit":250,"tier":"studio"},"requestId":"req_4"}',
            200,
          );
        }
        return http.Response(
          '{"success":true,"data":{"caption":"Ship it"},"credits":{"remaining":11,"used":4,"limit":250,"tier":"studio"},"requestId":"req_5"}',
          200,
        );
      });
      final TippyChatService service = buildService(client);
      await service.fetchCreditsInfo();
      final TippyCaptionResult caption = await service.createCaption(
        prompt: 'launch day',
      );
      final TippyCreditsInfo cached = await service.fetchCreditsInfo();
      expect(caption.creditsRemaining, 11);
      expect(cached.creditsRemaining, 11);
      expect(callCount, 2);
    });

    test('analyze content success updates cached credits', () async {
      var callCount = 0;
      final MockClient client = MockClient((http.Request request) async {
        callCount += 1;
        if (callCount == 1) {
          return http.Response(
            '{"success":true,"data":{"greeting":"Welcome"},"credits":{"remaining":8,"used":2,"limit":100,"tier":"pro"},"requestId":"req_6"}',
            200,
          );
        }
        return http.Response(
          '{"success":true,"data":{"summary":"Good","actionItems":["Tighten hook"]},"credits":{"remaining":7,"used":3,"limit":100,"tier":"pro"},"requestId":"req_7"}',
          200,
        );
      });
      final TippyChatService service = buildService(client);
      await service.fetchCreditsInfo();
      final TippyAnalyzeContentResult analysis =
          await service.analyzeContent(content: 'draft');
      final TippyCreditsInfo cached = await service.fetchCreditsInfo();
      expect(analysis.creditsRemaining, 7);
      expect(cached.creditsRemaining, 7);
      expect(callCount, 2);
    });

    test('maps timeout to retryable network exception', () async {
      final MockClient client = MockClient((http.Request request) async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        return http.Response('{}', 200);
      });
      final TippyChatService service = buildService(
        client,
        timeout: const Duration(milliseconds: 50),
      );
      try {
        await service.sendMessage(
          messages: const <TippyChatMessage>[
            TippyChatMessage(role: 'user', content: 'hi'),
          ],
        );
        fail('Expected TippyNetworkException');
      } on TippyNetworkException catch (err) {
        expect(err.retryable, isTrue);
      }
    });

    test('maps missing App Check readiness to retryable verification error',
        () async {
      final MockClient client = MockClient((http.Request request) async {
        fail('Expected App Check preflight to block the request');
      });
      final TippyChatService service = TippyChatService(
        apiBase: 'https://staging.example.com',
        httpClient: client,
        tokenProvider: () async => 'token_123',
        appCheckReadinessProvider: ({bool forceRefresh = false}) async =>
            const AppCheckReadiness(isReady: false, detail: 'missing'),
        requestTimeout: const Duration(seconds: 1),
      );

      try {
        await service.sendMessage(
          messages: const <TippyChatMessage>[
            TippyChatMessage(role: 'user', content: 'hi'),
          ],
        );
        fail('Expected TippyChatException');
      } on TippyChatException catch (err) {
        expect(err.code, 'APP_CHECK_REQUIRED');
        expect(err.status, 401);
        expect(err.retryable, isTrue);
      }
    });
  });
}
