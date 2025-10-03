import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import '../services/enhanced_like_service.dart';

/// Enhanced Like Button with TikTok-style animations and persistence
///
/// Features:
/// - Heart morph animation (outline → filled with scale pop)
/// - Sparkle/burst effect on like
/// - Haptic feedback
/// - Optimistic UI updates
/// - Persistent state across app restarts
/// - Debounced rapid taps
/// - Proper error handling with rollback
class EnhancedLikeButton extends StatefulWidget {
  final String videoId;
  final int initialLikeCount;
  final bool initialIsLiked;
  final VoidCallback? onLikeChanged;
  final GlobalKey? iconKey;
  final String? source; // 'button' or 'double-tap' for analytics

  const EnhancedLikeButton({
    super.key,
    required this.videoId,
    required this.initialLikeCount,
    required this.initialIsLiked,
    this.onLikeChanged,
    this.iconKey,
    this.source = 'button',
  });

  @override
  State<EnhancedLikeButton> createState() => _EnhancedLikeButtonState();
}

class _EnhancedLikeButtonState extends State<EnhancedLikeButton>
    with TickerProviderStateMixin {
  late bool _isLiked;
  late int _likeCount;
  late AnimationController _heartAnimationController;
  late AnimationController _sparkleController;
  late Animation<double> _heartScaleAnimation;
  late Animation<double> _sparkleScaleAnimation;
  late Animation<double> _sparkleOpacityAnimation;

  bool _isAnimating = false;
  bool _isProcessing = false;
  DateTime? _lastTapTime;
  static const Duration _debounceDuration = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    _isLiked = widget.initialIsLiked;
    _likeCount = widget.initialLikeCount;

    _initializeAnimations();

    // Load persistent state after initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPersistentState();
    });
  }

  void _initializeAnimations() {
    // Heart animation controller - shorter, smoother duration
    _heartAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    // Sparkle animation controller - shorter duration
    _sparkleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Heart scale animation: 1.0 → 1.15 → 1.0 (smoother curve)
    _heartScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.15),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.15, end: 1.0),
        weight: 50,
      ),
    ]).animate(CurvedAnimation(
      parent: _heartAnimationController,
      curve: Curves.easeOutCubic, // Smoother curve
    ));

    // Sparkle scale animation - simpler curve
    _sparkleScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _sparkleController,
      curve: Curves.easeOut,
    ));

    // Sparkle opacity animation - faster fade
    _sparkleOpacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _sparkleController,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
    ));
  }

  @override
  void didUpdateWidget(EnhancedLikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Only update if video ID changed (not on every rebuild)
    if (oldWidget.videoId != widget.videoId) {
      _isLiked = widget.initialIsLiked;
      _likeCount = widget.initialLikeCount;
      _loadPersistentState();
    }
  }

  @override
  void dispose() {
    _heartAnimationController.dispose();
    _sparkleController.dispose();
    super.dispose();
  }

  /// Load persistent state from local storage
  Future<void> _loadPersistentState() async {
    try {
      final enhancedLikeService = EnhancedLikeService();
      final isLiked = await enhancedLikeService.isVideoLiked(widget.videoId);
      final likeCount = await enhancedLikeService.getLikeCount(widget.videoId);

      if (mounted) {
        setState(() {
          _isLiked = isLiked;
          _likeCount = likeCount;
        });
      }
    } catch (e) {
      // Fallback to initial values if loading fails
      debugPrint('Error loading persistent like state: $e');
    }
  }

  /// Handle like button tap with debouncing and animations
  Future<void> _handleLike() async {
    // Debounce rapid taps
    final now = DateTime.now();
    if (_lastTapTime != null &&
        now.difference(_lastTapTime!) < _debounceDuration) {
      return;
    }
    _lastTapTime = now;

    if (_isAnimating || _isProcessing) return;

    _isAnimating = true;
    _isProcessing = true;

    // Store original state for potential rollback
    final originalIsLiked = _isLiked;
    final originalLikeCount = _likeCount;

    try {
      // 1. Immediate haptic feedback
      HapticFeedback.lightImpact();

      // 2. Optimistic UI update
      setState(() {
        _isLiked = !_isLiked;
        _likeCount = _isLiked ? _likeCount + 1 : math.max(0, _likeCount - 1);
      });

      // 3. Notify parent immediately (before animations)
      widget.onLikeChanged?.call();

      // 4. Play animations (non-blocking)
      _playLikeAnimation();

      // 5. Perform background sync
      await _performBackgroundSync();
    } catch (e) {
      // Rollback on error
      setState(() {
        _isLiked = originalIsLiked;
        _likeCount = originalLikeCount;
      });

      // Show error feedback
      HapticFeedback.heavyImpact();
      debugPrint('Like operation failed, rolled back: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isAnimating = false;
          _isProcessing = false;
        });
      }
    }
  }

  /// Play the complete like animation sequence
  Future<void> _playLikeAnimation() async {
    if (!_isLiked) {
      // Unlike: reverse animation (subtle scale down + fill→outline)
      _heartAnimationController.reverse();
    } else {
      // Like: full animation sequence
      _heartAnimationController.forward();

      // Start sparkle effect immediately for smoother animation
      _sparkleController.forward();
    }
  }

  /// Perform background sync with server
  Future<void> _performBackgroundSync() async {
    try {
      final enhancedLikeService = EnhancedLikeService();

      // Sync with server using enhanced service
      final result = await enhancedLikeService.toggleLike(widget.videoId,
          source: widget.source ?? 'button');

      if (result != LikeResult.success) {
        debugPrint('Background sync failed: $result');
      }
    } catch (e) {
      // Don't throw - we want to keep the optimistic UI state
      debugPrint('Background sync failed (keeping UI state): $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleLike,
      behavior: HitTestBehavior.opaque, // Prevent tap from passing through
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Main heart button
          AnimatedBuilder(
            animation: _heartAnimationController,
            builder: (context, child) {
              return Transform.scale(
                scale: _heartScaleAnimation.value,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Heart icon with morph effect - optimized
                    Icon(
                      _isLiked ? Icons.favorite : Icons.favorite_border,
                      color: _isLiked
                          ? const Color(0xFF9248D2)
                          : Colors.white.withValues(alpha: 0.85),
                      size: 28,
                    ),
                    const SizedBox(height: 4),
                    // Like count
                    Text(
                      _likeCount.toString(),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Sparkle effect overlay - only when liking
          if (_isLiked && _sparkleController.isAnimating)
            AnimatedBuilder(
              animation: _sparkleController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _sparkleScaleAnimation.value,
                  child: Opacity(
                    opacity: _sparkleOpacityAnimation.value,
                    child: _buildSparkleEffect(),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  /// Build sparkle/burst effect around the heart
  Widget _buildSparkleEffect() {
    return CustomPaint(
      size: const Size(60, 60),
      painter: SparklePainter(),
    );
  }
}

/// Custom painter for sparkle effect
class SparklePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF9248D2)
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw multiple sparkles around the heart
    for (int i = 0; i < 8; i++) {
      final angle = (i * math.pi * 2) / 8;
      final sparkleX = center.dx + math.cos(angle) * radius * 0.7;
      final sparkleY = center.dy + math.sin(angle) * radius * 0.7;

      // Draw small sparkle dots
      canvas.drawCircle(
        Offset(sparkleX, sparkleY),
        2.0,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Enhanced floating hearts animation for double-tap
class EnhancedFloatingHearts {
  static void createFloatingHearts(
    BuildContext context,
    Offset origin,
    VoidCallback? onComplete,
  ) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => _EnhancedFloatingHeartsWidget(
        origin: origin,
        onComplete: onComplete ?? () {},
      ),
    );

    overlay.insert(overlayEntry);

    // Auto-remove after animation
    Future.delayed(const Duration(seconds: 2), () {
      overlayEntry.remove();
    });
  }
}

class _EnhancedFloatingHeartsWidget extends StatefulWidget {
  final Offset origin;
  final VoidCallback onComplete;

  const _EnhancedFloatingHeartsWidget({
    required this.origin,
    required this.onComplete,
  });

  @override
  State<_EnhancedFloatingHeartsWidget> createState() =>
      _EnhancedFloatingHeartsWidgetState();
}

class _EnhancedFloatingHeartsWidgetState
    extends State<_EnhancedFloatingHeartsWidget> with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _positionAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.3, curve: Curves.elasticOut),
    ));

    _opacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
    ));

    _positionAnimation = Tween<Offset>(
      begin: widget.origin,
      end: Offset(widget.origin.dx, widget.origin.dy - 100),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward().then((_) {
      widget.onComplete();
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
          left: _positionAnimation.value.dx - 15,
          top: _positionAnimation.value.dy - 15,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: _opacityAnimation.value,
              child: const Icon(
                Icons.favorite,
                color: Color(0xFF9248D2),
                size: 30,
              ),
            ),
          ),
        );
      },
    );
  }
}
