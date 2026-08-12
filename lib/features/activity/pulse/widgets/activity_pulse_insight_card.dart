import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/support_shell_style.dart';
import '../activity_pulse_logic.dart';
import '../activity_pulse_tokens.dart';

class ActivityPulseInsightCard extends StatefulWidget {
  const ActivityPulseInsightCard({
    super.key,
    required this.insight,
    this.onTap,
  });

  final ActivityPulseInsight insight;
  final VoidCallback? onTap;

  @override
  State<ActivityPulseInsightCard> createState() =>
      _ActivityPulseInsightCardState();
}

class _ActivityPulseInsightCardState extends State<ActivityPulseInsightCard> {
  double _scale = 1;

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final Color glow = ActivityPulseTokens.accentColor(widget.insight.accent);
    final bool isAction =
        widget.insight.accent == ActivityPulseAccent.action;
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.98),
      onTapUp: (_) => setState(() => _scale = 1),
      onTapCancel: () => setState(() => _scale = 1),
      onTap: widget.onTap == null
          ? null
          : () {
              HapticFeedback.lightImpact();
              widget.onTap!();
            },
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(
            color: shell.surfaceCard,
            gradient: isAction
                ? null
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      glow.withValues(alpha: 0.14),
                      shell.surfaceCard,
                    ],
                  ),
            borderRadius: BorderRadius.circular(isAction ? 16 : 18),
            border: Border.all(
              color: isAction
                  ? shell.surfaceCardBorder
                  : glow.withValues(alpha: 0.35),
            ),
            boxShadow: isAction
                ? null
                : <BoxShadow>[
                    BoxShadow(
                      color: glow.withValues(alpha: 0.14),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (isAction)
                  Container(
                    width: 3,
                    color: glow,
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        if (isAction)
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: glow.withValues(alpha: 0.15),
                            ),
                            child: Icon(
                              Icons.checklist_rounded,
                              size: 18,
                              color: glow,
                            ),
                          )
                        else
                          Text(
                            widget.insight.emoji,
                            style: const TextStyle(fontSize: 26),
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                widget.insight.title,
                                style: TextStyle(
                                  color: shell.onChrome,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.insight.body,
                                style: TextStyle(
                                  color: shell.muted,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
