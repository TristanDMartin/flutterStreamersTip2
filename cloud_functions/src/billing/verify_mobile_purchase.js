'use strict';

const admin = require('firebase-admin');
const https = require('https');
const {
  SignedDataVerifier,
  Environment,
  OfferType,
} = require('@apple/app-store-server-library');
const {loadAppleRootCertificates} = require('./apple_root_cas');
const {
  assertMobilePurchaseAllowed,
  assertTransactionNotBoundToOtherUser,
  applyEntitlementDowngrade,
  buildUserEntitlementPatch,
  recordTransactionOwner,
  Timestamp,
  FieldValue,
} = require('../shared/subscription_entitlements');
const {applyEntitlementPatches, loadUserWithBilling} =
  require('../shared/user_billing_storage');
const {
  verifyGooglePlaySubscription,
  defaultAndroidPackageName,
} = require('./google_play_verify');
const {verifyAppCheckHttp} = require('../shared/verify_app_check_http');

const ALLOWED_PRODUCT_IDS = new Set([
  'streamerstip_pro_monthly_ios',
  'streamerstip_pro_yearly_ios',
  'streamerstip_studio_monthly_ios',
  'streamerstip_studio_yearly_ios',
  'streamerstip_pro_monthly_android',
  'streamerstip_pro_yearly_android',
  'streamerstip_studio_monthly_android',
  'streamerstip_studio_yearly_android',
  'creator_pro_monthly',
  'creator_pro_yearly',
  'creator_studio_monthly',
  'creator_studio_yearly',
  'streamerstip_pro_monthly',
  'streamerstip_pro_yearly',
  'streamerstip_studio_monthly',
  'streamerstip_studio_yearly',
]);

const LEGACY_PRODUCT_IDS = new Set([
  'creator_pro_monthly',
  'creator_pro_yearly',
  'creator_studio_monthly',
  'creator_studio_yearly',
  'streamerstip_pro_monthly',
  'streamerstip_pro_yearly',
  'streamerstip_studio_monthly',
  'streamerstip_studio_yearly',
]);

const DEFAULT_APPLE_BUNDLE_ID = 'com.streamerstip.streamersTipApp';

function tierFromProductId(productId) {
  if (String(productId).includes('studio')) {
    return 'studio';
  }
  return 'pro';
}

function billingProvider(platform) {
  return platform === 'ios' ? 'apple' : 'google';
}

function isProductAllowedForPlatform(productId, platform) {
  const id = String(productId || '').trim().toLowerCase();
  if (id.endsWith('_ios')) {
    return platform === 'ios';
  }
  if (id.endsWith('_android')) {
    return platform === 'android';
  }
  return LEGACY_PRODUCT_IDS.has(productId);
}

function postAppleVerifyReceipt(host, bodyObj) {
  const body = JSON.stringify(bodyObj);
  return new Promise((resolve, reject) => {
    const req = https.request(
        {
          hostname: host,
          path: '/verifyReceipt',
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Content-Length': Buffer.byteLength(body, 'utf8'),
          },
        },
        (res) => {
          let raw = '';
          res.on('data', (chunk) => {
            raw += chunk;
          });
          res.on('end', () => {
            try {
              resolve(JSON.parse(raw));
            } catch (e) {
              reject(new Error('Apple response not JSON'));
            }
          });
        },
    );
    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

async function verifyAppleReceipt(receiptData, sharedSecret, expectedProductId) {
  if (!sharedSecret) {
    throw new Error('APP_STORE_SHARED_SECRET is not configured');
  }
  const payload = {
    'receipt-data': receiptData,
    password: sharedSecret,
    'exclude-old-transactions': false,
  };
  let result = await postAppleVerifyReceipt('buy.itunes.apple.com', payload);
  if (result.status === 21007) {
    result = await postAppleVerifyReceipt('sandbox.itunes.apple.com', payload);
  }
  if (result.status !== 0) {
    throw new Error(`Apple verifyReceipt failed (status ${result.status})`);
  }
  const latest = result.latest_receipt_info;
  if (!Array.isArray(latest) || latest.length === 0) {
    throw new Error('Apple receipt has no latest_receipt_info');
  }
  const matching = latest.filter((t) => t.product_id === expectedProductId);
  if (matching.length === 0) {
    throw new Error(`Receipt has no transaction for ${expectedProductId}`);
  }
  matching.sort((a, b) => {
    const ea = parseInt(String(a.expires_date_ms || '0'), 10);
    const eb = parseInt(String(b.expires_date_ms || '0'), 10);
    return eb - ea;
  });
  const t = matching[0];
  const expiresMs = parseInt(String(t.expires_date_ms || '0'), 10);
  if (!expiresMs) {
    throw new Error('Apple transaction missing expires_date_ms');
  }
  const trial =
    t.is_trial_period === 'true' || t.is_in_intro_offer_period === 'true';
  return {
    originalTransactionId: String(t.original_transaction_id || ''),
    purchaseTokenStored: receiptData,
    currentPeriodEnd: new Date(expiresMs),
    trialEndsAt: trial ? new Date(expiresMs) : null,
    subscriptionStatus: trial ? 'trialing' : 'active',
  };
}

function looksLikeStoreKit2Jws(token) {
  const s = String(token || '');
  return s.split('.').length === 3 && s.startsWith('eyJ');
}

async function verifyAppleStoreKit2Transaction(signedTransaction, expectedProductId) {
  const bundleId = process.env.APPLE_BUNDLE_ID || DEFAULT_APPLE_BUNDLE_ID;
  const appAppleIdRaw = process.env.APP_STORE_APP_APPLE_ID || '';
  const appAppleId = appAppleIdRaw.trim()
    ? parseInt(appAppleIdRaw.trim(), 10)
    : undefined;
  const appleRootCAs = await loadAppleRootCertificates();
  const environments = [Environment.SANDBOX, Environment.PRODUCTION];
  let lastError = null;
  for (const environment of environments) {
    try {
      const verifier = new SignedDataVerifier(
          appleRootCAs,
          true,
          environment,
          bundleId,
          environment === Environment.PRODUCTION ? appAppleId : undefined,
      );
      const txn = await verifier.verifyAndDecodeTransaction(signedTransaction);
      const productId = String(txn.productId || '');
      if (productId !== expectedProductId) {
        throw new Error(
            `JWS product ${productId} does not match ${expectedProductId}`,
        );
      }
      const expiresMs = txn.expiresDate;
      if (!expiresMs) {
        throw new Error('Apple JWS transaction missing expiresDate');
      }
      const offerType = txn.offerType;
      const offerDiscount = String(txn.offerDiscountType || '').toUpperCase();
      const trial =
        offerType === OfferType.INTRODUCTORY_OFFER ||
        offerType === OfferType.SUBSCRIPTION_OFFER_CODE ||
        offerDiscount.includes('FREE_TRIAL') ||
        offerDiscount.includes('INTRODUCTORY');
      return {
        originalTransactionId: String(
            txn.originalTransactionId || txn.transactionId || '',
        ),
        purchaseTokenStored: signedTransaction,
        currentPeriodEnd: new Date(expiresMs),
        trialEndsAt: trial ? new Date(expiresMs) : null,
        subscriptionStatus: trial ? 'trialing' : 'active',
      };
    } catch (e) {
      lastError = e;
    }
  }
  throw lastError || new Error('Apple JWS verification failed');
}

async function applyVerifiedMobileGrant(uid, {
  tier,
  provider,
  productId,
  verified,
  transactionId,
  existingUser,
  existingCreatedAt,
  lifecycleReason = 'verify_mobile_purchase',
}) {
  const now = FieldValue.serverTimestamp();
  const periodEndTs = Timestamp.fromDate(verified.currentPeriodEnd);
  const trialTs = verified.trialEndsAt
    ? Timestamp.fromDate(verified.trialEndsAt)
    : null;
  await applyEntitlementPatches(uid, {
    entitlementPatch: buildUserEntitlementPatch({
      tier,
      provider,
      productId,
      verified,
      periodEndTs,
      trialTs,
      now,
      existingUser,
    }),
    subscriptionsPatch: {
      uid,
      tier,
      provider,
      status: verified.subscriptionStatus,
      productId,
      originalTransactionId: verified.originalTransactionId,
      purchaseToken: verified.purchaseTokenStored,
      transactionId: transactionId || verified.originalTransactionId,
      currentPeriodStart: now,
      currentPeriodEnd: periodEndTs,
      trialEndsAt: trialTs,
      cancelAtPeriodEnd: false,
      createdAt: existingCreatedAt || now,
      updatedAt: now,
      lastLifecycleReason: lifecycleReason,
    },
  });
  await recordTransactionOwner({
    originalTransactionId: verified.originalTransactionId,
    uid,
    provider,
    productId,
  });
}

async function handleVerifyMobilePurchase(req, res) {
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }
  if (req.method !== 'POST') {
    res.status(405).json({error: 'Method not allowed'});
    return;
  }
  try {
    let rawBody = req.body;
    if (Buffer.isBuffer(rawBody)) {
      rawBody = rawBody.toString('utf8');
    }
    const body =
      typeof rawBody === 'string' ? JSON.parse(rawBody || '{}') : (rawBody || {});
    const authHeader = req.headers.authorization || '';
    if (!authHeader.startsWith('Bearer ')) {
      res.status(401).json({error: 'Missing Authorization Bearer token'});
      return;
    }
    const idToken = authHeader.slice('Bearer '.length).trim();
    const decoded = await admin.auth().verifyIdToken(idToken);
    const appCheckResult = await verifyAppCheckHttp(req);
    if (!appCheckResult.ok) {
      res.status(appCheckResult.status).json({
        error: appCheckResult.message,
        code: appCheckResult.code,
      });
      return;
    }
    const uid = String(body.uid || '').trim();
    if (!uid || uid !== decoded.uid) {
      res.status(403).json({error: 'uid must match signed-in user'});
      return;
    }
    const platform = String(body.platform || '').toLowerCase().trim();
    const productId = String(body.productId || '').trim();
    const purchaseToken = String(body.purchaseToken || '').trim();
    const transactionId = String(body.transactionId || '').trim();
    if (!ALLOWED_PRODUCT_IDS.has(productId)) {
      res.status(400).json({error: 'Invalid productId'});
      return;
    }
    if (!isProductAllowedForPlatform(productId, platform)) {
      res.status(400).json({error: 'productId does not match platform'});
      return;
    }
    if (!purchaseToken) {
      res.status(400).json({error: 'Missing purchaseToken'});
      return;
    }
    const existingUser = await loadUserWithBilling(uid);
    assertMobilePurchaseAllowed(existingUser);

    let verified;
    if (platform === 'ios') {
      if (looksLikeStoreKit2Jws(purchaseToken)) {
        verified = await verifyAppleStoreKit2Transaction(
            purchaseToken,
            productId,
        );
      } else {
        const secret = process.env.APP_STORE_SHARED_SECRET || '';
        verified = await verifyAppleReceipt(
            purchaseToken,
            secret,
            productId,
        );
      }
    } else if (platform === 'android') {
      verified = await verifyGooglePlaySubscription(
          defaultAndroidPackageName(),
          productId,
          purchaseToken,
      );
    } else {
      res.status(400).json({error: 'platform must be ios or android'});
      return;
    }

    if (verified.subscriptionStatus === 'expired') {
      await applyEntitlementDowngrade(uid, {
        status: 'expired',
        reason: 'verify_expired',
      });
      res.status(410).json({
        ok: false,
        error: 'Subscription expired',
        subscriptionStatus: 'expired',
      });
      return;
    }

    await assertTransactionNotBoundToOtherUser(
        verified.originalTransactionId,
        uid,
    );

    const tier = tierFromProductId(productId);
    const provider = billingProvider(platform);
    const subSnap = await admin.firestore().collection('subscriptions').doc(uid).get();
    const existingCreatedAt =
      subSnap.exists && subSnap.data().createdAt
        ? subSnap.data().createdAt
        : null;
    await applyVerifiedMobileGrant(uid, {
      tier,
      provider,
      productId,
      verified,
      transactionId,
      existingUser,
      existingCreatedAt,
    });
    res.status(200).json({
      ok: true,
      tier,
      subscriptionStatus: verified.subscriptionStatus,
      productId,
    });
  } catch (e) {
    console.error('verifyMobilePurchase', e);
    const status =
      e.code === 'STRIPE_CONFLICT' || e.code === 'TRANSACTION_BOUND'
        ? 409
        : 500;
    res.status(status).json({error: e.message || 'Verification failed'});
  }
}

module.exports = {
  handleVerifyMobilePurchase,
  tierFromProductId,
  ALLOWED_PRODUCT_IDS,
  applyVerifiedMobileGrant,
};
