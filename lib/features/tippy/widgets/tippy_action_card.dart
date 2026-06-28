import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/tippy_ui_payload.dart';

class TippyActionCard extends StatelessWidget {
  const TippyActionCard({
    super.key,
    required this.card,
    this.onDeepLink,
    this.onPrefillPrompt,
    this.onApproveSchedule,
  });

  final TippyUiCardData card;
  final void Function(String value)? onDeepLink;
  final void Function(String value)? onPrefillPrompt;
  final void Function(TippyUiCardData card)? onApproveSchedule;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            card.title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          if (card.body.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              card.body,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ],
          if (card.ctaLabel != null && card.ctaLabel!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => _handleCta(context),
                  child: Text(card.ctaLabel!),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _handleCta(BuildContext context) {
    final String? action = card.ctaAction;
    final String? value = card.ctaValue;
    if (action == null || value == null || value.isEmpty) {
      return;
    }
    if (action == 'copy_text') {
      Clipboard.setData(ClipboardData(text: value));
      return;
    }
    if (action == 'deep_link') {
      onDeepLink?.call(value);
      return;
    }
    if (action == 'prefill_prompt') {
      onPrefillPrompt?.call(value);
      return;
    }
    if (action == 'approve_schedule') {
      onApproveSchedule?.call(card);
    }
  }
}
