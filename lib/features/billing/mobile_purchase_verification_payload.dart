/// Payload sent to your backend after a store purchase succeeds locally.
///
/// Server must validate with Apple/Google before writing entitlements.
class MobilePurchaseVerificationPayload {
  const MobilePurchaseVerificationPayload({
    required this.uid,
    required this.platform,
    required this.productId,
    required this.purchaseToken,
    required this.transactionId,
  });

  final String uid;
  final String platform;
  final String productId;
  final String purchaseToken;
  final String transactionId;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'uid': uid,
        'platform': platform,
        'productId': productId,
        'purchaseToken': purchaseToken,
        'transactionId': transactionId,
      };
}
