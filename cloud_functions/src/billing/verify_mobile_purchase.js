'use strict';

/**
 * POST /verifyMobilePurchase — same JSON body as the Flutter app
 * (MobilePurchaseVerificationPayload).
 *
 * Env (set via Firebase Functions config / secrets):
 * - APP_STORE_SHARED_SECRET — App Store Connect → app → In-App Purchase key
 * - GOOGLE_PLAY_SERVICE_ACCOUNT_JSON — full service account JSON (string)
 * - ANDROID_PACKAGE_NAME — default com.streamerstip.streamersTipApp
 *
 * Apple uses verifyReceipt (classic). StoreKit 2 JWS-only receipts return 501
 * until you add App Store Server API verification.
 */

const admin = require('firebase-admin');
const https = require('https');
const {JWT} = require('google-auth-library');
const {
  SignedDataVerifier,
  Environment,
  OfferType,
} = require('@apple/app-store-server-library');
const {loadAppleRootCertificates} = require('./apple_root_cas');

const FieldValue = admin.firestore.FieldValue;
const Timestamp = admin.firestore.Timestamp;

const ALLOWED_PRODUCT_IDS = new Set([
  'creator_pro_monthly',
  'creator_pro_yearly',
  'creator_studio_monthly',
  'creator_studio_yearly',
  'streamerstip_pro_monthly',
  'streamerstip_pro_yearly',
  'streamerstip_studio_monthly',
  'streamerstip_studio_yearly',
]);

const DEFAULT_ANDROID_PACKAGE = 'com.streamerstip.streamersTipApp';
const DEFAULT_APPLE_BUNDLE_ID = 'com.streamerstip.streamersTipApp';

function tierFromProductId(productId) {
  if (String(productId).includes('studio')) return 'studio';
  return 'pro';
}

function billingProvider(platform) {
  return platform === 'ios' ? 'apple' : 'google';
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

function buildUserEntitlementPatch({
  tier,
  provider,
  productId,
  verified,
  periodEndTs,
  trialTs,
  now,
  existingUser = {},
}) {
  const isPaid =
    verified.subscriptionStatus === 'active' ||
    verified.subscriptionStatus === 'trialing';
  const existingEnt =
    existingUser.entitlements &&
    typeof existingUser.entitlements === 'object' &&
    !Array.isArray(existingUser.entitlements)
      ? existingUser.entitlements
      : {};
  const existingSub =
    existingUser.subscription &&
    typeof existingUser.subscription === 'object' &&
    !Array.isArray(existingUser.subscription)
      ? existingUser.subscription
      : {};
  const existingTippy =
    existingEnt.tippyAi &&
    typeof existingEnt.tippyAi === 'object' &&
    !Array.isArray(existingEnt.tippyAi)
      ? existingEnt.tippyAi
      : {};
  return {
    tier,
    subscriptionTier: tier,
    subscriptionStatus: verified.subscriptionStatus,
    billingProvider: provider,
    planProductId: productId,
    currentPeriodEnd: periodEndTs,
    trialEndsAt: trialTs,
    subscriptionTrialEndAt: trialTs,
    updatedAt: now,
    entitlements: {
      ...existingEnt,
      active: isPaid,
      tippyAi: {
        ...existingTippy,
        plan: tier,
        tier,
        status: verified.subscriptionStatus,
        productId,
        provider,
      },
    },
    subscription: {
      ...existingSub,
      tier,
      plan: tier,
      status: verified.subscriptionStatus,
      productId,
      provider,
      currentPeriodEnd: periodEndTs,
      trialEndsAt: trialTs,
      cancelAtPeriodEnd: false,
    },
  };
}

async function verifyGooglePlaySubscription(packageName, productId, purchaseToken) {
  const raw = process.env.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON;
  if (!raw || raw.trim() === '') {
    throw new Error('GOOGLE_PLAY_SERVICE_ACCOUNT_JSON is not configured');
  }
  const cred = JSON.parse(raw);
  const jwtClient = new JWT({
    email: cred.client_email,
    key: cred.private_key,
    scopes: ['https://www.googleapis.com/auth/androidpublisher'],
  });
  const url =
    'https://androidpublisher.googleapis.com/androidpublisher/v3/' +
    `applications/${encodeURIComponent(packageName)}` +
    '/purchases/subscriptionsv2/tokens/' +
    `${encodeURIComponent(purchaseToken)}`;
  const gRes = await jwtClient.request({url});
  const data = gRes.data || {};
  if (gRes.status < 200 || gRes.status >= 300) {
    throw new Error(
      `Play API ${gRes.status}: ${JSON.stringify(data).slice(0, 500)}`,
    );
  }
  const state = String(data.subscriptionState || '').toUpperCase();
  if (!state.includes('ACTIVE') && !state.includes('PENDING')) {
    throw new Error(`Play subscriptionState: ${data.subscriptionState}`);
  }
  const items = data.lineItems || [];
  if (!Array.isArray(items) || items.length === 0) {
    throw new Error('Play subscription has no lineItems');
  }
  const li =
    items.find((x) => x.productId === productId) || items[0];
  const expiryIso = li.expiryTime;
  if (!expiryIso) {
    throw new Error('Play lineItem missing expiryTime');
  }
  const currentPeriodEnd = new Date(expiryIso);
  const offer = li.offerDetails || {};
  const tags = (offer.offerTags || []).map((x) => String(x).toUpperCase());
  const trial =
    tags.includes('FREE_TRIAL') ||
    tags.includes('INTRODUCTORY_PRICE') ||
    String(offer.basePlanId || '').toLowerCase().includes('trial');
  return {
    originalTransactionId: String(data.latestOrderId || purchaseToken),
    purchaseTokenStored: purchaseToken,
    currentPeriodEnd,
    trialEndsAt: trial ? currentPeriodEnd : null,
    subscriptionStatus: trial ? 'trialing' : 'active',
  };
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
    if (!purchaseToken) {
      res.status(400).json({error: 'Missing purchaseToken'});
      return;
    }
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
      const pkg =
        process.env.ANDROID_PACKAGE_NAME || DEFAULT_ANDROID_PACKAGE;
      verified = await verifyGooglePlaySubscription(
          pkg,
          productId,
          purchaseToken,
      );
    } else {
      res.status(400).json({error: 'platform must be ios or android'});
      return;
    }
    const tier = tierFromProductId(productId);
    const provider = billingProvider(platform);
    const now = FieldValue.serverTimestamp();
    const userRef = admin.firestore().collection('users').doc(uid);
    const subRef = admin.firestore().collection('subscriptions').doc(uid);
    const userSnap = await userRef.get();
    const existingUser = userSnap.exists ? userSnap.data() || {} : {};
    const subSnap = await subRef.get();
    const existingCreatedAt =
      subSnap.exists && subSnap.data().createdAt
        ? subSnap.data().createdAt
        : null;
    const periodEndTs = Timestamp.fromDate(verified.currentPeriodEnd);
    const trialTs = verified.trialEndsAt
      ? Timestamp.fromDate(verified.trialEndsAt)
      : null;
    const batch = admin.firestore().batch();
    batch.set(
        userRef,
        buildUserEntitlementPatch({
          tier,
          provider,
          productId,
          verified,
          periodEndTs,
          trialTs,
          now,
          existingUser,
        }),
        {merge: true},
    );
    batch.set(
        subRef,
        {
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
        },
        {merge: true},
    );
    await batch.commit();
    res.status(200).json({
      ok: true,
      tier,
      subscriptionStatus: verified.subscriptionStatus,
      productId,
    });
  } catch (e) {
    console.error('verifyMobilePurchase', e);
    res.status(500).json({error: e.message || 'Verification failed'});
  }
}

module.exports = {handleVerifyMobilePurchase};
