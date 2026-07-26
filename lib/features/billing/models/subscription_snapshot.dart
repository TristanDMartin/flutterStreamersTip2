import 'package:streamers_tip/features/billing/entitlement_sentinel.dart';
import 'package:streamers_tip/features/billing/models/billing_tier.dart';
import 'package:streamers_tip/features/billing/models/growth_entitlement_levels.dart';
import 'package:streamers_tip/features/billing/tier_display_names.dart';
import 'package:streamers_tip/features/entitlements/tippy_ai_entitlement_payload.dart';

class ApiEntitlements {
  const ApiEntitlements({
    required this.maxPlatforms,
    required this.monthlyAiCredits,
    required this.contentPlansLimit,
    required this.analyticsWindowDays,
    required this.crossPostWeeklyLimit,
    required this.videoUploadsPerMonth,
    required this.teamMembersLimit,
    required this.canCrossPost,
    required this.canBulkPublish,
    required this.canUseAdvancedAnalytics,
    required this.canUseAICaptionRewrite,
    required this.canUseGrowthReports,
    required this.canUseTeamMembers,
    required this.canUseAutomation,
    required this.canExportAnalytics,
    required this.canUseContentPlanner,
  });

  final int maxPlatforms;
  final int monthlyAiCredits;
  final int contentPlansLimit;
  final int analyticsWindowDays;
  final int crossPostWeeklyLimit;
  final int videoUploadsPerMonth;
  final int teamMembersLimit;
  final bool canCrossPost;
  final bool canBulkPublish;
  final bool canUseAdvancedAnalytics;
  final bool canUseAICaptionRewrite;
  final bool canUseGrowthReports;
  final bool canUseTeamMembers;
  final bool canUseAutomation;
  final bool canExportAnalytics;
  final bool canUseContentPlanner;

  bool get canBulkPublishEffective =>
      canBulkPublish || isEntitlementUnlimited(contentPlansLimit);

  int effectiveMaxPlatforms() {
    if (isEntitlementUnlimited(maxPlatforms)) {
      return 999;
    }
    return maxPlatforms < 1 ? 1 : maxPlatforms;
  }

  factory ApiEntitlements.fromJson(Map<String, dynamic>? raw) {
    if (raw == null || raw.isEmpty) {
      return ApiEntitlements.fallbackStarter();
    }
    return ApiEntitlements(
      maxPlatforms: _readInt(raw['maxPlatforms'], 1),
      monthlyAiCredits: _readInt(
        raw['monthlyAiCredits'] ?? raw['aiCreditsPerMonth'],
        0,
      ),
      contentPlansLimit: _readInt(
        raw['contentPlansLimit'] ?? raw['contentPlans'],
        1,
      ),
      analyticsWindowDays: _readInt(raw['analyticsWindowDays'], 7),
      crossPostWeeklyLimit: _readInt(raw['crossPostWeeklyLimit'], 0),
      // Missing field must not look like "0 uploads left" — uploads are unlimited.
      videoUploadsPerMonth: _readInt(
        raw['videoUploadsPerMonth'],
        kEntitlementUnlimited,
      ),
      teamMembersLimit: _readInt(raw['teamMembersLimit'] ?? raw['teamMembers'], 0),
      canCrossPost: _readBool(raw['canCrossPost'], false),
      canBulkPublish: _readBool(raw['canBulkPublish'], false),
      canUseAdvancedAnalytics: _readBool(raw['canUseAdvancedAnalytics'], false),
      canUseAICaptionRewrite: _readBool(raw['canUseAICaptionRewrite'], false),
      canUseGrowthReports: _readBool(raw['canUseGrowthReports'], false),
      canUseTeamMembers: _readBool(raw['canUseTeamMembers'], false),
      canUseAutomation: _readBool(raw['canUseAutomation'], false),
      canExportAnalytics: _readBool(raw['canExportAnalytics'], false),
      canUseContentPlanner: _readBool(raw['canUseContentPlanner'], true),
    );
  }

  factory ApiEntitlements.fromLegacyLimitsAndFeatures({
    required Map<String, dynamic>? limits,
    required Map<String, dynamic>? features,
  }) {
    final Map<String, dynamic> lim = limits ?? <String, dynamic>{};
    final Map<String, dynamic> feat = features ?? <String, dynamic>{};
    return ApiEntitlements(
      maxPlatforms: _readInt(
        lim['connectedPlatforms'],
        1,
      ),
      monthlyAiCredits: _readInt(lim['aiCreditsPerMonth'], 0),
      contentPlansLimit: _readInt(lim['contentPlans'], 1),
      analyticsWindowDays: _readInt(lim['analyticsWindowDays'], 7),
      crossPostWeeklyLimit: _readInt(lim['crossPostWeeklyLimit'], 0),
      videoUploadsPerMonth: _readInt(
        lim['videoUploadsPerMonth'],
        kEntitlementUnlimited,
      ),
      teamMembersLimit: _readInt(lim['teamMembers'], 0),
      canCrossPost: _readBool(feat['crossPosting'], false),
      canBulkPublish: _readBool(feat['bulkPublishing'], false),
      canUseAdvancedAnalytics: _readBool(feat['advancedAnalytics'], false),
      canUseAICaptionRewrite: _readBool(feat['tippyPremium'], false),
      canUseGrowthReports: _readBool(feat['advancedReports'], false),
      canUseTeamMembers: _readBool(feat['teamMembers'], false),
      canUseAutomation: _readBool(feat['automation'], false),
      canExportAnalytics: _readBool(feat['analyticsExport'], false),
      canUseContentPlanner: _readBool(feat['contentPlanner'], true),
    );
  }

  /// Matches website `lib/billing/entitlements.ts` starter SoT.
  factory ApiEntitlements.fallbackStarter() {
    return const ApiEntitlements(
      maxPlatforms: 1,
      monthlyAiCredits: 25,
      contentPlansLimit: 1,
      analyticsWindowDays: 7,
      crossPostWeeklyLimit: 0,
      videoUploadsPerMonth: kEntitlementUnlimited,
      teamMembersLimit: 0,
      canCrossPost: false,
      canBulkPublish: false,
      canUseAdvancedAnalytics: false,
      canUseAICaptionRewrite: false,
      canUseGrowthReports: false,
      canUseTeamMembers: false,
      canUseAutomation: false,
      canExportAnalytics: false,
      canUseContentPlanner: true,
    );
  }
}

class UsageSnapshot {
  const UsageSnapshot({
    required this.periodKey,
    required this.monthlyCreditsUsed,
    required this.monthlyCreditsRemaining,
    this.lastResetDate,
  });

  final String periodKey;
  final int monthlyCreditsUsed;
  final int monthlyCreditsRemaining;
  final DateTime? lastResetDate;

  factory UsageSnapshot.fromJson(Map<String, dynamic>? raw) {
    if (raw == null || raw.isEmpty) {
      return const UsageSnapshot(
        periodKey: '',
        monthlyCreditsUsed: 0,
        monthlyCreditsRemaining: 0,
      );
    }
    return UsageSnapshot(
      periodKey: raw['periodKey'] is String ? raw['periodKey'] as String : '',
      monthlyCreditsUsed: _readInt(
        raw['monthlyCreditsUsed'] ?? raw['usedCredits'],
        0,
      ),
      monthlyCreditsRemaining: _readInt(
        raw['monthlyCreditsRemaining'] ?? raw['remainingCredits'],
        0,
      ),
      lastResetDate: _readDate(
        raw['lastResetDate'] ?? raw['resetAt'],
      ),
    );
  }
}

class AiCreditCosts {
  const AiCreditCosts({required this.costs});

  final Map<String, int> costs;

  int costFor(String action, {int fallback = 1}) {
    final int? v = costs[action];
    if (v != null && v > 0) {
      return v;
    }
    return fallback;
  }

  factory AiCreditCosts.fromJson(Map<String, dynamic>? raw) {
    if (raw == null || raw.isEmpty) {
      return AiCreditCosts.canonical;
    }
    final Map<String, int> out = <String, int>{};
    raw.forEach((String key, Object? value) {
      final int n = _readInt(value, 0);
      if (n > 0) {
        out[key] = n;
      }
    });
    if (out.isEmpty) {
      return AiCreditCosts.canonical;
    }
    return AiCreditCosts(costs: out);
  }

  static const AiCreditCosts canonical = AiCreditCosts(
    costs: <String, int>{
      'captionRewrite': 1,
      'hashtags': 1,
      'captionGeneration': 2,
      'contentPlan': 5,
      'growthAnalysis': 10,
    },
  );
}

/// Parsed `/api/user/entitlements` payload for the signed-in user.
class SubscriptionSnapshot {
  const SubscriptionSnapshot({
    required this.tier,
    required this.effectiveTier,
    required this.storedTier,
    required this.subscriptionStatus,
    required this.isPaid,
    required this.isStarter,
    required this.isPro,
    required this.isStudio,
    required this.isOwnerAccount,
    required this.isUnlimited,
    required this.creditsUsed,
    required this.creditsLimit,
    required this.creditsRemaining,
    required this.entitlements,
    required this.usage,
    required this.aiCreditCosts,
    this.levels = const GrowthEntitlementLevels(
      dailyBriefLevel: 'basic',
      creatorMemoryLevel: 'basic',
      creatorScoreLevel: 'basic',
      weeklyReportLevel: 'basic',
      academyAccessLevel: 'foundation',
    ),
    this.subscriptionPeriodEnd,
    this.resetAt,
    this.source = '',
    this.uid = '',
    this.email = '',
    this.canUseTippy = true,
  });

  final BillingTier tier;
  final BillingTier effectiveTier;
  final BillingTier storedTier;
  final String subscriptionStatus;
  final DateTime? subscriptionPeriodEnd;
  final bool isPaid;
  final bool isStarter;
  final bool isPro;
  final bool isStudio;
  final bool isOwnerAccount;
  final bool isUnlimited;
  final int creditsUsed;
  final int creditsLimit;
  final int creditsRemaining;
  final String source;
  final DateTime? resetAt;
  final ApiEntitlements entitlements;
  final UsageSnapshot usage;
  final AiCreditCosts aiCreditCosts;
  final GrowthEntitlementLevels levels;
  final String uid;
  final String email;
  final bool canUseTippy;

  String get tierApi => billingTierToApiValue(effectiveTier);

  String get tierDisplayName => tierDisplayNameForApi(tierApi);

  String get weeklyReportLevel => levels.weeklyReportLevel;

  bool get isTrialing =>
      subscriptionStatus.trim().toLowerCase() == 'trialing';

  /// Uploads are never paywalled across Creator / Pro / Studio.
  bool canUpload({required int uploadsThisMonth}) {
    return canUploadVideo(
      videoUploadsPerMonth: entitlements.videoUploadsPerMonth,
      uploadsThisMonth: uploadsThisMonth,
    );
  }

  /// Legacy provider / Tippy UI compatibility.
  String get tierSource => source;

  bool get hasFullAccess => isOwnerAccount || isUnlimited;

  bool get canBulkPublish => entitlements.canBulkPublish;

  int get analyticsDays => entitlements.analyticsWindowDays;

  TippyAiEntitlementPayload get tippyAi => TippyAiEntitlementPayload(
        enabled: hasFullAccess || canUseTippy,
        monthlyCredits: entitlements.monthlyAiCredits > 0
            ? entitlements.monthlyAiCredits
            : creditsLimit,
        remainingCredits: usage.monthlyCreditsRemaining > 0
            ? usage.monthlyCreditsRemaining
            : creditsRemaining,
        usedCredits: usage.monthlyCreditsUsed > 0
            ? usage.monthlyCreditsUsed
            : creditsUsed,
        plan: tierApi,
      );

  factory SubscriptionSnapshot.fromResponseJson(Map<String, dynamic> body) {
    final Map<String, dynamic> root = _unwrapRoot(body);
    final String tierRaw = _readString(
      root['tier'] ?? root['effectiveTier'],
      'starter',
    );
    final String storedRaw = _readString(
      root['storedTier'] ?? tierRaw,
      tierRaw,
    );
    final BillingTier effective = billingTierFromApi(tierRaw);
    final BillingTier stored = billingTierFromApi(storedRaw);
    ApiEntitlements entitlements = ApiEntitlements.fromJson(
      root['entitlements'] is Map<String, dynamic>
          ? root['entitlements'] as Map<String, dynamic>
          : null,
    );
    if (root['entitlements'] == null &&
        (root['limits'] != null || root['features'] != null)) {
      entitlements = ApiEntitlements.fromLegacyLimitsAndFeatures(
        limits: root['limits'] is Map<String, dynamic>
            ? root['limits'] as Map<String, dynamic>
            : null,
        features: root['features'] is Map<String, dynamic>
            ? root['features'] as Map<String, dynamic>
            : null,
      );
    }
    final Map<String, dynamic>? tippyMap =
        root['tippyAi'] is Map<String, dynamic>
            ? root['tippyAi'] as Map<String, dynamic>
            : null;
    if (root['entitlements'] == null && tippyMap != null) {
      entitlements = ApiEntitlements(
        maxPlatforms: entitlements.maxPlatforms,
        monthlyAiCredits: _readInt(
          tippyMap['monthlyCredits'] ?? root['aiCreditsMonthlyLimit'],
          entitlements.monthlyAiCredits,
        ),
        contentPlansLimit: entitlements.contentPlansLimit,
        analyticsWindowDays: entitlements.analyticsWindowDays,
        crossPostWeeklyLimit: entitlements.crossPostWeeklyLimit,
        videoUploadsPerMonth: entitlements.videoUploadsPerMonth,
        teamMembersLimit: entitlements.teamMembersLimit,
        canCrossPost: entitlements.canCrossPost,
        canBulkPublish: entitlements.canBulkPublish,
        canUseAdvancedAnalytics: entitlements.canUseAdvancedAnalytics,
        canUseAICaptionRewrite: entitlements.canUseAICaptionRewrite,
        canUseGrowthReports: entitlements.canUseGrowthReports,
        canUseTeamMembers: entitlements.canUseTeamMembers,
        canUseAutomation: entitlements.canUseAutomation,
        canExportAnalytics: entitlements.canExportAnalytics,
        canUseContentPlanner: entitlements.canUseContentPlanner,
      );
    }
    final int creditsLimit = _readInt(
      root['creditsLimit'] ?? root['aiCreditsMonthlyLimit'],
      entitlements.monthlyAiCredits,
    );
    final int creditsRemaining = _readInt(
      root['creditsRemaining'],
      _readInt(tippyMap?['remainingCredits'], 0),
    );
    final int creditsUsed = _readInt(
      root['creditsUsed'],
      _readInt(tippyMap?['usedCredits'], 0),
    );
    UsageSnapshot usage = UsageSnapshot.fromJson(
      root['usage'] is Map<String, dynamic>
          ? root['usage'] as Map<String, dynamic>
          : null,
    );
    if (usage.monthlyCreditsRemaining == 0 && creditsRemaining > 0) {
      usage = UsageSnapshot(
        periodKey: usage.periodKey,
        monthlyCreditsUsed: creditsUsed,
        monthlyCreditsRemaining: creditsRemaining,
        lastResetDate: usage.lastResetDate ?? _readDate(root['resetAt']),
      );
    }
    final Map<String, dynamic>? levelsMap =
        root['levels'] is Map<String, dynamic>
            ? root['levels'] as Map<String, dynamic>
            : root;
    final GrowthEntitlementLevels levels = GrowthEntitlementLevels.fromJson(
      levelsMap,
      tierApi: billingTierToApiValue(effective),
    );
    return SubscriptionSnapshot(
      uid: _readString(root['uid'], ''),
      email: _readString(root['email'], ''),
      tier: effective,
      effectiveTier: effective,
      storedTier: stored,
      subscriptionStatus: _readString(root['subscriptionStatus'], 'inactive'),
      subscriptionPeriodEnd: _readDate(root['subscriptionPeriodEnd']),
      isPaid: root['isPaid'] == true ||
          _inferIsPaid(
            tier: effective,
            status: _readString(root['subscriptionStatus'], 'inactive'),
            periodEnd: _readDate(root['subscriptionPeriodEnd']),
          ),
      isStarter: root['isStarter'] == true || effective == BillingTier.starter,
      isPro: root['isPro'] == true || effective == BillingTier.pro,
      isStudio: root['isStudio'] == true || effective == BillingTier.studio,
      isOwnerAccount: root['isOwnerAccount'] == true,
      isUnlimited: root['isUnlimited'] == true,
      creditsUsed: creditsUsed,
      creditsLimit: creditsLimit,
      creditsRemaining: creditsRemaining,
      source: _readString(
        root['source'] ??
            root['tierSource'] ??
            root['subscriptionProvider'],
        '',
      ),
      resetAt: _readDate(root['resetAt']),
      entitlements: entitlements,
      usage: usage,
      aiCreditCosts: AiCreditCosts.fromJson(
        root['aiCreditCosts'] is Map<String, dynamic>
            ? root['aiCreditCosts'] as Map<String, dynamic>
            : null,
      ),
      levels: levels,
      canUseTippy: tippyMap != null
          ? tippyMap['enabled'] == true
          : true,
    );
  }

  factory SubscriptionSnapshot.starterFallback() {
    return SubscriptionSnapshot(
      tier: BillingTier.starter,
      effectiveTier: BillingTier.starter,
      storedTier: BillingTier.starter,
      subscriptionStatus: 'inactive',
      isPaid: false,
      isStarter: true,
      isPro: false,
      isStudio: false,
      isOwnerAccount: false,
      isUnlimited: false,
      creditsUsed: 0,
      creditsLimit: 0,
      creditsRemaining: 0,
      entitlements: ApiEntitlements.fallbackStarter(),
      usage: const UsageSnapshot(
        periodKey: '',
        monthlyCreditsUsed: 0,
        monthlyCreditsRemaining: 0,
      ),
      aiCreditCosts: AiCreditCosts.canonical,
      levels: GrowthEntitlementLevels.forTierApi('starter'),
    );
  }
}

Map<String, dynamic> _unwrapRoot(Map<String, dynamic> json) {
  if (json['success'] == true && json['data'] is Map<String, dynamic>) {
    return json['data'] as Map<String, dynamic>;
  }
  return json;
}

int _readInt(Object? value, int fallback) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  if (value is String) {
    return int.tryParse(value) ?? fallback;
  }
  return fallback;
}

bool _readBool(Object? value, bool fallback) {
  if (value is bool) {
    return value;
  }
  return fallback;
}

String _readString(Object? value, String fallback) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return fallback;
}

bool _inferIsPaid({
  required BillingTier tier,
  required String status,
  required DateTime? periodEnd,
}) {
  if (tier != BillingTier.pro && tier != BillingTier.studio) {
    return false;
  }
  final String s = status.trim().toLowerCase();
  if (s == 'active' || s == 'trialing' || s == 'grace_period') {
    return true;
  }
  if (periodEnd != null && periodEnd.isAfter(DateTime.now())) {
    return true;
  }
  return false;
}

DateTime? _readDate(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is DateTime) {
    return value;
  }
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value.trim());
  }
  return null;
}
