import '../gamification/gamification_event_types.dart';
import 'threads_contract.dart';

/// Maps Threads v2 contract gamification keys onto app event type strings.
class ThreadsGamification {
  const ThreadsGamification._();

  static String get threadCreated =>
      kGamificationEvents['threadCreated'] ??
      GamificationEventTypes.contentThreadCreated;

  static String get threadParticipated =>
      kGamificationEvents['threadParticipated'] ??
      'community.thread_participated';

  static String get helpfulReactionReceived =>
      kGamificationEvents['helpfulReactionReceived'] ??
      'community.helpful_reaction_received';

  static String get answerMarkedHelpful =>
      kGamificationEvents['answerMarkedHelpful'] ??
      'community.answer_marked_helpful';

  static String get unansweredHelped =>
      kGamificationEvents['unansweredHelped'] ??
      'community.unanswered_helped';

  static const List<String> reputationLabels = <String>[
    'helpful_voice',
    'growth_contributor',
    'setup_specialist',
    'feedback_regular',
    'community_builder',
    'collaboration_starter',
  ];
}
