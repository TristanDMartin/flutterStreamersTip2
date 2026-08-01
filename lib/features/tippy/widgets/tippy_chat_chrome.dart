import 'package:flutter/material.dart';

import '../tippy_chat_tokens.dart';

class TippyChatAtmosphere extends StatelessWidget {
  const TippyChatAtmosphere({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: TippyChatTokens.bg,
        gradient: RadialGradient(
          center: Alignment(0, -1.05),
          radius: 1.15,
          colors: <Color>[
            Color(0x386633CC),
            TippyChatTokens.bg,
          ],
          stops: <double>[0, 0.62],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.95, -0.55),
                radius: 0.85,
                colors: <Color>[
                  Color(0x1A3B82F6),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class TippyMark extends StatelessWidget {
  const TippyMark({
    super.key,
    this.size = 24,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.32),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            TippyChatTokens.accent,
            TippyChatTokens.accent2,
          ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: TippyChatTokens.accent.withValues(alpha: 0.28),
            blurRadius: size * 0.45,
            offset: Offset(0, size * 0.12),
          ),
        ],
      ),
      child: Icon(
        Icons.auto_awesome_rounded,
        color: Colors.white,
        size: size * 0.52,
      ),
    );
  }
}

class TippyIconButton extends StatelessWidget {
  const TippyIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final Widget button = Material(
      color: TippyChatTokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: TippyChatTokens.border),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(
            icon,
            size: 14,
            color: TippyChatTokens.textSecondary,
          ),
        ),
      ),
    );
    if (tooltip == null) {
      return button;
    }
    return Tooltip(message: tooltip!, child: button);
  }
}

class TippyCreditsPill extends StatelessWidget {
  const TippyCreditsPill({
    super.key,
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: TippyChatTokens.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: TippyChatTokens.border),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TippyChatTokens.nunito(
          size: 11,
          color: TippyChatTokens.textSecondary,
          weight: FontWeight.w600,
        ),
      ),
    );
  }
}

class TippyThinkingDots extends StatefulWidget {
  const TippyThinkingDots({super.key});

  @override
  State<TippyThinkingDots> createState() => _TippyThinkingDotsState();
}

class _TippyThinkingDotsState extends State<TippyThinkingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List<Widget>.generate(3, (int i) {
            final double phase = (_controller.value + i * 0.15) % 1.0;
            final double t = phase < 0.4
                ? (phase / 0.4)
                : phase < 0.8
                    ? ((0.8 - phase) / 0.4)
                    : 0;
            return Padding(
              padding: EdgeInsets.only(right: i == 2 ? 0 : 6),
              child: Transform.translate(
                offset: Offset(0, -3 * t),
                child: Opacity(
                  opacity: 0.35 + (0.65 * t),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: TippyChatTokens.softLavender,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class TippyStarterCard extends StatefulWidget {
  const TippyStarterCard({
    super.key,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  State<TippyStarterCard> createState() => _TippyStarterCardState();
}

class _TippyStarterCardState extends State<TippyStarterCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
        child: Material(
          color: _hovered
              ? TippyChatTokens.focus.withValues(alpha: 0.12)
              : TippyChatTokens.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: _hovered
                  ? TippyChatTokens.focus.withValues(alpha: 0.55)
                  : TippyChatTokens.border,
            ),
          ),
          child: InkWell(
            onTap: widget.enabled ? widget.onTap : null,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.label,
                  style: TippyChatTokens.nunito(
                    size: 13,
                    color: const Color(0xFFCBD5E1),
                    weight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TippyAccentChip extends StatelessWidget {
  const TippyAccentChip({
    super.key,
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.accent = true,
  });

  final String label;
  final VoidCallback? onTap;
  final bool enabled;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: accent
          ? TippyChatTokens.accent.withValues(alpha: 0.22)
          : TippyChatTokens.surface,
      shape: StadiumBorder(
        side: BorderSide(
          color: accent
              ? TippyChatTokens.focus.withValues(alpha: 0.45)
              : TippyChatTokens.border,
        ),
      ),
      child: InkWell(
        onTap: enabled ? onTap : null,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(
            label,
            style: TippyChatTokens.nunito(
              size: 11,
              weight: FontWeight.w700,
              color: accent
                  ? TippyChatTokens.chipText
                  : TippyChatTokens.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class TippyEmptyState extends StatelessWidget {
  const TippyEmptyState({
    super.key,
    required this.greeting,
    required this.starters,
    required this.onStarter,
    required this.onCaption,
    required this.onGeneratePlan,
    this.busy = false,
    this.footer,
  });

  final String greeting;
  final List<String> starters;
  final ValueChanged<String> onStarter;
  final VoidCallback onCaption;
  final VoidCallback onGeneratePlan;
  final bool busy;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        children: <Widget>[
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            width: double.infinity,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: TippyChatTokens.accent.withValues(alpha: 0.25),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: TippyChatTokens.accent.withValues(alpha: 0.25),
                        blurRadius: 64,
                      ),
                    ],
                  ),
                ),
                const TippyMark(size: 48),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            greeting,
            textAlign: TextAlign.center,
            style: TippyChatTokens.nunito(
              size: 13,
              color: TippyChatTokens.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            TippyChatTokens.emptyTitle,
            textAlign: TextAlign.center,
            style: TippyChatTokens.nunito(
              size: 20,
              weight: FontWeight.w800,
              color: TippyChatTokens.textPrimary,
              letterSpacing: -0.3,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            TippyChatTokens.emptySubtitle,
            textAlign: TextAlign.center,
            style: TippyChatTokens.nunito(
              size: 12,
              color: TippyChatTokens.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          for (final String starter in starters.take(4)) ...<Widget>[
            TippyStarterCard(
              label: starter,
              enabled: !busy,
              onTap: () => onStarter(starter),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: <Widget>[
              TippyAccentChip(
                label: 'AI Caption',
                enabled: !busy,
                onTap: onCaption,
              ),
              TippyAccentChip(
                label: 'Generate plan',
                enabled: !busy,
                onTap: onGeneratePlan,
              ),
            ],
          ),
          if (footer != null) ...<Widget>[
            const SizedBox(height: 16),
            footer!,
          ],
        ],
      ),
    );
  }
}

class TippyComposerShell extends StatefulWidget {
  const TippyComposerShell({
    super.key,
    required this.controller,
    required this.onSend,
    required this.enabled,
    this.hintText = 'Ask Tippy anything…',
    this.chips,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool enabled;
  final String hintText;
  final Widget? chips;

  @override
  State<TippyComposerShell> createState() => _TippyComposerShellState();
}

class _TippyComposerShellState extends State<TippyComposerShell> {
  late final FocusNode _focusNode = FocusNode();

  bool get _canSend =>
      widget.enabled && widget.controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(covariant TippyComposerShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
    }
  }

  void _onTextChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool focused = _focusNode.hasFocus;
    final bool canSend = _canSend;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (widget.chips != null) ...<Widget>[
            widget.chips!,
            const SizedBox(height: 8),
          ],
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
            decoration: BoxDecoration(
              color: TippyChatTokens.composer,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: focused
                    ? TippyChatTokens.focus.withValues(alpha: 0.45)
                    : TippyChatTokens.border,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
                if (focused)
                  BoxShadow(
                    color: TippyChatTokens.focus.withValues(alpha: 0.18),
                    blurRadius: 0,
                    spreadRadius: 1,
                  ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    enabled: widget.enabled,
                    minLines: 1,
                    maxLines: 5,
                    style: TippyChatTokens.nunito(
                      size: 13,
                      color: TippyChatTokens.textBody,
                      height: 1.4,
                    ),
                    decoration: InputDecoration(
                      hintText: widget.hintText,
                      hintStyle: TippyChatTokens.nunito(
                        size: 13,
                        color: TippyChatTokens.textPlaceholder,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) {
                      if (canSend) {
                        widget.onSend();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  key: const Key('tippy-send'),
                  onPressed: canSend ? widget.onSend : null,
                  tooltip: 'Send message',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 36,
                    height: 36,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    disabledBackgroundColor:
                        Colors.white.withValues(alpha: 0.08),
                    foregroundColor: Colors.white,
                    disabledForegroundColor:
                        Colors.white.withValues(alpha: 0.35),
                  ),
                  icon: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: canSend
                          ? const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: <Color>[
                                TippyChatTokens.accent,
                                TippyChatTokens.accent2,
                              ],
                            )
                          : null,
                      color: canSend
                          ? null
                          : Colors.white.withValues(alpha: 0.08),
                    ),
                    child: const SizedBox(
                      width: 36,
                      height: 36,
                      child: Icon(
                        Icons.arrow_upward_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
