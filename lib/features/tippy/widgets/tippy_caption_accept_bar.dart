import 'package:flutter/material.dart';

import '../../publish/publish_flow_tokens.dart';

/// Accept / Undo bar after Tippy improves a New Post caption.
class TippyCaptionAcceptBar extends StatelessWidget {
  const TippyCaptionAcceptBar({
    super.key,
    required this.onAccept,
    required this.onUndo,
    this.creditsRemaining,
  });

  final VoidCallback onAccept;
  final VoidCallback onUndo;
  final int? creditsRemaining;

  @override
  Widget build(BuildContext context) {
    final String creditsLabel = creditsRemaining == null
        ? 'Tippy improved your caption'
        : 'Tippy improved your caption · $creditsRemaining credits left';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: PublishFlowTokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PublishFlowTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            creditsLabel,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: onUndo,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: PublishFlowTokens.border),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Text('Undo'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: onAccept,
                  style: FilledButton.styleFrom(
                    backgroundColor: PublishFlowTokens.primaryStart,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Text('Accept'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
