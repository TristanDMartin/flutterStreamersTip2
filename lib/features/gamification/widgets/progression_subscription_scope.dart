import 'package:flutter/material.dart';

/// Previously gated Firestore progression listeners behind mount lifecycle.
///
/// That gate was removed: [userProgressBundleProvider] always listens while
/// signed in so app Progression matches website Mission Control. This widget
/// remains a no-op wrapper for call sites that still wrap their child.
class ProgressionSubscriptionScope extends StatelessWidget {
  const ProgressionSubscriptionScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
