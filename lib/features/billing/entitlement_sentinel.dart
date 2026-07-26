/// Unlimited numeric limits from `/api/user/entitlements`.
const int kEntitlementUnlimited = -1;

bool isEntitlementUnlimited(int value) => value < 0;

/// Uploads are never paywalled. Always use this (limit can be `-1`).
bool canUploadVideo({
  required int videoUploadsPerMonth,
  required int uploadsThisMonth,
}) {
  return isEntitlementUnlimited(videoUploadsPerMonth) ||
      uploadsThisMonth < videoUploadsPerMonth;
}
