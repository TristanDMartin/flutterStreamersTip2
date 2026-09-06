import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Phase 1J.6 — light success haptics / motion only. Never blocks lifecycle.
bool tippyMotionAllowed(BuildContext context) {
  return !MediaQuery.disableAnimationsOf(context);
}

Duration tippyStageTransitionDuration(BuildContext context) {
  return tippyMotionAllowed(context)
      ? const Duration(milliseconds: 180)
      : Duration.zero;
}

void tippySuccessHaptic(BuildContext context) {
  if (!tippyMotionAllowed(context)) {
    return;
  }
  HapticFeedback.lightImpact();
}

void tippyConfirmHaptic(BuildContext context) {
  if (!tippyMotionAllowed(context)) {
    return;
  }
  HapticFeedback.selectionClick();
}
