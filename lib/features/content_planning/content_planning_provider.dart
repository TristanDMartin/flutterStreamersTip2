import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/onboarding/onboarding_mission_actions.dart';
import 'content_planning_models.dart';
import 'content_planning_repository.dart';

final Provider<ContentPlanningRepository> contentPlanningRepositoryProvider =
    Provider<ContentPlanningRepository>((Ref ref) {
  return FirestoreContentPlanningRepository();
});

final FutureProvider<List<ContentPlan>> contentPlansProvider =
    FutureProvider<List<ContentPlan>>((Ref ref) async {
  final User? user = FirebaseAuth.instance.currentUser;
  final String? token = await user?.getIdToken(false);
  if (user == null || token == null || token.isEmpty) {
    throw const ContentPlanningException('Authentication required.');
  }
  final ContentPlanningRepository repository =
      ref.watch(contentPlanningRepositoryProvider);
  final plans = await repository.listPlans(idToken: token, userId: user.uid);
  if (plans.isNotEmpty) {
    await OnboardingMissionActions.complete(user.uid, 'create_content_plan');
  }
  return plans;
});
