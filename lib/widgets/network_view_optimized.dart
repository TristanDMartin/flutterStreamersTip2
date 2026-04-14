import 'package:flutter/material.dart';

import 'network_view.dart';

/// Compatibility wrapper while the app migrates to the canonical NetworkView.
class NetworkViewOptimized extends StatelessWidget {
  const NetworkViewOptimized({super.key});

  @override
  Widget build(BuildContext context) {
    return const NetworkView();
  }
}
