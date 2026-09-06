import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:streamers_tip/features/gamification/achievements/achievement_repository.dart';
import 'package:streamers_tip/features/gamification/achievements/acknowledge_result.dart';

void main() {
  group('AchievementRepository.acknowledge', () {
    test('returns success on 2xx', () async {
      final MockClient client = MockClient((http.Request request) async {
        expect(request.method, 'PATCH');
        expect(
          request.url.path,
          '/gamification/achievements/first_video/acknowledge',
        );
        return http.Response('{"ok":true}', 200);
      });
      final AchievementRepository repo = AchievementRepository(
        httpClient: client,
        baseUrl: 'https://example.test',
        readIdToken: () async => 'token',
      );
      final AchievementAcknowledgeResult actual =
          await repo.acknowledge('first_video');
      expect(actual, isA<AchievementAcknowledgeSuccess>());
    });

    test('maps 401 to session-expired product copy', () async {
      final MockClient client = MockClient((http.Request request) async {
        return http.Response(
          '{"error":"Unauthorized","stack":"do-not-surface"}',
          401,
        );
      });
      final AchievementRepository repo = AchievementRepository(
        httpClient: client,
        baseUrl: 'https://example.test',
        readIdToken: () async => 'token',
      );
      final AchievementAcknowledgeResult actual =
          await repo.acknowledge('first_video');
      expect(actual, isA<AchievementAcknowledgeFailure>());
      final AchievementAcknowledgeFailure failure =
          actual as AchievementAcknowledgeFailure;
      expect(failure.isSessionExpired, isTrue);
      expect(failure.userMessage, kAchievementSessionExpiredMessage);
    });

    test('maps other failures to generic retry copy', () async {
      final MockClient client = MockClient((http.Request request) async {
        return http.Response('{"error":"WORKER_INTERNAL"}', 500);
      });
      final AchievementRepository repo = AchievementRepository(
        httpClient: client,
        baseUrl: 'https://example.test',
        readIdToken: () async => 'token',
      );
      final AchievementAcknowledgeResult actual =
          await repo.acknowledge('first_video');
      final AchievementAcknowledgeFailure failure =
          actual as AchievementAcknowledgeFailure;
      expect(failure.isSessionExpired, isFalse);
      expect(failure.userMessage, kAchievementGenericRetryMessage);
    });

    test('missing auth token is session-expired and does not PATCH', () async {
      bool didPatch = false;
      final MockClient client = MockClient((http.Request request) async {
        didPatch = true;
        return http.Response('{"ok":true}', 200);
      });
      final AchievementRepository repo = AchievementRepository(
        httpClient: client,
        baseUrl: 'https://example.test',
        readIdToken: () async => null,
      );
      final AchievementAcknowledgeResult actual =
          await repo.acknowledge('first_video');
      expect(didPatch, isFalse);
      expect(
        (actual as AchievementAcknowledgeFailure).isSessionExpired,
        isTrue,
      );
    });
  });
}
