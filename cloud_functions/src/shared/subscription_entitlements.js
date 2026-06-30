'use strict';

const admin = require('firebase-admin');
const {HttpsError} = require('firebase-functions/v2/https');
const {normalizeTierKey} = require('./entitlements');

const Timestamp = admin.firestore.Timestamp;
const FieldValue = admin.firestore.FieldValue;

function db() {
  return admin.firestore();
}

function normalizeTierString(value) {
  const tier = normalizeTierKey(value);
  return tier === 'starter' ? 'starter' : tier;
}

function isPaidSubscriptionStatus(status) {
  return [
    'active',
    'trialing',
    'in_trial',
    'grace_period',
    'past_due',
  ].includes(String(status || '').trim().toLowerCase());
}

function readTimestampAsDate(value) {
  if (!value) {
    return null;
  }
  if (value instanceof Date) {
    return value;
  }
  if (typeof value.toDate === 'function') {
    return value.toDate();
  }
  if (typeof value === 'number') {
    return new Date(value);
  }
  if (typeof value === 'string') {
    const parsed = Date.parse(value);
    return Number.isFinite(parsed) ? new Date(parsed) : null;
  }
  return null;
}

function readPeriodEndFromUserDoc(userData = {}) {
  const candidates = [
    userData.currentPeriodEnd,
    userData.subscriptionCurrentPeriodEnd,
    userData.subscription?.currentPeriodEnd,
    userData.subscription?.periodEnd,
    userData.subscription?.expiresAt,
    userData.billing?.currentPeriodEnd,
  ];
  for (const value of candidates) {
    const date = readTimestampAsDate(value);
    if (date) {
      return date;
    }
  }
  return null;
}

function isSubscriptionPeriodActive(userData = {}) {
  const status = String(
      userData.subscriptionStatus ||
      userData.subscription?.status ||
      userData.billing?.status ||
      '',
  ).trim().toLowerCase();
  if (!isPaidSubscriptionStatus(status)) {
    return false;
  }
  const periodEnd = readPeriodEndFromUserDoc(userData);
  return !periodEnd || periodEnd.getTime() > Date.now();
}

function assertMobilePurchaseAllowed(userData = {}) {
  const provider = String(
      userData.billingProvider ||
      userData.subscription?.provider ||
      userData.billing?.provider ||
      '',
  ).trim().toLowerCase();
  if (provider === 'stripe') {
    const err = new HttpsError(
        'failed-precondition',
        'Manage your web subscription from the website.',
    );
    err.code = 'STRIPE_CONFLICT';
    throw err;
  }
}

async function assertTransactionNotBoundToOtherUser(
    originalTransactionId,
    uid,
) {
  const id = String(originalTransactionId || '').trim();
  if (!id) {
    return;
  }
  const doc = await db().collection('subscriptionTransactions').doc(id).get();
  if (doc.exists && doc.data()?.uid && doc.data().uid !== uid) {
    const err = new HttpsError(
        'already-exists',
        'This purchase is already linked to another account.',
    );
    err.code = 'TRANSACTION_BOUND';
    throw err;
  }
}

function buildUserEntitlementPatch({
  tier,
  provider,
  productId,
  verified,
  periodEndTs,
  trialTs,
  now,
}) {
  const normalizedTier = normalizeTierString(tier);
  const status = verified.subscriptionStatus || 'active';
  return {
    subscriptionTier: normalizedTier,
    subscriptionStatus: status,
    subscriptionProvider: provider,
    billingProvider: provider,
    subscriptionProductId: productId,
    currentPeriodEnd: periodEndTs,
    trialEndsAt: trialTs,
    updatedAt: now,
    entitlements: {
      tippyAi: {
        enabled: normalizedTier === 'pro' || normalizedTier === 'studio',
        tier: normalizedTier,
        provider,
        productId,
        status,
        currentPeriodEnd: periodEndTs,
        updatedAt: now,
      },
    },
    subscription: {
      tier: normalizedTier,
      provider,
      status,
      productId,
      originalTransactionId: verified.originalTransactionId,
      purchaseToken: verified.purchaseTokenStored,
      currentPeriodEnd: periodEndTs,
      trialEndsAt: trialTs,
      updatedAt: now,
    },
  };
}

async function applyEntitlementDowngrade(uid, {
  status = 'expired',
  reason = 'subscription_inactive',
} = {}) {
  const now = FieldValue.serverTimestamp();
  const patch = {
    subscriptionTier: 'starter',
    subscriptionStatus: status,
    updatedAt: now,
    entitlements: {
      tippyAi: {
        enabled: false,
        tier: 'starter',
        status,
        updatedAt: now,
      },
    },
    subscription: {
      tier: 'starter',
      status,
      lastLifecycleReason: reason,
      updatedAt: now,
    },
  };
  await db().collection('users').doc(uid).set(patch, {merge: true});
  await db().collection('subscriptions').doc(uid).set({
    uid,
    tier: 'starter',
    status,
    lastLifecycleReason: reason,
    updatedAt: now,
  }, {merge: true});
}

async function recordTransactionOwner({
  originalTransactionId,
  uid,
  provider,
  productId,
}) {
  const id = String(originalTransactionId || '').trim();
  if (!id) {
    return;
  }
  await db().collection('subscriptionTransactions').doc(id).set({
    uid,
    provider,
    productId,
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});
}

module.exports = {
  Timestamp,
  FieldValue,
  normalizeTierString,
  isPaidSubscriptionStatus,
  readPeriodEndFromUserDoc,
  isSubscriptionPeriodActive,
  assertMobilePurchaseAllowed,
  assertTransactionNotBoundToOtherUser,
  applyEntitlementDowngrade,
  buildUserEntitlementPatch,
  recordTransactionOwner,
};
