/// Whether liking a video emits Worker gamification / progression side effects.
///
/// Keep `false` until `…/gamification/events` is deployed; avoids 404 noise and
/// extra async work on the like hot path.
abstract final class GamificationLikeEventsPolicy {
  static const bool emitOnLike = false;
}
