import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/billing/mobile_purchase_verification_payload.dart';

void main() {
  group('MobilePurchaseVerificationPayload', () {
    test('site API Apple body uses signedTransactionInfo', () {
      const MobilePurchaseVerificationPayload payload =
          MobilePurchaseVerificationPayload(
        uid: 'uid-1',
        platform: 'ios',
        productId: 'creator_pro_monthly',
        purchaseToken: 'jws-token',
        transactionId: 'tx-9',
      );
      expect(payload.toSiteApiJson(), <String, dynamic>{
        'signedTransactionInfo': 'jws-token',
        'transactionId': 'tx-9',
        'productId': 'creator_pro_monthly',
      });
    });

    test('site API Google body includes subscriptionId', () {
      const MobilePurchaseVerificationPayload payload =
          MobilePurchaseVerificationPayload(
        uid: 'uid-1',
        platform: 'android',
        productId: 'creator_pro_monthly',
        purchaseToken: 'play-token',
        transactionId: 'tx-1',
      );
      expect(payload.toSiteApiJson(), <String, dynamic>{
        'purchaseToken': 'play-token',
        'subscriptionId': 'creator_pro',
        'productId': 'creator_pro_monthly',
      });
    });

    test('legacy Cloud Function body unchanged', () {
      const MobilePurchaseVerificationPayload payload =
          MobilePurchaseVerificationPayload(
        uid: 'uid-1',
        platform: 'ios',
        productId: 'streamerstip_pro_monthly',
        purchaseToken: 'token-abc',
        transactionId: 'tx-9',
      );
      expect(payload.toLegacyCloudFunctionJson(), <String, dynamic>{
        'uid': 'uid-1',
        'platform': 'ios',
        'productId': 'streamerstip_pro_monthly',
        'purchaseToken': 'token-abc',
        'transactionId': 'tx-9',
      });
    });
  });
}
