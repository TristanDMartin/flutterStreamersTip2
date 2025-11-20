import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// TikTok-style heart animation widget
class HeartAnimationWidget extends StatefulWidget {
  final Offset position;
  final VoidCallback? onComplete;
  final bool enableParticles;

  const HeartAnimationWidget({
    super.key,
    required this.position,
    this.onComplete,
    this.enableParticles = true,
  });

  @override
  State<HeartAnimationWidget> createState() => _HeartAnimationWidgetState();
}

class _HeartAnimationWidgetState extends State<HeartAnimationWidget>
    with TickerProviderStateMixin {
  late AnimationController _heartController;
  late AnimationController _particleController;

  late Animation<double> _heartScale;
  late Animation<double> _heartOpacity;
  late Animation<Offset> _heartPosition;
  late Animation<double> _heartRotation;

  late Animation<double> _particleOpacity;
  late Animation<double> _particleScale;

  final List<ParticleData> _particles = [];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _createParticles();
    _startAnimations();
  }

  void _initializeAnimations() {
    // Heart animation controller
    _heartController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );

    // Particle animation controller
    _particleController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    // Heart scale animation (overshoot effect)
    _heartScale = Tween<double>(
      begin: 0.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _heartController,
      curve: const Interval(0.0, 0.17, curve: Curves.elasticOut),
    ));

    // Heart opacity animation
    _heartOpacity = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _heartController,
      curve: const Interval(0.0, 0.17, curve: Curves.easeOut),
    ));

    // Heart position animation (drift up with jitter)
    _heartPosition = Tween<Offset>(
      begin: Offset.zero,
      end: Offset(
        (math.Random().nextDouble() - 0.5) * 20, // Random jitter
        -100, // Drift up
      ),
    ).animate(CurvedAnimation(
      parent: _heartController,
      curve: Curves.easeInOut,
    ));

    // Heart rotation animation (subtle jitter)
    _heartRotation = Tween<double>(
      begin: 0.0,
      end: (math.Random().nextDouble() - 0.5) *
          20 *
          (math.pi / 180), // Random rotation
    ).animate(CurvedAnimation(
      parent: _heartController,
      curve: Curves.easeInOut,
    ));

    // Particle animations
    _particleOpacity = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _particleController,
      curve: const Interval(0.0, 1.0, curve: Curves.easeOut),
    ));

    _particleScale = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _particleController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    ));
  }

  void _createParticles() {
    final random = math.Random();

    for (int i = 0; i < 8; i++) {
      final angle = (i / 8.0) * 2 * math.pi;
      final distance = 30 + random.nextDouble() * 40; // 30-70px radius

      _particles.add(ParticleData(
        angle: angle,
        distance: distance,
        color: _getRandomParticleColor(),
        size: 2 + random.nextDouble() * 4, // 2-6px size
      ));
    }
  }

  Color _getRandomParticleColor() {
    final colors = [
      Colors.pink.shade300,
      Colors.red.shade300,
      Colors.orange.shade300,
      Colors.yellow.shade300,
    ];
    return colors[math.Random().nextInt(colors.length)];
  }

  void _startAnimations() {
    // Start particle animation immediately
    _particleController.forward();

    // Start heart animation with slight delay
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) {
        _heartController.forward().then((_) {
          // Fade out at the end
          _heartController.reverse().then((_) {
            widget.onComplete?.call();
          });
        });
      }
    });
  }

  @override
  void dispose() {
    _heartController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Particles
        if (widget.enableParticles)
          AnimatedBuilder(
            animation: _particleController,
            builder: (context, child) {
              return Stack(
                children: _particles.map((particle) {
                  final progress = _particleController.value;
                  final x =
                      math.cos(particle.angle) * particle.distance * progress;
                  final y =
                      math.sin(particle.angle) * particle.distance * progress;

                  return Positioned(
                    left: widget.position.dx + x - particle.size / 2,
                    top: widget.position.dy + y - particle.size / 2,
                    child: Opacity(
                      opacity: _particleOpacity.value,
                      child: Transform.scale(
                        scale: _particleScale.value,
                        child: Container(
                          width: particle.size,
                          height: particle.size,
                          decoration: BoxDecoration(
                            color: particle.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),

        // Heart
        AnimatedBuilder(
          animation: _heartController,
          builder: (context, child) {
            return Positioned(
              left: widget.position.dx + _heartPosition.value.dx - 15,
              top: widget.position.dy + _heartPosition.value.dy - 15,
              child: Transform.scale(
                scale: _heartScale.value,
                child: Transform.rotate(
                  angle: _heartRotation.value,
                  child: Opacity(
                    opacity: _heartOpacity.value,
                    child: const Icon(
                      Icons.favorite,
                      color: Colors.red,
                      size: 30,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Particle data for animation
class ParticleData {
  final double angle;
  final double distance;
  final Color color;
  final double size;

  const ParticleData({
    required this.angle,
    required this.distance,
    required this.color,
    required this.size,
  });
}

/// Heart button with TikTok-style animations
class HeartButtonWidget extends StatefulWidget {
  final bool isLiked;
  final int likeCount;
  final bool isLoading;
  final VoidCallback? onTap;
  final bool enableAnimations;

  const HeartButtonWidget({
    super.key,
    required this.isLiked,
    required this.likeCount,
    this.isLoading = false,
    this.onTap,
    this.enableAnimations = true,
  });

  @override
  State<HeartButtonWidget> createState() => _HeartButtonWidgetState();
}

class _HeartButtonWidgetState extends State<HeartButtonWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 120),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.25,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.onTap != null) {
      // Haptic feedback
      HapticFeedback.lightImpact();

      // Animation
      if (widget.enableAnimations) {
        _controller.forward().then((_) {
          _controller.reverse();
        });
      }

      widget.onTap!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _scaleAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: widget.isLoading ? 1.0 : _scaleAnimation.value,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Heart icon
                      Icon(
                        widget.isLiked ? Icons.favorite : Icons.favorite_border,
                        color: widget.isLiked ? Colors.red : Colors.white,
                        size: 32,
                      ),

                      // Loading indicator
                      if (widget.isLoading)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.red),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 4),

            // Like count
            Text(
              _formatCount(widget.likeCount),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }
}
