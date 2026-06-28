import 'package:flutter/material.dart';

class TippyMemoryEmptyState extends StatelessWidget {
  const TippyMemoryEmptyState({
    super.key,
    this.onUploadTap,
  });

  final VoidCallback? onUploadTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Upload a few clips to unlock personalized coaching',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'After 3 uploads, Tippy learns your niche, cadence, and what hooks work.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
          if (onUploadTap != null) ...<Widget>[
            const SizedBox(height: 10),
            TextButton(onPressed: onUploadTap, child: const Text('Create a post')),
          ],
        ],
      ),
    );
  }
}
