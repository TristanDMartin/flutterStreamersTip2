import 'package:flutter/material.dart';

class TrendingCreatorSkeleton extends StatelessWidget {
  const TrendingCreatorSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color base = dark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFF0F172A).withValues(alpha: 0.07);
    final Color card = dark
        ? const Color(0xFF0F172A).withValues(alpha: 0.72)
        : Colors.white.withValues(alpha: 0.94);
    final Color border = dark
        ? Colors.white.withValues(alpha: 0.10)
        : const Color(0xFF0F172A).withValues(alpha: 0.08);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.20 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: base,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            height: 10,
            width: 72,
            decoration: BoxDecoration(
              color: base,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 8,
            width: 52,
            decoration: BoxDecoration(
              color: base,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 8,
            width: 64,
            decoration: BoxDecoration(
              color: base,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          const Spacer(),
          Container(
            height: 30,
            width: double.infinity,
            decoration: BoxDecoration(
              color: base,
              borderRadius: BorderRadius.circular(15),
            ),
          ),
        ],
      ),
    );
  }
}
