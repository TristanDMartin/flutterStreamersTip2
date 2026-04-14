import 'mission_template.dart';
import 'mission_templates_config.dart';

/// Maps event `type` strings to mission template ids (for analytics / client hints).
/// Authoritative progress is computed server-side.
class MissionEventRegistry {
  MissionEventRegistry._();

  static final Map<String, Set<String>> _eventToTemplateIds =
      _buildEventToTemplateIds();

  static Map<String, Set<String>> _buildEventToTemplateIds() {
    final Map<String, Set<String>> map = <String, Set<String>>{};
    for (final MissionTemplate t in MissionTemplatesConfig.all) {
      for (final String key in t.progressEventKeys) {
        map.putIfAbsent(key, () => <String>{}).add(t.templateId);
      }
    }
    return map;
  }

  static Set<String> templateIdsForEvent(String eventType) {
    return _eventToTemplateIds[eventType] ?? <String>{};
  }

  static bool eventAdvancesAnyMission(String eventType) {
    return _eventToTemplateIds.containsKey(eventType);
  }
}
