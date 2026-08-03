import 'package:flutter/material.dart';

import 'threads_contract.dart';
import 'threads_models.dart';

/// Compact Conversation Pulse meter shown under thread body.
class ConversationPulseCard extends StatefulWidget {
  const ConversationPulseCard({
    super.key,
    required this.thread,
  });

  final ThreadDto thread;

  @override
  State<ConversationPulseCard> createState() => _ConversationPulseCardState();
}

class _ConversationPulseCardState extends State<ConversationPulseCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  bool get _isHot {
    final String state = normalizeMomentumState(widget.thread.momentumState);
    return state == 'active_now' || state == 'trending';
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    if (_isHot) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant ConversationPulseCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isHot && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!_isHot && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final ThreadDto thread = widget.thread;
    final double fill = conversationPulseFill(thread.momentumState);
    final Color accent = conversationPulseColor(thread.momentumState);
    final String label = momentumLabel(thread.momentumState);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          final double glow = _isHot ? 0.18 + (_controller.value * 0.28) : 0.0;
          return Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 168),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        'Pulse',
                        style: TextStyle(
                          color: scheme.onSurface.withValues(alpha: 0.45),
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: accent.withValues(alpha: 0.95),
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: _isHot
                          ? <BoxShadow>[
                              BoxShadow(
                                color: accent.withValues(alpha: glow),
                                blurRadius: 10 + (_controller.value * 8),
                                spreadRadius: 0.5,
                              ),
                            ]
                          : null,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: SizedBox(
                        height: 4,
                        width: double.infinity,
                        child: Stack(
                          children: <Widget>[
                            Container(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                        FractionallySizedBox(
                          widthFactor: fill,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: <Color>[
                                  accent.withValues(alpha: 0.75),
                                  accent,
                                  Color.lerp(accent, Colors.white, 0.35)!,
                                ],
                              ),
                            ),
                          ),
                        ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${thread.helpfulCount} helpful · ${thread.replyCount} replies',
                    style: TextStyle(
                      color: scheme.onSurface.withValues(alpha: 0.4),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_isHot) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      conversationPulseFeedback(thread),
                      style: TextStyle(
                        color: accent.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

double conversationPulseFill(String momentumState) {
  switch (normalizeMomentumState(momentumState)) {
    case 'active_now':
      return 0.92;
    case 'trending':
      return 0.74;
    case 'picking_up':
      return 0.48;
    case 'resolved':
      return 1.0;
    case 'new':
    default:
      return 0.18;
  }
}

Color conversationPulseColor(String momentumState) {
  switch (normalizeMomentumState(momentumState)) {
    case 'active_now':
      return const Color(0xFFFF5C1A);
    case 'trending':
      return const Color(0xFFFFC107);
    case 'picking_up':
      return const Color(0xFF5B8CFF);
    case 'resolved':
      return const Color(0xFF22F5A5);
    case 'new':
    default:
      return const Color(0xFFA8B8D8);
  }
}

String conversationPulseFeedback(ThreadDto thread) {
  switch (normalizeMomentumState(thread.momentumState)) {
    case 'active_now':
      return 'Live — most engaged right now.';
    case 'trending':
      return 'Heating up — high engagement.';
    case 'picking_up':
      return 'Warming up.';
    case 'resolved':
      return 'Resolved.';
    case 'new':
    default:
      if (thread.replyCount == 0) {
        return 'Just started.';
      }
      return 'Building momentum.';
  }
}
