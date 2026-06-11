import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'get_user_tier.dart';
import 'models/billing_tier.dart';
import 'models/subscription_snapshot.dart';
import 'subscription_provider.dart';

/// Firestore tier — badge/display only. Do not use for paid feature gates.
final StreamProvider<BillingTierAccess> billingTierAccessProvider =
    StreamProvider<BillingTierAccess>((Ref ref) {
  final User? user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    return Stream<BillingTierAccess>.value(BillingTierAccess.fallbackLegacy());
  }
  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map(
        (DocumentSnapshot<Map<String, dynamic>> snap) =>
            BillingTierAccess.fromUserDocument(
          snap.data() ?? <String, dynamic>{},
        ),
      );
});

/// Effective tier from `/api/user/entitlements` (not Firestore alone).
final Provider<String> resolvedBillingTierProvider =
    Provider<String>((Ref ref) {
  final SubscriptionSnapshot? cached =
      ref.read(subscriptionRepositoryProvider).peekCached();
  final SubscriptionSnapshot? snap =
      ref.watch(subscriptionSnapshotProvider).valueOrNull ?? cached;
  if (snap != null) {
    return snap.tierApi;
  }
  return billingTierToApiValue(BillingTier.starter);
});
