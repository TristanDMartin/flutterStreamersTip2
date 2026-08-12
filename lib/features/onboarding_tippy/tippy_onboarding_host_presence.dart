/// Tracks whether a [TippyOnboardingView] is already mounted so
/// [OnboardingGate] does not stack a second Tippy funnel.
abstract final class TippyOnboardingHostPresence {
  static int _depth = 0;

  static bool get isActive => _depth > 0;

  static void enter() {
    _depth += 1;
  }

  static void leave() {
    if (_depth > 0) {
      _depth -= 1;
    }
  }
}
