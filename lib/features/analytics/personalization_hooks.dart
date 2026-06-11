import '../../shared/analytics/analytics_event_constants.dart';
import 'models/analytics_profile.dart';

/// Foundation hooks for personalization from [AnalyticsProfile].
abstract class AnalyticsPersonalizationHooks {
  const AnalyticsPersonalizationHooks();

  List<String> recommendVideoIds(AnalyticsProfile profile);

  List<String> recommendGuideSlugs(AnalyticsProfile profile);

  List<String> recommendCourseIds(AnalyticsProfile profile);

  List<String> recommendToolIds(AnalyticsProfile profile);

  List<String> recommendTippyPrompts(AnalyticsProfile profile);
}

class DefaultAnalyticsPersonalizationHooks extends AnalyticsPersonalizationHooks {
  const DefaultAnalyticsPersonalizationHooks();

  @override
  List<String> recommendVideoIds(AnalyticsProfile profile) {
    if (profile.favoriteCategories.isEmpty) {
      return <String>[];
    }
    return <String>[];
  }

  @override
  List<String> recommendGuideSlugs(AnalyticsProfile profile) {
    final List<String> out = <String>[];
    if (profile.preferredContentType == AnalyticsTargetTypes.guide) {
      out.add('growth-basics');
    }
    for (final String category in profile.favoriteCategories.keys.take(2)) {
      out.add('guide-$category');
    }
    return out;
  }

  @override
  List<String> recommendCourseIds(AnalyticsProfile profile) {
    if (profile.creatorStage == 'beginner') {
      return <String>['creator-fundamentals'];
    }
    return <String>[];
  }

  @override
  List<String> recommendToolIds(AnalyticsProfile profile) {
    final List<String> tools = <String>['content-planner', 'ask-tippy'];
    if (profile.creatorStage == 'established') {
      tools.add('growth-analytics');
    }
    return tools;
  }

  @override
  List<String> recommendTippyPrompts(AnalyticsProfile profile) {
    if (profile.recommendedNextActions.isNotEmpty) {
      return profile.recommendedNextActions
          .map((String action) => 'Help me: $action')
          .take(3)
          .toList();
    }
    return <String>[
      'What should I post this week based on my goals?',
      'How can I improve watch time on my latest clips?',
    ];
  }
}

const DefaultAnalyticsPersonalizationHooks kDefaultPersonalizationHooks =
    DefaultAnalyticsPersonalizationHooks();
