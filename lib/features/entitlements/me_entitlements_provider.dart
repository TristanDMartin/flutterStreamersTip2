import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/me_entitlements_service.dart';
import 'me_entitlements_models.dart';

final Provider<MeEntitlementsService> meEntitlementsServiceProvider =
    Provider<MeEntitlementsService>(
  (Ref ref) {
    return MeEntitlementsService();
  },
);

/// Refetch entitlements when auth session changes (login, logout, token).
final StreamProvider<User?> meEntitlementsAuthUserProvider =
    StreamProvider<User?>(
  (Ref ref) => FirebaseAuth.instance.authStateChanges(),
);

final AutoDisposeFutureProvider<MeEntitlementsData> meEntitlementsProvider =
    FutureProvider.autoDispose<MeEntitlementsData>(
  (Ref ref) async {
    ref.watch(meEntitlementsAuthUserProvider);
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Not signed in');
    }
    return ref.read(meEntitlementsServiceProvider).fetchCurrentUserEntitlements();
  },
);
