import 'package:flutter/material.dart';

/// Previously gated Firestore progression listeners behind mount lifecycle.
///
/// Phase 1J.5: [userProgressBundleProvider] listens only when
/// [authenticatedAppShellReadyProvider] is true (ACTIVATED / app route).
/// This widget remains a no-op wrapper for call sites that still wrap their child.
class ProgressionSubscriptionScope extends StatelessWidget {
  const ProgressionSubscriptionScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
