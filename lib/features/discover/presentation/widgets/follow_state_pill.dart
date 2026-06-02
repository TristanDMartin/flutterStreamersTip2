import 'package:flutter/material.dart';

/// Deprecated for Trending Creators. Follow actions now live on profiles.
class FollowStatePill extends StatelessWidget {
  const FollowStatePill({
    super.key,
    required this.isConnected,
    required this.isLoading,
    required this.isDark,
    required this.onFollowTap,
    required this.onConnectedTap,
  });

  final bool isConnected;
  final bool isLoading;
  final bool isDark;
  final VoidCallback onFollowTap;
  final VoidCallback onConnectedTap;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
