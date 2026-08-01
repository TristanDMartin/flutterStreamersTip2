import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/approvals/approval_queue_contract.dart';

void main() {
  group('approval deep links', () {
    test('parses query approval id from web team analytics href', () {
      expect(
        parseApprovalRequestIdFromDeepLink(
          actionUrl:
              '/dashboard/analytics?tab=team&approval=req_abc123',
        ),
        'req_abc123',
      );
    });

    test('parses /approval-review/{id}', () {
      expect(
        parseApprovalRequestIdFromDeepLink(
          actionUrl: '/approval-review/req_xyz',
        ),
        'req_xyz',
      );
    });

    test('parses workspaceId from notification actionUrl', () {
      expect(
        parseWorkspaceIdFromDeepLink(
          actionUrl:
              '/dashboard/analytics?tab=team&approval=req_1&workspaceId=owner_uid',
        ),
        'owner_uid',
      );
    });

    test('detects approval-looking notifications', () {
      expect(
        looksLikeApprovalNotification(
          actionType: 'content_approval_requested',
        ),
        isTrue,
      );
      expect(
        looksLikeApprovalNotification(
          typeName: 'WORKSPACE_APPROVAL_REQUESTED',
        ),
        isTrue,
      );
    });
  });
}
