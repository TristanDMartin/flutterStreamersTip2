'use strict';

const assert = require('assert');

const ALLOWED = new Set([
  'streamerstip_pro_monthly_ios',
  'streamerstip_pro_yearly_ios',
  'streamerstip_studio_monthly_ios',
  'streamerstip_studio_yearly_ios',
  'streamerstip_pro_monthly_android',
  'streamerstip_pro_yearly_android',
  'streamerstip_studio_monthly_android',
  'streamerstip_studio_yearly_android',
  'streamerstip_pro_monthly',
  'streamerstip_pro_yearly',
  'streamerstip_studio_monthly',
  'streamerstip_studio_yearly',
]);

function tierFromProductId(productId) {
  if (String(productId).includes('studio')) return 'studio';
  return 'pro';
}

assert.strictEqual(tierFromProductId('streamerstip_pro_monthly_ios'), 'pro');
assert.strictEqual(tierFromProductId('streamerstip_studio_yearly_android'), 'studio');
assert(ALLOWED.has('streamerstip_pro_monthly_ios'));
assert(ALLOWED.has('streamerstip_pro_monthly_android'));

console.log('billing_verify_test: ok');
