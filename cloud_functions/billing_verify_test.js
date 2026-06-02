'use strict';

const assert = require('assert');

const ALLOWED = new Set([
  'streamerstip_pro_monthly',
  'streamerstip_pro_yearly',
  'streamerstip_studio_monthly',
  'streamerstip_studio_yearly',
]);

function tierFromProductId(productId) {
  if (String(productId).includes('studio')) return 'studio';
  return 'pro';
}

assert.strictEqual(tierFromProductId('streamerstip_pro_monthly'), 'pro');
assert.strictEqual(tierFromProductId('streamerstip_studio_yearly'), 'studio');
assert(ALLOWED.has('streamerstip_pro_monthly'));

console.log('billing_verify_test: ok');
