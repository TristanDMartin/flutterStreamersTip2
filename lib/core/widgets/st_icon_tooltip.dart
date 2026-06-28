import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Icon-only control with tooltip (desktop/web) and long-press hint (mobile).
class StIconTooltip extends StatelessWidget {
  const StIconTooltip({
    super.key,
    required this.message,
    required this.icon,
    this.onPressed,
    this.color,
    this.iconSize,
    this.padding,
    this.constraints,
    this.enabled = true,
  });

  final String message;
  final Widget icon;
  final VoidCallback? onPressed;
  final Color? color;
  final double? iconSize;
  final EdgeInsetsGeometry? padding;
  final BoxConstraints? constraints;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final Widget button = IconButton(
      tooltip: message,
      onPressed: enabled ? onPressed : null,
      icon: icon,
      color: color,
      iconSize: iconSize,
      padding: padding ?? EdgeInsets.zero,
      constraints: constraints,
    );
    return Semantics(
      label: message,
      button: true,
      enabled: enabled,
      child: _LongPressHint(
        message: message,
        child: button,
      ),
    );
  }
}

class _LongPressHint extends StatefulWidget {
  const _LongPressHint({
    required this.message,
    required this.child,
  });

  final String message;
  final Widget child;

  @override
  State<_LongPressHint> createState() => _LongPressHintState();
}

class _LongPressHintState extends State<_LongPressHint> {
  OverlayEntry? _entry;

  @override
  void dispose() {
    _removeHint();
    super.dispose();
  }

  void _removeHint() {
    _entry?.remove();
    _entry = null;
  }

  void _showHint(LongPressStartDetails details) {
    if (_entry != null) {
      return;
    }
    HapticFeedback.lightImpact();
    final OverlayState overlay = Overlay.of(context);
    final RenderBox box = context.findRenderObject()! as RenderBox;
    final Offset origin = box.localToGlobal(Offset.zero);
    _entry = OverlayEntry(
      builder: (BuildContext context) {
        return Positioned(
          left: origin.dx.clamp(8.0, MediaQuery.sizeOf(context).width - 160),
          top: (origin.dy - 36).clamp(8.0, MediaQuery.sizeOf(context).height),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        );
      },
    );
    overlay.insert(_entry!);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPressStart: _showHint,
      onLongPressEnd: (_) => _removeHint(),
      onLongPressCancel: _removeHint,
      child: widget.child,
    );
  }
}
