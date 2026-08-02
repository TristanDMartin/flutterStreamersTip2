import 'package:flutter/material.dart';

import 'code_drawn_tippy.dart';
import 'tippy_mascot_types.dart';

/// Interchangeable Tippy presentation layer.
/// Onboarding must only depend on this facade + [TippyMascotState].
class TippyMascot extends StatelessWidget {
  const TippyMascot({
    super.key,
    this.state = TippyMascotState.idle,
    this.size = 160,
    this.implementation = TippyMascotImplementation.staticAsset,
    this.reducedMotion,
  });

  final TippyMascotState state;
  final double size;
  final TippyMascotImplementation implementation;
  final bool? reducedMotion;

  @override
  Widget build(BuildContext context) {
    final bool reduce = reducedMotion ??
        MediaQuery.disableAnimationsOf(context) ||
            WidgetsBinding.instance.platformDispatcher.accessibilityFeatures
                .reduceMotion;
    switch (implementation) {
      case TippyMascotImplementation.codeDrawn:
      case TippyMascotImplementation.staticAsset:
      case TippyMascotImplementation.animatedAsset:
      case TippyMascotImplementation.futureRive:
        // Logo stand-in until production Tippy / Rive assets land.
        return CodeDrawnTippy(
          state: state,
          size: size,
          reducedMotion: reduce,
        );
    }
  }
}
