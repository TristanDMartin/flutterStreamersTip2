import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Gesture detector that handles single-tap and double-tap with conflict resolution
class DoubleTapGestureDetector extends StatefulWidget {
  final Widget child;
  final VoidCallback? onSingleTap;
  final Function(Offset position)? onDoubleTap;
  final Duration doubleTapDelay;

  const DoubleTapGestureDetector({
    super.key,
    required this.child,
    this.onSingleTap,
    this.onDoubleTap,
    this.doubleTapDelay = const Duration(milliseconds: 200), // Faster response
  });

  @override
  State<DoubleTapGestureDetector> createState() =>
      _DoubleTapGestureDetectorState();
}

class _DoubleTapGestureDetectorState extends State<DoubleTapGestureDetector> {
  Timer? _singleTapTimer;
  int _tapCount = 0;
  Offset? _lastTapPosition;

  void _handleTapDown(TapDownDetails details) {
    _tapCount++;
    _lastTapPosition = details.localPosition;

    if (_tapCount == 1) {
      // Start timer for single tap
      _singleTapTimer = Timer(widget.doubleTapDelay, () {
        if (_tapCount == 1 && widget.onSingleTap != null) {
          // Single tap confirmed
          widget.onSingleTap!();
        }
        _reset();
      });
    } else if (_tapCount == 2) {
      // Double tap detected
      _singleTapTimer?.cancel();

      if (widget.onDoubleTap != null && _lastTapPosition != null) {
        // Haptic feedback for double tap
        HapticFeedback.mediumImpact();
        widget.onDoubleTap!(_lastTapPosition!);
      }

      _reset();
    }
  }

  void _reset() {
    _tapCount = 0;
    _lastTapPosition = null;
    _singleTapTimer?.cancel();
  }

  @override
  void dispose() {
    _singleTapTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      behavior: HitTestBehavior.translucent,
      child: widget.child,
    );
  }
}

/// Enhanced gesture detector with accessibility support
class AccessibleGestureDetector extends StatefulWidget {
  final Widget child;
  final VoidCallback? onSingleTap;
  final Function(Offset position)? onDoubleTap;
  final String? semanticLabel;
  final String? tooltip;

  const AccessibleGestureDetector({
    super.key,
    required this.child,
    this.onSingleTap,
    this.onDoubleTap,
    this.semanticLabel,
    this.tooltip,
  });

  @override
  State<AccessibleGestureDetector> createState() =>
      _AccessibleGestureDetectorState();
}

class _AccessibleGestureDetectorState extends State<AccessibleGestureDetector> {
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.semanticLabel,
      hint: widget.tooltip,
      button: true,
      onTap: widget.onSingleTap,
      onLongPress: () {
        // Show tooltip for long press
        if (widget.tooltip != null) {
          _showTooltip(context, widget.tooltip!);
        }
      },
      child: DoubleTapGestureDetector(
        onSingleTap: widget.onSingleTap,
        onDoubleTap: widget.onDoubleTap,
        child: widget.child,
      ),
    );
  }

  void _showTooltip(BuildContext context, String message) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 100, // Position above bottom navigation
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    // Remove tooltip after 2 seconds
    Timer(const Duration(seconds: 2), () {
      overlayEntry.remove();
    });
  }
}
