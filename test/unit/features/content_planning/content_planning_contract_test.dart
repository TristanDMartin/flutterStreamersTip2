import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/content_planning/content_planning_contract.dart';

void main() {
  group('contentPlanningContract v1', () {
    test('exposes a version', () {
      expect(kContentPlanningContractVersion, '1.1.0');
    });

    test('normalizes legacy Flutter and website statuses', () {
      expect(normalizeContentItemStatus('posted'), 'published');
      expect(normalizeContentItemStatus('needsReview'), 'ready_for_review');
      expect(normalizeContentItemStatus('planned'), 'draft');
      expect(normalizeContentItemStatus('recording'), 'in_progress');
      expect(normalizeContentItemStatus('editing'), 'in_progress');
      expect(normalizeContentItemStatus('completed'), 'completed');
      expect(normalizeContentItemStatus('done'), 'completed');
      expect(normalizeContentItemStatus('repurpose'), 'archived');
      expect(normalizeContentItemStatus('canceled'), 'cancelled');
    });

    test('keeps canonical statuses unchanged', () {
      for (final String status in kContentItemStatuses) {
        expect(normalizeContentItemStatus(status), status);
      }
    });

    test('normalizes content types and sources', () {
      expect(normalizeContentItemType('livestream'), 'stream');
      expect(normalizeContentItemType('vod'), 'video');
      expect(normalizeContentSource('app'), 'flutter');
      expect(normalizeContentSource('tippy_ai'), 'tippy');
    });

    test('maps visibility helpers both ways', () {
      expect(
        visibilityFromProfileFields(
          profileCalendar: 'public',
          streamerCalendar: null,
        ),
        'public',
      );
      expect(
        profileFieldsFromVisibility('team'),
        (profileCalendar: 'private', streamerCalendar: 'off'),
      );
    });

    test('builds Phase 3 stable link ids', () {
      expect(
        contentItemIdForScheduledPost('scheduled_1'),
        'sp_scheduled_1',
      );
      expect(
        publishJobIdForScheduledPost('scheduled_1'),
        'pj_scheduled_1',
      );
      expect(
        publishIdempotencyKey('uid1', 'scheduled_1'),
        'publish:uid1:scheduled_1',
      );
    });
  });
}
