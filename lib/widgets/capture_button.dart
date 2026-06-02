import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A sleek, circular capture button with animated progress ring
///
/// Features:
/// - Tap to start/stop recording
/// - Animated progress ring that fills clockwise
/// - Haptic feedback on tap
/// - Smooth scale animation on press
/// - Brand gradient center with soft shadow
class CaptureButton extends StatefulWidget {
  const CaptureButton({
    super.key,
    this.size = 68,
    this.ringWidth = 7,
    this.duration = const Duration(seconds: 15), // full ring fill time
    required this.onStart,
    required this.onFinish,
    this.onTap, // Optional single tap handler
    this.isRecording = false, // External recording state
  });

  final double size;
  final double ringWidth;
  final Duration duration;
  final VoidCallback onStart;
  final VoidCallback onFinish;
  final VoidCallback? onTap;
  final bool isRecording; // External recording state

  @override
  State<CaptureButton> createState() => _CaptureButtonState();
}

class _CaptureButtonState extends State<CaptureButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _stopRecording();
        }
      });

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.98,
    ).animate(CurvedAnimation(
      parent: _ctrl,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void didUpdateWidget(CaptureButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Sync with external recording state
    if (widget.isRecording != oldWidget.isRecording) {
      if (widget.isRecording) {
        _ctrl.forward(from: 0);
      } else {
        _ctrl.stop();
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _startRecording() async {
    if (widget.isRecording) return;

    HapticFeedback.lightImpact();
    widget.onStart();
  }

  void _stopRecording() {
    if (!widget.isRecording) return;

    widget.onFinish();

    // Brief success pulse
    HapticFeedback.mediumImpact();
  }

  void _handleTap() {
    if (widget.onTap != null) {
      widget.onTap!();
    } else {
      if (widget.isRecording) {
        _stopRecording();
      } else {
        _startRecording();
      }
    }
  }

  void _handlePressStart() {
    setState(() => _isPressed = true);
    if (widget.onTap == null) {
      _startRecording();
    }
  }

  void _handlePressEnd() {
    setState(() => _isPressed = false);
    if (widget.onTap == null && widget.isRecording) {
      _stopRecording();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;

    return GestureDetector(
      onTap: _handleTap,
      onTapDown: (_) => _handlePressStart(),
      onTapUp: (_) => _handlePressEnd(),
      onTapCancel: _handlePressEnd,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _isPressed ? 0.98 : 1.0,
            child: SizedBox(
              width: size,
              height: size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Progress ring
                  if (widget.isRecording)
                    CustomPaint(
                      size: Size(size, size),
                      painter: _RingPainter(
                        progress: _ctrl.value,
                        ringWidth: widget.ringWidth,
                        ringColor: Colors.red
                            .withValues(alpha: 0.9), // Red ring when recording
                        bgRingColor: Colors.red
                            .withValues(alpha: 0.15), // Red background ring
                      ),
                    ),

                  // Center button
                  Container(
                    width: size - (widget.ringWidth * 2),
                    height: size - (widget.ringWidth * 2),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF9248D2), // brand purple
                          Color(0xFF1670DE), // brand blue
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black38,
                          blurRadius: 24,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: widget.isRecording
                        ? const Icon(
                            Icons.stop,
                            color: Colors.white,
                            size: 24,
                          )
                        : const Icon(
                            Icons.circle,
                            color: Colors.white,
                            size: 20,
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Custom painter for the animated progress ring
class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.ringWidth,
    required this.ringColor,
    required this.bgRingColor,
  });

  final double progress; // 0..1
  final double ringWidth;
  final Color ringColor;
  final Color bgRingColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide / 2) - ringWidth / 2;

    // Background ring
    final bgPaint = Paint()
      ..color = bgRingColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth
      ..strokeCap = StrokeCap.round;

    // Progress ring
    final progressPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth
      ..strokeCap = StrokeCap.round;

    // Draw background circle
    canvas.drawCircle(center, radius, bgPaint);

    // Draw progress arc (starts at top, clockwise)
    if (progress > 0) {
      const startAngle = -90 * (3.14159265 / 180); // Start at top
      final sweepAngle = 2 * 3.14159265 * progress; // Clockwise progress

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress ||
      old.ringWidth != ringWidth ||
      old.ringColor != ringColor ||
      old.bgRingColor != bgRingColor;
}

/// Example usage widget showing different capture button configurations
class CaptureButtonExample extends StatefulWidget {
  const CaptureButtonExample({super.key});

  @override
  State<CaptureButtonExample> createState() => _CaptureButtonExampleState();
}

class _CaptureButtonExampleState extends State<CaptureButtonExample> {
  int _tapCount = 0;
  int _recordCount = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Tap to record/stop button
            CaptureButton(
              size: 72,
              ringWidth: 8,
              duration: const Duration(seconds: 10),
              onStart: () {
                setState(() => _recordCount++);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Recording started...'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              onFinish: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Recording finished!'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),

            const SizedBox(height: 40),

            // Simple tap button
            CaptureButton(
              size: 64,
              ringWidth: 6,
              onTap: () {
                setState(() => _tapCount++);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Tapped $_tapCount times'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              onStart: () {}, // Required but not used
              onFinish: () {}, // Required but not used
            ),

            const SizedBox(height: 40),

            Text(
              'Records: $_recordCount | Taps: $_tapCount',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
