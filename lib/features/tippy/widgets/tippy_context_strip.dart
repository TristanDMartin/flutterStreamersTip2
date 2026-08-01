import 'package:flutter/material.dart';

import '../models/tippy_ui_payload.dart';
import '../tippy_chat_tokens.dart';

class TippyContextStrip extends StatelessWidget {
  const TippyContextStrip({
    super.key,
    required this.data,
  });

  final TippyContextStripData data;

  @override
  Widget build(BuildContext context) {
    if (!data.hasContent && !data.memoryReady) {
      return const SizedBox.shrink();
    }
    final List<Widget> chips = <Widget>[];
    if (data.nicheLabel != null && data.nicheLabel!.isNotEmpty) {
      chips.add(_ChipLabel(text: data.nicheLabel!));
    }
    if (data.cadenceLabel != null && data.cadenceLabel!.isNotEmpty) {
      chips.add(_ChipLabel(text: data.cadenceLabel!));
    }
    if (data.topGoalLabel != null && data.topGoalLabel!.isNotEmpty) {
      chips.add(_ChipLabel(text: data.topGoalLabel!, accent: true));
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: TippyChatTokens.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TippyChatTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            data.memoryReady ? 'Tippy knows you' : 'Building your profile',
            style: TippyChatTokens.nunito(
              size: 11,
              weight: FontWeight.w700,
              color: TippyChatTokens.textSecondary,
              letterSpacing: 0.4,
            ),
          ),
          if (chips.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: chips,
            ),
          ],
        ],
      ),
    );
  }
}

class _ChipLabel extends StatelessWidget {
  const _ChipLabel({
    required this.text,
    this.accent = false,
  });

  final String text;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent
            ? TippyChatTokens.accent.withValues(alpha: 0.22)
            : TippyChatTokens.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: accent
              ? TippyChatTokens.focus.withValues(alpha: 0.45)
              : TippyChatTokens.border,
        ),
      ),
      child: Text(
        text,
        style: TippyChatTokens.nunito(
          size: 11,
          weight: FontWeight.w700,
          color: accent
              ? TippyChatTokens.chipText
              : TippyChatTokens.textSecondary,
        ),
      ),
    );
  }
}
