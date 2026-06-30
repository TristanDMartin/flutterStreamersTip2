'use strict';

const {GoogleAuth} = require('google-auth-library');

const ANDROID_PUBLISHER_SCOPE =
  'https://www.googleapis.com/auth/androidpublisher';
const DEFAULT_ANDROID_PACKAGE_NAME = 'com.streamerstip.streamersTipApp';

function defaultAndroidPackageName() {
  return (
    process.env.GOOGLE_PLAY_PACKAGE_NAME ||
    process.env.ANDROID_PACKAGE_NAME ||
    DEFAULT_ANDROID_PACKAGE_NAME
  );
}

async function androidPublisherGet(path) {
  const auth = new GoogleAuth({scopes: [ANDROID_PUBLISHER_SCOPE]});
  const client = await auth.getClient();
  const url = `https://androidpublisher.googleapis.com/androidpublisher/v3/${path}`;
  const response = await client.request({url, method: 'GET'});
  return response.data || {};
}

function parseMillis(value) {
  const parsed = parseInt(String(value || '0'), 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : 0;
}

async function verifyGooglePlaySubscription(
    packageName,
    productId,
    purchaseToken,
) {
  const encodedProductId = encodeURIComponent(productId);
  const encodedToken = encodeURIComponent(purchaseToken);
  const path =
    `applications/${encodeURIComponent(packageName)}` +
    `/purchases/subscriptions/${encodedProductId}/tokens/${encodedToken}`;
  const data = await androidPublisherGet(path);
  const expiryMs = parseMillis(data.expiryTimeMillis);
  if (!expiryMs) {
    throw new Error('Google Play subscription missing expiryTimeMillis');
  }
  const paymentState = Number(data.paymentState);
  const cancelReason = data.cancelReason;
  const isExpired = expiryMs <= Date.now();
  const isTrial = paymentState === 2;
  return {
    originalTransactionId: String(
        data.linkedPurchaseToken ||
        data.orderId ||
        purchaseToken,
    ),
    purchaseTokenStored: purchaseToken,
    currentPeriodEnd: new Date(expiryMs),
    trialEndsAt: isTrial ? new Date(expiryMs) : null,
    subscriptionStatus:
      isExpired || cancelReason === 1 ? 'expired' : isTrial ? 'trialing' : 'active',
  };
}

module.exports = {
  defaultAndroidPackageName,
  verifyGooglePlaySubscription,
};
