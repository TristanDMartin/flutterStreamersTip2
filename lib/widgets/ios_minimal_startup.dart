import 'package:flutter/material.dart';

/// Minimal startup wrapper for iOS
/// Shows child immediately - no delays or white screen
class IOSMinimalStartup extends StatelessWidget {
  final Widget child;

  const IOSMinimalStartup({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // Always show child immediately - no delay
    // The splash screen is handled by AppStartupWrapper
    return child;
  }
}
