import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import '../providers/video_like_provider.dart';
import '../services/streamers_tip_like_service.dart';

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
class EnhancedLikeButton extends ConsumerStatefulWidget {
  final String videoId;
  final int initialLikeCount;
  final bool initialIsLiked;
  final VoidCallback? onLikeChanged;
  final GlobalKey? iconKey;
  final String? source; // 'button' or 'double-tap' for analytics
  final double width;
  final double height;
  final double iconSize;
  final double labelFontSize;
  final double labelGap;
  final double sparkleSize;

  const EnhancedLikeButton({
    super.key,
    required this.videoId,
    required this.initialLikeCount,
    required this.initialIsLiked,
    this.onLikeChanged,
    this.iconKey,
    this.source = 'button',
    this.width = 64,
    this.height = 96,
    this.iconSize = 34,
    this.labelFontSize = 12,
    this.labelGap = 4,
    this.sparkleSize = 80,
  });

  @override
  ConsumerState<EnhancedLikeButton> createState() => _EnhancedLikeButtonState();
}

class _EnhancedLikeButtonState extends ConsumerState<EnhancedLikeButton>
    with TickerProviderStateMixin {
  late AnimationController _heartAnimationController;
  late AnimationController _sparkleController;
  late Animation<double> _heartScaleAnimation;
  late Animation<double> _sparkleScaleAnimation;
  late Animation<double> _sparkleOpacityAnimation;

  bool _isAnimating = false;
  bool _isProcessing = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _videoStatsSubscription;
  DateTime? _lastTapTime;
  static const Duration _debounceDuration =
      Duration(milliseconds: 150); // Faster response

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref.read(videoLikeProvider(widget.videoId).notifier).seedFromDisplay(
            isLiked: widget.initialIsLiked,
            likeCount: widget.initialLikeCount,
          );
      _subscribeToLiveLikeCount();
      unawaited(_hydrateLikedEdgeFromFirestore());
    });
  }

  /// Ensure filled heart survives remount / web likes (edge docs, not just feed flag).
  Future<void> _hydrateLikedEdgeFromFirestore() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final bool liked = await StreamersTipLikeService.instance
          .isVideoLikedByUser(widget.videoId, user.uid);
      if (!mounted) return;
      if (!liked) return;
      final VideoLikeState current =
          ref.read(videoLikeProvider(widget.videoId));
      if (current.isLiked) return;
      ref.read(videoLikeProvider(widget.videoId).notifier).seedFromDisplay(
            isLiked: true,
            likeCount: current.likeCount,
          );
    } catch (e) {
      debugPrint('⚠️ EnhancedLikeButton: like-edge hydrate failed: $e');
    }
  }

  void _initializeAnimations() {
    // TikTok-style heart animation controller - more responsive
    _heartAnimationController = AnimationController(
      duration: const Duration(
          milliseconds: 200), // Slightly longer for better visibility
      vsync: this,
    );

    // TikTok-style sparkle animation controller - balanced duration
    _sparkleController = AnimationController(
      duration:
          const Duration(milliseconds: 800), // Longer for more dramatic effect
      vsync: this,
    );

    // Instagram-style heart scale animation with elastic bounce
    _heartScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3, // Bigger scale for Instagram effect
    ).animate(CurvedAnimation(
      parent: _heartAnimationController,
      curve: Curves.elasticOut, // Instagram-style elastic bounce
    ));

    // Instagram-style sparkle scale animation
    _sparkleScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _sparkleController,
      curve: Curves.easeOutBack, // Instagram-style back easing
    ));

    // Instagram-style sparkle opacity animation - slower fade
    _sparkleOpacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _sparkleController,
      curve: const Interval(0.3, 1.0,
          curve: Curves.easeOutQuart), // Slower, smoother fade
    ));
  }

  @override
  void didUpdateWidget(EnhancedLikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId != widget.videoId) {
      _videoStatsSubscription?.cancel();
      _subscribeToLiveLikeCount();
    }
  }

  @override
  void dispose() {
    _videoStatsSubscription?.cancel();
    _heartAnimationController.dispose();
    _sparkleController.dispose();
    super.dispose();
  }

  void _subscribeToLiveLikeCount() {
    _videoStatsSubscription?.cancel();
    _videoStatsSubscription = FirebaseFirestore.instance
        .collection('videos')
        .doc(widget.videoId)
        .snapshots()
        .listen((snapshot) {
      if (!mounted || !snapshot.exists) return;
      final data = snapshot.data();
      if (data == null) return;

      final dynamic rawLikeCount = data['likes'];
      final dynamic rawLikeCountLegacy = data['likeCount'] ?? data['likesCount'];
      final int likes = rawLikeCount is num
          ? rawLikeCount.toInt()
          : int.tryParse(rawLikeCount?.toString() ?? '') ?? 0;
      final int likeCount = rawLikeCountLegacy is num
          ? rawLikeCountLegacy.toInt()
          : int.tryParse(rawLikeCountLegacy?.toString() ?? '') ?? 0;
      final int nextLikeCount = math.max(0, math.max(likes, likeCount));
      ref
          .read(videoLikeProvider(widget.videoId).notifier)
          .applyLikeCountFromFirestore(nextLikeCount);
    });
  }

  /// Handle like button tap with debouncing and animations
  Future<void> _handleLike() async {
    debugPrint(
        '🎯 EnhancedLikeButton: _handleLike() called for video ${widget.videoId}');

    // Debounce rapid taps
    final now = DateTime.now();
    if (_lastTapTime != null &&
        now.difference(_lastTapTime!) < _debounceDuration) {
      debugPrint('⏱️ EnhancedLikeButton: Debounced (too fast)');
      return;
    }
    _lastTapTime = now;

    if (_isAnimating || _isProcessing) {
      debugPrint('⏸️ EnhancedLikeButton: Already animating/processing');
      return;
    }

    _isAnimating = true;
    _isProcessing = true;

    final VideoLikeState before = ref.read(videoLikeProvider(widget.videoId));

    try {
      HapticFeedback.mediumImpact();
      ref
          .read(videoLikeProvider(widget.videoId).notifier)
          .toggleOptimistic(source: widget.source ?? 'button_tap');
      widget.onLikeChanged?.call();
      final VideoLikeState after = ref.read(videoLikeProvider(widget.videoId));
      await _playLikeAnimation(isLiked: after.isLiked);
    } catch (e) {
      ref.read(videoLikeProvider(widget.videoId).notifier).restoreState(before);
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
  Future<void> _playLikeAnimation({required bool isLiked}) async {
    if (!isLiked) {
      // Unlike: reverse animation (subtle scale down + fill→outline)
      debugPrint('💔 EnhancedLikeButton: Playing UNLIKE animation');
      await _heartAnimationController.reverse();
      _sparkleController.reset();
    } else {
      // Like: full animation sequence with sparkles
      debugPrint(
          '❤️ EnhancedLikeButton: Playing LIKE animation with gradient sparkles');
      _heartAnimationController.reset();
      _sparkleController.reset();

      await _heartAnimationController.forward();
      _sparkleController.forward();
      debugPrint(
          '✨ EnhancedLikeButton: Sparkle animation started - should see gradient burst!');
    }
  }

  @override
  Widget build(BuildContext context) {
    final VideoLikeState likeState =
        ref.watch(videoLikeProvider(widget.videoId));
    final bool isLiked = likeState.isLiked;
    final int likeCount = likeState.likeCount;
    // Removed excessive build logging - was called on every frame
    // debugPrint(
    //     '🎨 EnhancedLikeButton: Building - videoId: ${widget.videoId}, local _isLiked: $_isLiked, _likeCount: $_likeCount');

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Semantics(
        label: isLiked ? 'Unlike' : 'Like',
        hint: 'Double-tap video to like',
        button: true,
        onTap: _handleLike,
        child: GestureDetector(
          onTap: _handleLike,
          behavior: HitTestBehavior.translucent,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _heartAnimationController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _heartScaleAnimation.value,
                        child: isLiked
                            ? ShaderMask(
                                shaderCallback: (bounds) =>
                                    const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF9248D2),
                                    Color(0xFF7768DF),
                                    Color(0xFF1670DE),
                                    Color(0xFF3C8BD6),
                                    Color(0xFF4897D2),
                                  ],
                                  stops: [0.0, 0.25, 0.5, 0.75, 1.0],
                                ).createShader(bounds),
                                child: Icon(
                                  Icons.favorite,
                                  color: Colors.white,
                                  size: widget.iconSize,
                                ),
                              )
                            : Icon(
                                Icons.favorite_border,
                                color: Colors.white,
                                size: widget.iconSize,
                                shadows: const <Shadow>[
                                  Shadow(
                                    color: Color(0x99000000),
                                    blurRadius: 8,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                      );
                    },
                  ),
                  SizedBox(height: widget.labelGap),
                  Text(
                    _formatCompactCount(likeCount),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: widget.labelFontSize,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              if (_sparkleController.isAnimating)
                IgnorePointer(
                  child: AnimatedBuilder(
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
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build Instagram-style sparkle/burst effect around the heart
  Widget _buildSparkleEffect() {
    return CustomPaint(
      size: Size.square(widget.sparkleSize),
      painter: InstagramSparklePainter(
        animationValue: _sparkleController.value,
      ),
    );
  }

  String _formatCompactCount(int value) {
    if (value <= 0) return '0';
    if (value < 1000) return value.toString();
    if (value < 1000000) {
      final compact = value / 1000;
      final text = compact < 10
          ? compact.toStringAsFixed(1)
          : compact.toStringAsFixed(0);
      return '${text.replaceFirst(RegExp(r'\\.0$'), '')}K';
    }
    final compact = value / 1000000;
    final text =
        compact < 10 ? compact.toStringAsFixed(1) : compact.toStringAsFixed(0);
    return '${text.replaceFirst(RegExp(r'\\.0$'), '')}M';
  }
}

/// Instagram-style sparkle effect painter
class InstagramSparklePainter extends CustomPainter {
  final double animationValue;

  InstagramSparklePainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Multiple layers of sparkles with brand gradient colors (purple to blue)
    _drawSparkleLayer(canvas, center, 0.4, 0.6,
        const Color(0xFF9248D2).withValues(alpha: 0.9), 12); // Purple
    _drawSparkleLayer(canvas, center, 0.6, 0.8,
        const Color(0xFF1670DE).withValues(alpha: 0.7), 8); // Blue
    _drawSparkleLayer(canvas, center, 0.8, 1.0,
        const Color(0xFF4897D2).withValues(alpha: 0.85), 6); // Lightest blue

    // Central burst effect with gradient
    _drawCentralBurst(canvas, center);
  }

  void _drawSparkleLayer(Canvas canvas, Offset center, double innerRadius,
      double outerRadius, Color color, int count) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (int i = 0; i < count; i++) {
      final angle = (i * math.pi * 2) / count;
      final progress = animationValue;
      final radius = innerRadius + (outerRadius - innerRadius) * progress;

      final sparkleX =
          center.dx + math.cos(angle) * radius * 25; // 25 is base radius
      final sparkleY = center.dy + math.sin(angle) * radius * 25;

      // Sparkle size based on animation progress
      final sparkleSize = (2.0 + progress * 3.0) * (1.0 - (progress * 0.3));

      // Draw sparkle with slight rotation
      canvas.save();
      canvas.translate(sparkleX, sparkleY);
      canvas.rotate(angle + progress * math.pi);

      // Draw sparkle shape (small star-like)
      final path = Path();
      path.moveTo(0, -sparkleSize);
      path.lineTo(sparkleSize * 0.3, -sparkleSize * 0.3);
      path.lineTo(sparkleSize, 0);
      path.lineTo(sparkleSize * 0.3, sparkleSize * 0.3);
      path.lineTo(0, sparkleSize);
      path.lineTo(-sparkleSize * 0.3, sparkleSize * 0.3);
      path.lineTo(-sparkleSize, 0);
      path.lineTo(-sparkleSize * 0.3, -sparkleSize * 0.3);
      path.close();

      canvas.drawPath(path, paint);
      canvas.restore();
    }
  }

  void _drawCentralBurst(Canvas canvas, Offset center) {
    // Draw central burst circles with gradient colors (purple to blue)
    final colors = [
      const Color(0xFF9248D2), // Purple
      const Color(0xFF7768DF), // Another purple
      const Color(0xFF1670DE), // Blue
    ];

    for (int i = 0; i < 3; i++) {
      final paint = Paint()
        ..color = colors[i].withValues(alpha: 0.4 * (1.0 - animationValue))
        ..style = PaintingStyle.fill;

      final radius = (5.0 + i * 3.0) * animationValue;
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(InstagramSparklePainter oldDelegate) =>
      oldDelegate.animationValue != animationValue;
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
