import 'store_product_ids.dart';

/// Body for POST `/api/billing/apple/verify` or `/api/billing/google/verify`,
/// or legacy Cloud Function `verifyMobilePurchase`.
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

  bool get isIos => platform == 'ios';

  /// Website API (Pricing v2 mobile billing spec).
  Map<String, dynamic> toSiteApiJson() {
    if (isIos) {
      return <String, dynamic>{
        'signedTransactionInfo': purchaseToken,
        if (transactionId.isNotEmpty) 'transactionId': transactionId,
        'productId': productId,
      };
    }
    return <String, dynamic>{
      'purchaseToken': purchaseToken,
      'subscriptionId': googlePlaySubscriptionIdForProduct(productId),
      'productId': productId,
    };
  }

  /// Legacy Firebase HTTPS function — unchanged contract.
  Map<String, dynamic> toLegacyCloudFunctionJson() => <String, dynamic>{
        'uid': uid,
        'platform': platform,
        'productId': productId,
        'purchaseToken': purchaseToken,
        'transactionId': transactionId,
      };
}
