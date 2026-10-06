'use strict';

const admin = require('firebase-admin');

/** Mirrors firestore.rules `accountMayUseProduct`. */
const PRODUCT_ACCOUNT_STATUSES = new Set([
  '',
  'active',
  'verificationpending',
  'verifiedprovisioning',
  'verificationrequired',
]);

function isProductAccountStatus(rawStatus) {
  const status = typeof rawStatus === 'string' ? rawStatus.trim().toLowerCase() : '';
  return PRODUCT_ACCOUNT_STATUSES.has(status);
}

/** Missing doc is allowed (provisioning race), matching the rules. */
async function canAccountUseProduct(uid) {
  const snap = await admin.firestore().collection('users').doc(uid).get();
  if (!snap.exists) return true;
  const data = snap.data() || {};
  if (data.isDeleted === true) return false;
  return isProductAccountStatus(data.accountStatus);
}

module.exports = {isProductAccountStatus, canAccountUseProduct};
