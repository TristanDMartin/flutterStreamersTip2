/// Unlimited numeric limits from `/api/user/entitlements`.
const int kEntitlementUnlimited = -1;

bool isEntitlementUnlimited(int value) => value < 0;
