class TippyAiEntitlementPayload {
  const TippyAiEntitlementPayload({
    required this.enabled,
    required this.monthlyCredits,
    required this.remainingCredits,
    this.usedCredits = -1,
    this.plan = '',
    this.features = const <String>[],
  });

  final bool enabled;
  final int monthlyCredits;
  final int remainingCredits;

  /// When >= 0, synced from backend [credits.used]. Used to infer remaining.
  final int usedCredits;
  final String plan;
  final List<String> features;

  factory TippyAiEntitlementPayload.fromJson(
    Map<String, dynamic>? raw,
  ) {
    if (raw == null || raw.isEmpty) {
      return const TippyAiEntitlementPayload(
        enabled: false,
        monthlyCredits: 0,
        remainingCredits: 0,
        usedCredits: -1,
      );
    }
    int readI(Object? v) {
      if (v is int) {
        return v;
      }
      if (v is num) {
        return v.round();
      }
      if (v is String) {
        return int.tryParse(v) ?? 0;
      }
      return 0;
    }

    final List<dynamic> featRaw = raw['features'] is List<dynamic>
        ? raw['features'] as List<dynamic>
        : const <dynamic>[];
    final int usedRaw = readI(raw['usedCredits']);
    return TippyAiEntitlementPayload(
      enabled: raw['enabled'] == true,
      monthlyCredits: readI(raw['monthlyCredits']),
      remainingCredits: readI(raw['remainingCredits']),
      usedCredits: raw.containsKey('usedCredits') ? usedRaw : -1,
      plan: raw['plan'] is String ? raw['plan'] as String : '',
      features: featRaw.map((Object? e) => e.toString()).toList(
            growable: false,
          ),
    );
  }
}

class MeEntitlementsData {
  const MeEntitlementsData({
    required this.uid,
    this.email = '',
    required this.tier,
    required this.tierSource,
    this.subscriptionStatus = 'unknown',
    this.tippyAi = const TippyAiEntitlementPayload(
      enabled: false,
      monthlyCredits: 0,
      remainingCredits: 0,
      usedCredits: -1,
    ),
  });

  final String uid;
  final String email;
  final String tier;
  final String tierSource;
  final String subscriptionStatus;
  final TippyAiEntitlementPayload tippyAi;

  factory MeEntitlementsData.fromResponseJson(
    Map<String, dynamic> body,
  ) {
    final Object? d = body['data'];
    final Map<String, dynamic> data =
        d is Map<String, dynamic> ? d : <String, dynamic>{};
    final String tier =
        data['tier'] is String ? (data['tier'] as String) : 'unknown';
    return MeEntitlementsData(
      uid: data['uid'] is String ? data['uid'] as String : '',
      email: data['email'] is String ? data['email'] as String : '',
      tier: tier,
      tierSource:
          data['tierSource'] is String ? data['tierSource'] as String : 'none',
      subscriptionStatus: data['subscriptionStatus'] is String
          ? data['subscriptionStatus'] as String
          : 'unknown',
      tippyAi: TippyAiEntitlementPayload.fromJson(
        data['tippyAi'] is Map<String, dynamic>
            ? data['tippyAi'] as Map<String, dynamic>
            : null,
      ),
    );
  }
}
