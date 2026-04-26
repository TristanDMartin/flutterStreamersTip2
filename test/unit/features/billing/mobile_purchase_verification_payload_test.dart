import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/billing/mobile_purchase_verification_payload.dart';

void main() {
  test('MobilePurchaseVerificationPayload serializes for backend', () {
    const MobilePurchaseVerificationPayload payload =
        MobilePurchaseVerificationPayload(
      uid: 'uid-1',
      platform: 'ios',
      productId: 'streamerstip_pro_monthly',
      purchaseToken: 'token-abc',
      transactionId: 'tx-9',
    );
    expect(payload.toJson(), <String, dynamic>{
      'uid': 'uid-1',
      'platform': 'ios',
      'productId': 'streamerstip_pro_monthly',
      'purchaseToken': 'token-abc',
      'transactionId': 'tx-9',
    });
  });
}
