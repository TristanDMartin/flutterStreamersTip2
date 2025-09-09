import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/like_service.dart';

class OptimizedLikeButton extends StatefulWidget {
  final String videoId;
  final int initialLikeCount;
  final bool initialIsLiked;
  final VoidCallback? onLikeChanged;
  final GlobalKey? iconKey;

  const OptimizedLikeButton({
    super.key,
    required this.videoId,
    required this.initialLikeCount,
    required this.initialIsLiked,
    this.onLikeChanged,
    this.iconKey,
  });

  @override
  State<OptimizedLikeButton> createState() => _OptimizedLikeButtonState();
}

class _OptimizedLikeButtonState extends State<OptimizedLikeButton> 
    with SingleTickerProviderStateMixin {
  late bool _isLiked;
  late int _likeCount;
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.initialIsLiked;
    _likeCount = widget.initialLikeCount;
    
    // Load persistent state
    _loadPersistentState();
    
    // Initialize animation controller with more dramatic animation
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.6, // More dramatic scale down
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut, // More bouncy animation
    ));
    
    _colorAnimation = ColorTween(
      begin: Colors.white.withValues(alpha: 0.85),
      end: const Color(0xFF9248D2).withValues(alpha: 0.7),
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void didUpdateWidget(OptimizedLikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIsLiked != widget.initialIsLiked) {
      _isLiked = widget.initialIsLiked;
    }
    if (oldWidget.initialLikeCount != widget.initialLikeCount) {
      _likeCount = widget.initialLikeCount;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Load persistent state from local storage
  Future<void> _loadPersistentState() async {
    try {
      final likeService = LikeService();
      final isLiked = await likeService.isVideoLiked(widget.videoId);
      final likeCount = await likeService.getLikeCount(widget.videoId);
      
      if (mounted) {
        setState(() {
          _isLiked = isLiked;
          _likeCount = likeCount;
        });
      }
    } catch (e) {
      // Fallback to initial values if loading fails
      // Error loading persistent state: $e
    }
  }

  void _handleTapDown(TapDownDetails details) {
    if (!_isLoading && !_isPressed) {
      setState(() {
        _isPressed = true;
      });
      _animationController.forward();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (_isPressed) {
      _animationController.reverse().then((_) {
        if (mounted) {
          setState(() {
            _isPressed = false;
          });
        }
      });
    }
  }

  void _handleTapCancel() {
    if (_isPressed) {
      _animationController.reverse().then((_) {
        if (mounted) {
          setState(() {
            _isPressed = false;
          });
        }
      });
    }
  }

  Future<void> _handleLike() async {
    if (_isLoading) return;

    // Immediate UI feedback
    HapticFeedback.lightImpact();
    setState(() {
      _isLoading = true;
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });

    try {
      // Track engagement immediately
      LikeService().trackLikeEngagement(widget.videoId, _isLiked);

      // Perform like/unlike operation
      final success = await LikeService().toggleLike(widget.videoId);
      
      if (!success) {
        // Revert on failure
        setState(() {
          _isLiked = !_isLiked;
          _likeCount += _isLiked ? 1 : -1;
        });
        return;
      }

      // Create floating hearts animation on like
      if (_isLiked) {
        _createFloatingHearts();
      }

      // Notify parent of change
      widget.onLikeChanged?.call();
    } catch (e) {
      // Revert on error
      setState(() {
        _isLiked = !_isLiked;
        _likeCount += _isLiked ? 1 : -1;
      });
      // Error toggling like: $e
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _createFloatingHearts() {
    final RenderBox? box = widget.iconKey?.currentContext?.findRenderObject() as RenderBox?;
    final Offset origin = box != null
        ? box.localToGlobal(Offset(box.size.width / 2, box.size.height / 2))
        : Offset(MediaQuery.of(context).size.width / 2, MediaQuery.of(context).size.height / 2);
    
    FloatingHeartsAnimation.createFloatingHearts(
      context,
      origin,
      () {}, // No callback needed
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleLike,
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    children: [
                      Icon(
                        _isLoading 
                            ? Icons.favorite 
                            : (_isLiked ? Icons.favorite : Icons.favorite_border),
                        color: _isLiked 
                            ? const Color(0xFF9248D2) 
                            : (_isPressed ? _colorAnimation.value : Colors.white.withValues(alpha: 0.85)),
                        size: 28,
                      ),
                      if (_isLoading)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Center(
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9248D2)),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
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
            ),
          );
        },
      ),
    );
  }
}