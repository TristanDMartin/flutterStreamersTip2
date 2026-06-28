import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/billing/mobile_purchase_verification_payload.dart';
import 'package:streamers_tip/features/billing/store_product_ids.dart';

void main() {
  group('MobilePurchaseVerificationPayload', () {
    test('site API Apple body uses signedTransactionInfo', () {
      const MobilePurchaseVerificationPayload payload =
          MobilePurchaseVerificationPayload(
        uid: 'uid-1',
        platform: 'ios',
        productId: kIosProMonthlyId,
        purchaseToken: 'jws-token',
        transactionId: 'tx-9',
      );
      expect(payload.toSiteApiJson(), <String, dynamic>{
        'signedTransactionInfo': 'jws-token',
        'transactionId': 'tx-9',
        'productId': kIosProMonthlyId,
      });
    });

    test('site API Google body includes subscriptionId', () {
      const MobilePurchaseVerificationPayload payload =
          MobilePurchaseVerificationPayload(
        uid: 'uid-1',
        platform: 'android',
        productId: kAndroidProMonthlyId,
        purchaseToken: 'play-token',
        transactionId: 'tx-1',
      );
      expect(payload.toSiteApiJson(), <String, dynamic>{
        'purchaseToken': 'play-token',
        'subscriptionId': 'streamerstip_pro',
        'productId': kAndroidProMonthlyId,
      });
    });

    test('legacy Cloud Function body unchanged', () {
      const MobilePurchaseVerificationPayload payload =
          MobilePurchaseVerificationPayload(
        uid: 'uid-1',
        platform: 'ios',
        productId: kLegacyProMonthlyId,
        purchaseToken: 'token-abc',
        transactionId: 'tx-9',
      );
      expect(payload.toLegacyCloudFunctionJson(), <String, dynamic>{
        'uid': 'uid-1',
        'platform': 'ios',
        'productId': kLegacyProMonthlyId,
        'purchaseToken': 'token-abc',
        'transactionId': 'tx-9',
      });
    });
  });
}
