import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:streamers_tip/features/tippy/tippy_chat_service.dart';

void main() {
  group('TippyChatService', () {
    TippyChatService buildService(MockClient client, {Duration? timeout}) {
      return TippyChatService(
        apiBase: 'https://staging.example.com',
        httpClient: client,
        tokenProvider: () async => 'token_123',
        requestTimeout: timeout ?? const Duration(seconds: 1),
      );
    }

    test('parses valid success response', () async {
      Uri? sent;
      final MockClient client = MockClient((http.Request request) async {
        sent = request.url;
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
      expect(sent?.path, '/api/tippy/chat');
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
      Uri? sent;
      final MockClient client = MockClient((http.Request request) async {
        sent = request.url;
        expect(request.url.path, '/api/tippy/credits');
        return http.Response(
          '{"creditsRemaining":18,"creditsLimit":250,"tier":"pro"}',
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });
      final TippyChatService service = buildService(client);
      final TippyCreditsInfo actual = await service.fetchCreditsInfo();
      expect(actual.greeting, 'Hey creator, what are we building today?');
      expect(actual.creditsRemaining, 18);
      expect(actual.tier, 'pro');
      expect(sent?.path, '/api/tippy/credits');
    });

    test('does not cache a failed credits response', () async {
      var callCount = 0;
      final MockClient client = MockClient((http.Request request) async {
        callCount += 1;
        if (callCount == 1) {
          return http.Response('{"error":"Failed to fetch credits"}', 500);
        }
        return http.Response(
          '{"creditsRemaining":9,"tier":"pro"}',
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });
      final TippyChatService service = buildService(client);
      final TippyCreditsInfo first = await service.fetchCreditsInfo();
      final TippyCreditsInfo second = await service.fetchCreditsInfo();
      expect(first.creditsRemaining, isNull);
      expect(second.creditsRemaining, 9);
      expect(callCount, 2);
    });

    test('fetchContext reads creator memory from the site API', () async {
      Uri? sent;
      final MockClient client = MockClient((http.Request request) async {
        sent = request.url;
        return http.Response(
          '{"success":true,"memory":{"identity":{"niche":"IRL"},"goals":{"goalIds":["grow"]}}}',
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });
      final TippyChatService service = buildService(client);
      final TippyContextSnapshot actual = await service.fetchContext();
      expect(actual.memoryReady, isTrue);
      expect(actual.ui.contextStrip.nicheLabel, 'IRL');
      expect(sent?.path, '/api/tippy/creator-memory');
    });

    test('caption success updates cached credits', () async {
      var callCount = 0;
      final MockClient client = MockClient((http.Request request) async {
        if (request.url.path.contains('/api/tippy/credits')) {
          return http.Response(
            '{"creditsRemaining":99,"tier":"pro"}',
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }
        callCount += 1;
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
      expect(callCount, 1);
    });

    test('analyze content success updates cached credits', () async {
      var callCount = 0;
      final MockClient client = MockClient((http.Request request) async {
        if (request.url.path.contains('/api/tippy/credits')) {
          return http.Response(
            '{"creditsRemaining":99,"tier":"pro"}',
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }
        callCount += 1;
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
      expect(callCount, 1);
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

    test('createPlan does not call legacy /tippy/create-plan', () async {
      var called = false;
      final MockClient client = MockClient((http.Request request) async {
        called = true;
        return http.Response('{}', 200);
      });
      final TippyChatService service = buildService(client);
      await expectLater(
        service.createPlan(
          messages: const <TippyChatMessage>[
            TippyChatMessage(role: 'user', content: 'plan'),
          ],
        ),
        throwsA(isA<TippyChatException>()),
      );
      expect(called, isFalse);
    });

    test('proposeSchedule and approveScheduleProposal do not call legacy paths',
        () async {
      var called = false;
      final MockClient client = MockClient((http.Request request) async {
        called = true;
        return http.Response('{}', 200);
      });
      final TippyChatService service = buildService(client);
      await expectLater(
        service.proposeSchedule(prompt: 'slots'),
        throwsA(isA<TippyChatException>()),
      );
      await expectLater(
        service.approveScheduleProposal(proposalId: 'p1'),
        throwsA(isA<TippyChatException>()),
      );
      expect(called, isFalse);
    });
  });
}
