import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'tippy_mascot_types.dart';

/// Logo-based Tippy stand-in until production Tippy mascot assets land.
class CodeDrawnTippy extends StatefulWidget {
  const CodeDrawnTippy({
    super.key,
    required this.state,
    this.size = 160,
    this.reducedMotion = false,
  });

  final TippyMascotState state;
  final double size;
  final bool reducedMotion;

  @override
  State<CodeDrawnTippy> createState() => _CodeDrawnTippyState();
}

class _CodeDrawnTippyState extends State<CodeDrawnTippy>
    with TickerProviderStateMixin {
  late final AnimationController _idleController;
  late final AnimationController _actionController;
  late final Animation<double> _idleBob;
  late final Animation<double> _action;

  @override
  void initState() {
    super.initState();
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );
    _actionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _idleBob = Tween<double>(begin: -3, end: 3).animate(
      CurvedAnimation(parent: _idleController, curve: Curves.easeInOut),
    );
    _action = CurvedAnimation(
      parent: _actionController,
      curve: Curves.easeOutBack,
    );
    _startLoops();
    _playState(widget.state);
  }

  @override
  void didUpdateWidget(covariant CodeDrawnTippy oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reducedMotion != widget.reducedMotion) {
      _startLoops();
    }
    if (oldWidget.state != widget.state) {
      _playState(widget.state);
    }
  }

  void _startLoops() {
    _idleController.stop();
    if (widget.reducedMotion) {
      return;
    }
    _idleController.repeat(reverse: true);
  }

  void _playState(TippyMascotState state) {
    if (widget.reducedMotion) {
      _actionController.value = 1;
      return;
    }
    switch (state) {
      case TippyMascotState.enter:
      case TippyMascotState.bounce:
      case TippyMascotState.wave:
      case TippyMascotState.reactPositive:
      case TippyMascotState.celebrate:
        _actionController
          ..reset()
          ..forward();
        break;
      case TippyMascotState.idle:
      case TippyMascotState.blink:
      case TippyMascotState.thinking:
      case TippyMascotState.speaking:
        break;
    }
  }

  @override
  void dispose() {
    _idleController.dispose();
    _actionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(
        <Listenable>[_idleController, _actionController],
      ),
      builder: (BuildContext context, Widget? child) {
        double scale = 1;
        double dy = widget.reducedMotion ? 0 : _idleBob.value;
        double tilt = 0;
        if (!widget.reducedMotion) {
          switch (widget.state) {
            case TippyMascotState.enter:
              scale = 0.88 + (0.12 * _action.value);
              dy = (1 - _action.value) * 24 + _idleBob.value;
              break;
            case TippyMascotState.bounce:
            case TippyMascotState.reactPositive:
              scale = 1 + (0.06 * math.sin(_action.value * math.pi));
              dy = -8 * math.sin(_action.value * math.pi) + _idleBob.value;
              break;
            case TippyMascotState.wave:
              tilt = math.sin(_action.value * math.pi * 2) * 0.08;
              break;
            case TippyMascotState.celebrate:
              scale = 1 + (0.08 * math.sin(_action.value * math.pi * 2));
              dy = -10 * math.sin(_action.value * math.pi) + _idleBob.value;
              break;
            default:
              break;
          }
        } else if (widget.state == TippyMascotState.enter) {
          scale = 0.96 + (0.04 * _action.value);
        }
        return Transform.translate(
          offset: Offset(0, dy),
          child: Transform.rotate(
            angle: tilt,
            child: Transform.scale(
              scale: scale,
              child: child,
            ),
          ),
        );
      },
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: Center(
                child: Image.asset(
                  'assets/logo.png',
                  width: widget.size * 0.78,
                  height: widget.size * 0.78,
                  fit: BoxFit.contain,
                  errorBuilder: (
                    BuildContext context,
                    Object error,
                    StackTrace? stackTrace,
                  ) {
                    return Image.asset(
                      'assets/app_logo.PNG',
                      width: widget.size * 0.78,
                      height: widget.size * 0.78,
                      fit: BoxFit.contain,
                    );
                  },
                ),
              ),
            ),
            Container(
              width: widget.size * 0.34,
              height: widget.size * 0.06,
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
