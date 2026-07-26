import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/current_user_provider.dart';
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
/// Always listens while authenticated so Home Progression, Tippy, and Academy
/// match website Mission Control (`users/{uid}/gamification/state`).
/// Do not gate this behind a mount-only flag — that previously forced Level 1
/// fallback forever because [ProgressionSubscriptionScope] was never mounted.
final StreamProvider<UserProgressBundle> userProgressBundleProvider =
    StreamProvider<UserProgressBundle>((Ref ref) {
  final AsyncValue<String?> authUid = ref.watch(authUserIdStreamProvider);
  final String? uid = authUid.valueOrNull;
  if (uid == null || uid.isEmpty) {
    return Stream<UserProgressBundle>.value(UserProgressBundle.fallback());
  }
  return ref.watch(gamificationRepositoryProvider).watchProgressBundle(uid);
});
