import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Compact follower line: "0 followers", "12 followers", "1.2K followers".
class FollowerCountText extends StatelessWidget {
  const FollowerCountText({
    super.key,
    required this.count,
    required this.color,
  });

  final int count;
  final Color color;

  static String formatCompactFollowers(int raw) {
    final int n = math.max(0, raw);
    if (n >= 1000000) {
      return '${(n / 1000000).toStringAsFixed(1)}M followers';
    }
    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(1)}K followers';
    }
    return '$n followers';
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      formatCompactFollowers(count),
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        height: 1.15,
      ),
    );
  }
}
