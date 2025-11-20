import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// TikTok-style like button for the right rail
class LikeButtonWidget extends StatefulWidget {
  final bool isLiked;
  final int likeCount;
  final bool isLoading;
  final VoidCallback? onTap;
  final bool enableAnimations;
  final bool isOwnVideo;

  const LikeButtonWidget({
    super.key,
    required this.isLiked,
    required this.likeCount,
    this.isLoading = false,
    this.onTap,
    this.enableAnimations = true,
    this.isOwnVideo = false,
  });

  @override
  State<LikeButtonWidget> createState() => _LikeButtonWidgetState();
}

class _LikeButtonWidgetState extends State<LikeButtonWidget>
    with TickerProviderStateMixin {
  late AnimationController _buttonController;
  late AnimationController _sparkleController;

  late Animation<double> _buttonScale;
  late Animation<double> _sparkleOpacity;
  late Animation<double> _sparkleScale;

  bool _showSparkles = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    // Button animation controller
    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 120),
      vsync: this,
    );

    // Sparkle animation controller
    _sparkleController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    // Button scale animation
    _buttonScale = Tween<double>(
      begin: 1.0,
      end: 1.25,
    ).animate(CurvedAnimation(
      parent: _buttonController,
      curve: Curves.easeOut,
    ));

    // Sparkle animations
    _sparkleOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _sparkleController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    ));

    _sparkleScale = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _sparkleController,
      curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
    ));
  }

  void _handleTap() {
    if (widget.onTap != null) {
      // Haptic feedback
      HapticFeedback.lightImpact();

      // Button animation
      if (widget.enableAnimations) {
        _buttonController.forward().then((_) {
          _buttonController.reverse();
        });
      }

      // Show sparkles for like action
      if (widget.enableAnimations && !widget.isLiked) {
        _showSparkles = true;
        _sparkleController.forward().then((_) {
          _sparkleController.reverse().then((_) {
            if (mounted) {
              setState(() {
                _showSparkles = false;
              });
            }
          });
        });
      }

      widget.onTap!();
    }
  }

  @override
  void dispose() {
    _buttonController.dispose();
    _sparkleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.isLiked ? 'Unlike' : 'Like',
      hint: 'Double-tap video to like',
      button: true,
      onTap: _handleTap,
      child: GestureDetector(
        onTap: _handleTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Button with animations
              AnimatedBuilder(
                animation: _buttonController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: widget.isLoading ? 1.0 : _buttonScale.value,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Heart icon with gradient fill
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: widget.isLiked
                                ? const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFFFF6B6B),
                                      Color(0xFFEE5A52),
                                      Color(0xFFFF4757),
                                    ],
                                  )
                                : null,
                            border: widget.isLiked
                                ? null
                                : Border.all(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    width: 2,
                                  ),
                          ),
                          child: Icon(
                            widget.isLiked
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: widget.isLiked ? Colors.white : Colors.white,
                            size: 24,
                          ),
                        ),

                        // Loading indicator
                        if (widget.isLoading)
                          const SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),

                        // Sparkle effect overlay
                        if (_showSparkles)
                          AnimatedBuilder(
                            animation: _sparkleController,
                            builder: (context, child) {
                              return Opacity(
                                opacity: _sparkleOpacity.value,
                                child: Transform.scale(
                                  scale: _sparkleScale.value,
                                  child: Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color:
                                            Colors.white.withValues(alpha: 0.8),
                                        width: 3,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
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
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),

              // Own video indicator
              if (widget.isOwnVideo)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Own',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
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

/// Sparkle particle widget for like animations
class SparkleParticleWidget extends StatefulWidget {
  final Offset position;
  final Color color;
  final Duration duration;
  final VoidCallback? onComplete;

  const SparkleParticleWidget({
    super.key,
    required this.position,
    required this.color,
    this.duration = const Duration(milliseconds: 250),
    this.onComplete,
  });

  @override
  State<SparkleParticleWidget> createState() => _SparkleParticleWidgetState();
}

class _SparkleParticleWidgetState extends State<SparkleParticleWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _opacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
    ));

    _scale = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));

    _controller.forward().then((_) {
      widget.onComplete?.call();
    });
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
      builder: (context, child) {
        return Positioned(
          left: widget.position.dx - 4,
          top: widget.position.dy - 4,
          child: Opacity(
            opacity: _opacity.value,
            child: Transform.scale(
              scale: _scale.value,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.5),
                      blurRadius: 4,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
