import 'package:flutter/material.dart';

class XpPopAnimation extends StatefulWidget {
  const XpPopAnimation({
    super.key,
    required this.xpAmount,
    required this.onComplete,
  });

  final String xpAmount;
  final VoidCallback onComplete;

  static OverlayEntry show({
    required BuildContext context,
    required String xpAmount,
    required VoidCallback onComplete,
  }) {
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (BuildContext context) {
        return XpPopAnimation(
          xpAmount: xpAmount,
          onComplete: () {
            entry.remove();
            onComplete();
          },
        );
      },
    );
    Overlay.of(context).insert(entry);
    return entry;
  }

  @override
  State<XpPopAnimation> createState() => _XpPopAnimationState();
}

class _XpPopAnimationState extends State<XpPopAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _opacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _slide = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -0.12),
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward().whenComplete(widget.onComplete);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Material(
        color: Colors.transparent,
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (BuildContext context, Widget? child) {
              return Opacity(
                opacity: _opacity.value,
                child: SlideTransition(
                  position: _slide,
                  child: child,
                ),
              );
            },
            child: Text(
              widget.xpAmount,
              style: const TextStyle(
                color: Color(0xFF00F5A0),
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
