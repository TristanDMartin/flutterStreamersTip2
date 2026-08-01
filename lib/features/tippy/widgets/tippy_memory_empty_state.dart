import 'package:flutter/material.dart';

import '../tippy_chat_tokens.dart';

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
        color: TippyChatTokens.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: TippyChatTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Upload a few clips to unlock personalized coaching',
            style: TippyChatTokens.nunito(
              size: 13,
              weight: FontWeight.w700,
              color: TippyChatTokens.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'After 3 uploads, Tippy learns your niche, cadence, and what hooks work.',
            style: TippyChatTokens.nunito(
              size: 12,
              color: TippyChatTokens.textSecondary,
              height: 1.4,
            ),
          ),
          if (onUploadTap != null) ...<Widget>[
            const SizedBox(height: 10),
            TextButton(
              onPressed: onUploadTap,
              style: TextButton.styleFrom(
                foregroundColor: TippyChatTokens.chipText,
              ),
              child: const Text('Create a post'),
            ),
          ],
        ],
      ),
    );
  }
}
