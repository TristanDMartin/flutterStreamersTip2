import 'package:flutter/material.dart';

import '../models/tippy_ui_payload.dart';

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
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            data.memoryReady ? 'Tippy knows you' : 'Building your profile',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: chips,
          ),
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
            ? const Color(0xFF1D4ED8).withValues(alpha: 0.35)
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: accent
              ? const Color(0xFF93C5FD).withValues(alpha: 0.45)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
