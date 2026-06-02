import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
final StreamProvider<UserProgressBundle> userProgressBundleProvider =
    StreamProvider<UserProgressBundle>((Ref ref) {
  final User? user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    return Stream<UserProgressBundle>.value(UserProgressBundle.fallback());
  }
  return ref
      .watch(gamificationRepositoryProvider)
      .watchProgressBundle(user.uid);
});
