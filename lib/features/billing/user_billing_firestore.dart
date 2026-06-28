import 'package:cloud_firestore/cloud_firestore.dart';

const String kUserBillingSubscriptionDocId = 'subscription';

DocumentReference<Map<String, dynamic>> userBillingSubscriptionRef(
  FirebaseFirestore firestore,
  String uid,
) {
  return firestore
      .collection('users')
      .doc(uid)
      .collection('billing')
      .doc(kUserBillingSubscriptionDocId);
}

/// Merges owner-only billing fields into a public user document map.
Map<String, dynamic> mergeUserDocWithBillingSubscription(
  Map<String, dynamic> userDoc,
  Map<String, dynamic>? billingDoc,
) {
  if (billingDoc == null || billingDoc.isEmpty) {
    return Map<String, dynamic>.from(userDoc);
  }
  final Map<String, dynamic> merged = Map<String, dynamic>.from(userDoc);
  const List<String> billingKeys = <String>[
    'tier',
    'subscriptionTier',
    'effectiveTier',
    'subscriptionStatus',
    'billingProvider',
    'planProductId',
    'currentPeriodEnd',
    'trialEndsAt',
    'subscriptionTrialEndAt',
    'entitlements',
    'subscription',
  ];
  for (final String key in billingKeys) {
    if (billingDoc.containsKey(key)) {
      merged[key] = billingDoc[key];
    }
  }
  return merged;
}

Future<Map<String, dynamic>?> readBillingSubscriptionForUid(
  FirebaseFirestore firestore,
  String uid,
) async {
  final DocumentSnapshot<Map<String, dynamic>> snap =
      await userBillingSubscriptionRef(firestore, uid).get();
  if (!snap.exists || snap.data() == null) {
    return null;
  }
  return snap.data();
}
