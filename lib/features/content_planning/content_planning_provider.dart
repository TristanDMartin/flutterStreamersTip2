import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'content_planning_models.dart';
import 'content_planning_repository.dart';

final Provider<ContentPlanningRepository> contentPlanningRepositoryProvider =
    Provider<ContentPlanningRepository>((Ref ref) {
  return FirestoreContentPlanningRepository();
});

final StreamProvider<List<ContentPlan>> contentPlansProvider =
    StreamProvider<List<ContentPlan>>((Ref ref) async* {
  final User? user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw const ContentPlanningException('Authentication required.');
  }
  final ContentPlanningRepository repository =
      ref.watch(contentPlanningRepositoryProvider);
  await for (final List<ContentPlan> plans
      in repository.watchPlans(userId: user.uid)) {
    yield plans;
  }
});
