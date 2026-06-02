import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gamification/models/subscription_plan.dart';
import 'get_user_tier.dart';

/// Live canonical billing tier from `users/{uid}` (subscriptionTier + status).
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
                snap.data() ?? <String, dynamic>{}),
      );
});

/// API tier string (`starter` | `pro` | `studio`) for feature gates.
final Provider<String> resolvedBillingTierProvider =
    Provider<String>((Ref ref) {
  final BillingTierAccess access =
      ref.watch(billingTierAccessProvider).valueOrNull ??
          BillingTierAccess.fallbackLegacy();
  if (access.usedCanonicalFields) {
    return subscriptionPlanToApiValue(access.effectivePlan);
  }
  return 'starter';
});
