import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/services/account_deletion_service.dart';

void main() {
  group('canonical account delete contract', () {
    test('requires ok true, not a bare HTTP 200', () {
      expect(
        isCanonicalAccountDeleteSuccess(
          statusCode: 200,
          body: <String, dynamic>{},
        ),
        isFalse,
      );
      expect(
        isCanonicalAccountDeleteSuccess(
          statusCode: 200,
          body: <String, dynamic>{'ok': true, 'deletedAuth': true},
        ),
        isTrue,
      );
      expect(
        isCanonicalAccountDeleteSuccess(
          statusCode: 200,
          body: <String, dynamic>{'alreadyDeleted': true},
        ),
        isTrue,
      );
    });

    test('unwraps nested Cloud Function payloads', () {
      expect(
        isCanonicalAccountDeleteSuccess(
          statusCode: 200,
          body: <String, dynamic>{
            'result': <String, dynamic>{
              'ok': true,
              'deletedAuth': true,
            },
          },
        ),
        isTrue,
      );
    });

    test('retries the same statuses as web account POST', () {
      expect(isRetryableAccountDeleteStatus(404), isTrue);
      expect(isRetryableAccountDeleteStatus(502), isTrue);
      expect(isRetryableAccountDeleteStatus(503), isTrue);
      expect(isRetryableAccountDeleteStatus(401), isFalse);
      expect(isRetryableAccountDeleteStatus(400), isFalse);
      expect(isRetryableAccountDeleteStatus(500), isFalse);
    });

    test('surfaces server confirmation errors', () {
      expect(
        accountDeleteErrorMessage(
          statusCode: 400,
          body: <String, dynamic>{
            'ok': false,
            'code': 'CONFIRMATION_REQUIRED',
            'message': 'Type DELETE to confirm account deletion.',
          },
        ),
        'Type DELETE to confirm account deletion.',
      );
    });
  });
}
