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
  final int usedCredits;
  final String plan;
  final List<String> features;

  factory TippyAiEntitlementPayload.fromJson(Map<String, dynamic>? raw) {
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
