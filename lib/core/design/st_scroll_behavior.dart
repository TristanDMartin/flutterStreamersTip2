import 'package:flutter/material.dart';

/// Same scroll feel on Android and iOS (TikTok‑style bounce everywhere).
class STScrollBehavior extends MaterialScrollBehavior {
  const STScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    );
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
