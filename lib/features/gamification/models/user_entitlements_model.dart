/// Feature flags from backend — never trust client-only toggles for paid features.
class UserEntitlementsModel {
  final bool tippyAi;
  final bool crossPosting;
  final bool advancedAnalytics;
  final bool advancedPlanner;
  final bool premiumMissionTracks;

  const UserEntitlementsModel({
    this.tippyAi = false,
    this.crossPosting = false,
    this.advancedAnalytics = false,
    this.advancedPlanner = false,
    this.premiumMissionTracks = false,
  });

  factory UserEntitlementsModel.fromFirestoreMap(Map<String, dynamic>? raw) {
    if (raw == null || raw.isEmpty) {
      return const UserEntitlementsModel();
    }
    final Map<String, dynamic> m = Map<String, dynamic>.from(raw);
    bool read(String k) {
      final Object? v = m[k];
      if (v is bool) {
        return v;
      }
      return false;
    }

    bool readTippyEnabled() {
      final Object? v = m['tippyAi'] ?? m['tippy_ai'];
      if (v is bool) {
        return v;
      }
      if (v is Map<String, dynamic>) {
        final Object? en = v['enabled'];
        if (en is bool) {
          return en;
        }
        final Object? plan = v['plan'] ?? v['tier'];
        if (plan is String && plan.trim().isNotEmpty) {
          return true;
        }
      }
      return false;
    }

    return UserEntitlementsModel(
      tippyAi: readTippyEnabled(),
      crossPosting: read('crossPosting') || read('cross_posting'),
      advancedAnalytics:
          read('advancedAnalytics') || read('advanced_analytics'),
      advancedPlanner: read('advancedPlanner') || read('advanced_planner'),
      premiumMissionTracks:
          read('premiumMissionTracks') || read('premium_mission_tracks'),
    );
  }
}
