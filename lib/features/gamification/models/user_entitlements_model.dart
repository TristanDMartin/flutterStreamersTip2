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
    bool read(String k) {
      final Object? v = raw[k];
      if (v is bool) return v;
      return false;
    }

    return UserEntitlementsModel(
      tippyAi: read('tippyAi') || read('tippy_ai'),
      crossPosting: read('crossPosting') || read('cross_posting'),
      advancedAnalytics: read('advancedAnalytics') || read('advanced_analytics'),
      advancedPlanner: read('advancedPlanner') || read('advanced_planner'),
      premiumMissionTracks:
          read('premiumMissionTracks') || read('premium_mission_tracks'),
    );
  }
}
