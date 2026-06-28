import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/design/st_system_ui.dart';
import '../onboarding_style.dart';

/// Paints [backgroundColor] edge-to-edge; pads [child] with system insets.
class OnboardingScreenLayout extends StatelessWidget {
  const OnboardingScreenLayout({
    super.key,
    required this.child,
    this.backgroundColor = OnboardingStyle.background,
    this.decoration,
  });

  final Widget child;
  final Color backgroundColor;
  final BoxDecoration? decoration;

  @override
  Widget build(BuildContext context) {
    final EdgeInsets insets = MediaQuery.paddingOf(context);
    return DecoratedBox(
      decoration: decoration ?? BoxDecoration(color: backgroundColor),
      child: SizedBox.expand(
        child: Padding(
          padding: EdgeInsets.only(
            top: insets.top,
            left: insets.left,
            right: insets.right,
            bottom: insets.bottom,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Edge-to-edge onboarding chrome — fills the viewport and paints behind
/// the status bar / home indicator.
class OnboardingFullScreenShell extends StatefulWidget {
  const OnboardingFullScreenShell({
    super.key,
    required this.child,
    this.backgroundColor = OnboardingStyle.background,
  });

  final Widget child;
  final Color backgroundColor;

  @override
  State<OnboardingFullScreenShell> createState() =>
      _OnboardingFullScreenShellState();
}

class _OnboardingFullScreenShellState extends State<OnboardingFullScreenShell> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(OnboardingStyle.immersiveSystemUi);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    STSystemUi.configureDefault();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: OnboardingStyle.immersiveSystemUi,
      child: Material(
        color: widget.backgroundColor,
        child: SizedBox.expand(child: widget.child),
      ),
    );
  }
}
