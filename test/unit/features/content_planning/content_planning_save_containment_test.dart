import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/content_planning/content_planning_models.dart';
import 'package:streamers_tip/features/content_planning/content_planning_repository.dart';

import '../../../test_support/firebase_test_setup.dart';

void main() {
  setUpAll(() async {
    await setupFirebaseForTests();
  });

  test('Firestore updatePlan does not write items[]', () async {
    final FirestoreContentPlanningRepository repository =
        FirestoreContentPlanningRepository();
    final ContentPlan plan = ContentPlan(
      id: 'plan-1',
      title: 'First week: IRL',
      userId: 'uid-1',
      itemCount: 1,
      items: const <ContentPlanItem>[
        ContentPlanItem(id: 'item-1', title: 'Behind the scenes — IRL'),
      ],
    );
    await expectLater(
      repository.updatePlan(userId: 'uid-1', plan: plan),
      throwsA(
        isA<ContentPlanningException>().having(
          (ContentPlanningException e) => e.message,
          'message',
          contains('Direct plan saves are disabled'),
        ),
      ),
    );
  });

  test('toFirestoreMap drops canonical item fields not in the client model', () {
    final Map<String, dynamic> written = const ContentPlanItem(
      id: 'item-1',
      title: 'Behind the scenes — IRL',
      status: 'scheduled',
      type: 'post',
    ).toFirestoreMap();
    expect(written.containsKey('createdAt'), isFalse);
    expect(written.containsKey('updatedAt'), isFalse);
    expect(written.containsKey('scheduledFor'), isFalse);
    expect(written.containsKey('source'), isFalse);
  });
}
