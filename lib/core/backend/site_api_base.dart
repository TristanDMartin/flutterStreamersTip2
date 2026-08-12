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

String siteWorkspaceApprovalsUrl({String? base, String scope = 'queue'}) {
  final String root = resolveSiteApiBase(explicitOverride: base);
  return '$root/api/workspace/approvals?scope=${Uri.encodeQueryComponent(scope)}';
}

String siteWorkspaceApprovalUrl({
  required String requestId,
  String? base,
}) {
  return siteApiPath(
    '/api/workspace/approvals/${Uri.encodeComponent(requestId)}',
    base: base,
  );
}

String siteTippyChatUrl({String? base}) =>
    siteApiPath('/api/tippy/chat', base: base);

String siteTippyChatsUrl({String? base}) =>
    siteApiPath('/api/tippy/chats', base: base);

String siteTippyChatByIdUrl(String chatId, {String? base}) =>
    siteApiPath('/api/tippy/chats/${Uri.encodeComponent(chatId)}', base: base);

String siteAccountProvisionUrl({String? base}) =>
    siteApiPath('/api/account/provision', base: base);

String siteAccountPendingUrl({String? base}) =>
    siteApiPath('/api/account/pending', base: base);

String siteUsernameClaimUrl({String? base}) =>
    siteApiPath('/api/username/claim', base: base);

String siteUsernameChangeUrl({String? base}) =>
    siteApiPath('/api/username/change', base: base);

String siteUsernameCheckUrl({String? base}) =>
    siteApiPath('/api/username/check', base: base);

String siteProfileDisplayNameUrl({String? base}) =>
    siteApiPath('/api/profile/display-name', base: base);
