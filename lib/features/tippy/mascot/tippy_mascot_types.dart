/// Replaceable Tippy mascot presentation states.
/// Onboarding logic must not depend on artwork implementation.
enum TippyMascotState {
  idle,
  enter,
  blink,
  bounce,
  wave,
  reactPositive,
  celebrate,
  thinking,
  speaking,
}

/// Which concrete presentation to render behind [TippyMascot].
enum TippyMascotImplementation {
  codeDrawn,
  staticAsset,
  animatedAsset,
  futureRive,
}
