/// Production website API (same-origin `/api/*` on streamerstip.com).
const String kSiteApiBase = String.fromEnvironment(
  'SITE_API_BASE',
  defaultValue: 'https://streamerstip.com',
);

String resolveSiteApiBase({String? explicitOverride}) {
  final String configured = (explicitOverride ?? kSiteApiBase).trim();
  return configured.replaceAll(RegExp(r'/$'), '');
}

String siteApiPath(String path, {String? base}) {
  final String root = resolveSiteApiBase(explicitOverride: base);
  final String p = path.startsWith('/') ? path : '/$path';
  return '$root$p';
}

String siteUserEntitlementsUrl({String? base}) =>
    siteApiPath('/api/user/entitlements', base: base);

String siteUserCreditsUrl({String? base}) =>
    siteApiPath('/api/user/credits', base: base);

String siteAppleBillingVerifyUrl({String? base}) =>
    siteApiPath('/api/billing/apple/verify', base: base);

String siteGoogleBillingVerifyUrl({String? base}) =>
    siteApiPath('/api/billing/google/verify', base: base);

String siteGrowthDataUrl({
  required String userId,
  required int days,
  String? base,
}) {
  final String root = resolveSiteApiBase(explicitOverride: base);
  return '$root/api/growth/data?userId=${Uri.encodeQueryComponent(userId)}'
      '&days=$days';
}

String siteGrowthRefreshUrl({
  required String userId,
  String? base,
}) {
  final String root = resolveSiteApiBase(explicitOverride: base);
  return '$root/api/growth/refresh?userId=${Uri.encodeQueryComponent(userId)}';
}

String siteRetentionTrackUrl({String? base}) =>
    siteApiPath('/api/track', base: base);

String siteWeeklyReportUrl({String? base}) =>
    siteApiPath('/api/reports/weekly', base: base);

String siteStudioTeamControlUrl({String? base}) =>
    siteApiPath('/api/studio/team-control', base: base);

String siteStudioExportWeeklyUrl({String? base}) =>
    siteApiPath('/api/studio/export/weekly', base: base);
