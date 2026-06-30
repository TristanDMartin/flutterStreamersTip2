'use strict';

const admin = require('firebase-admin');

function db() {
  return admin.firestore();
}

function mergeBillingIntoUserData(userData = {}, billingData = null) {
  const billing =
    billingData && typeof billingData === 'object' ? billingData : {};
  return {
    ...userData,
    billing,
    subscription: {
      ...(userData.subscription || {}),
      ...billing,
    },
    subscriptionTier:
      billing.tier || billing.plan || userData.subscriptionTier,
    subscriptionStatus:
      billing.status ||
      billing.subscriptionStatus ||
      userData.subscriptionStatus,
    billingProvider:
      billing.provider ||
      billing.billingProvider ||
      userData.billingProvider,
    currentPeriodEnd:
      billing.currentPeriodEnd || userData.currentPeriodEnd,
  };
}

async function loadUserWithBilling(uid) {
  const firestore = db();
  const userRef = firestore.collection('users').doc(uid);
  const billingRef = userRef.collection('billing').doc('subscription');
  const subscriptionRef = firestore.collection('subscriptions').doc(uid);
  const [userSnap, billingSnap, subscriptionSnap] = await Promise.all([
    userRef.get(),
    billingRef.get(),
    subscriptionRef.get(),
  ]);
  const userData = userSnap.exists ? userSnap.data() || {} : {};
  const subscriptionData = subscriptionSnap.exists
    ? subscriptionSnap.data() || {}
    : null;
  const billingData = billingSnap.exists
    ? billingSnap.data() || {}
    : subscriptionData;
  return mergeBillingIntoUserData(userData, billingData);
}

async function applyEntitlementPatches(uid, {
  entitlementPatch = {},
  subscriptionsPatch = {},
} = {}) {
  const firestore = db();
  const userRef = firestore.collection('users').doc(uid);
  const billingRef = userRef.collection('billing').doc('subscription');
  const subscriptionRef = firestore.collection('subscriptions').doc(uid);
  const batch = firestore.batch();
  batch.set(userRef, entitlementPatch, {merge: true});
  if (Object.keys(subscriptionsPatch).length > 0) {
    batch.set(subscriptionRef, subscriptionsPatch, {merge: true});
    batch.set(billingRef, subscriptionsPatch, {merge: true});
  }
  await batch.commit();
}

module.exports = {
  applyEntitlementPatches,
  loadUserWithBilling,
  mergeBillingIntoUserData,
};
