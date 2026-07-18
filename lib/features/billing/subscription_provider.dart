import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../utils/auth_transition_flutter_errors.dart';
import 'models/subscription_snapshot.dart';
import 'subscription_repository.dart';

final Provider<SubscriptionRepository> subscriptionRepositoryProvider =
    Provider<SubscriptionRepository>(
  (Ref ref) {
    final SubscriptionRepository repo = SubscriptionRepository();
    ref.onDispose(repo.dispose);
    return repo;
  },
);

final StreamProvider<User?> subscriptionAuthUserProvider =
    StreamProvider<User?>(
  (Ref ref) => FirebaseAuth.instance.authStateChanges(),
);

/// Canonical entitlements for the signed-in user (`/api/user/entitlements`).
final AutoDisposeFutureProvider<SubscriptionSnapshot>
    subscriptionSnapshotProvider =
    FutureProvider.autoDispose<SubscriptionSnapshot>(
  (Ref ref) async {
    ref.watch(subscriptionAuthUserProvider);
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Not signed in');
    }
    return ref
        .read(subscriptionRepositoryProvider)
        .fetchEntitlements();
  },
);

/// Refreshes after checkout, AI usage, pull-to-refresh, or app resume.
Future<SubscriptionSnapshot> refreshSubscriptionEntitlements(
  WidgetRef ref, {
  bool forceRefresh = true,
}) async {
  if (forceRefresh) {
    ref.read(subscriptionRepositoryProvider).invalidateCache();
  }
  ref.invalidate(subscriptionSnapshotProvider);
  return ref.read(subscriptionSnapshotProvider.future);
}

void invalidateSubscriptionEntitlements(WidgetRef ref) {
  try {
    ref.read(subscriptionRepositoryProvider).invalidateCache();
    ref.invalidate(subscriptionSnapshotProvider);
  } catch (error) {
    if (isIgnorableAuthTransitionFlutterError(error)) {
      return;
    }
    rethrow;
  }
}

/// Sync read of last successful fetch (may be null before first load).
SubscriptionSnapshot? readCachedSubscriptionSnapshot(WidgetRef ref) {
  return ref.read(subscriptionRepositoryProvider).peekCached();
}
