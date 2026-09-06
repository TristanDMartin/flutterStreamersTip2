import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/onboarding/authenticated_app_shell_ready.dart';
import '../../providers/current_user_provider.dart';
import './achievements/achievement_definition.dart';
import './achievements/achievement_repository.dart';
import 'data/gamification_repository.dart';
import 'models/user_progress_bundle.dart';
import 'services/gamification_event_service.dart';

final Provider<GamificationRepository> gamificationRepositoryProvider =
    Provider<GamificationRepository>(
  (Ref ref) => GamificationRepository(FirebaseFirestore.instance),
);

/// Default uses the Cloudflare Worker. Override `baseUrl` only if using optional Firebase HTTPS.
final Provider<GamificationEventService> gamificationEventServiceProvider =
    Provider<GamificationEventService>(
  (Ref ref) => GamificationEventService(),
);

/// Live progression + missions + tier snapshot for the signed-in user.
///
/// Phase 1J.5: listen only after ACTIVATED / app-shell boot. During Tippy
/// onboarding this stays on fallback so Firestore gamification is not hydrated.
final StreamProvider<UserProgressBundle> userProgressBundleProvider =
    StreamProvider<UserProgressBundle>((Ref ref) {
  final bool shellReady = ref.watch(authenticatedAppShellReadyProvider);
  final AsyncValue<String?> authUid = ref.watch(authUserIdStreamProvider);
  final String? uid = authUid.valueOrNull;
  if (!shellReady || uid == null || uid.isEmpty) {
    return Stream<UserProgressBundle>.value(UserProgressBundle.fallback());
  }
  return ref.watch(gamificationRepositoryProvider).watchProgressBundle(uid);
});

final Provider<AchievementRepository> achievementRepositoryProvider =
    Provider<AchievementRepository>(
  (Ref ref) => AchievementRepository(),
);

final StreamProvider<AchievementSnapshot> achievementSnapshotProvider =
    StreamProvider<AchievementSnapshot>((Ref ref) {
  final bool shellReady = ref.watch(authenticatedAppShellReadyProvider);
  final AsyncValue<String?> authUid = ref.watch(authUserIdStreamProvider);
  final String? uid = authUid.valueOrNull;
  if (!shellReady || uid == null || uid.isEmpty) {
    return Stream<AchievementSnapshot>.value(AchievementSnapshot.empty);
  }
  return ref.watch(achievementRepositoryProvider).watch(uid);
});
