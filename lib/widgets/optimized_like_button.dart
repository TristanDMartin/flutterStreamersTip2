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
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.initialIsLiked;
    _likeCount = widget.initialLikeCount;
    
    // Initialize animation controller with faster, more responsive animation
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 100), // Faster animation
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.7, // Less dramatic scale for faster feel
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut, // Faster, snappier animation
    ));
    
    // Load persistent state after initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPersistentState();
    });
  }

  @override
  void didUpdateWidget(OptimizedLikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIsLiked != widget.initialIsLiked) {
      setState(() {
        _isLiked = widget.initialIsLiked;
      });
    }
    if (oldWidget.initialLikeCount != widget.initialLikeCount) {
      setState(() {
        _likeCount = widget.initialLikeCount;
      });
    }
    
    // Only reload persistent state when video ID changes (not on every update)
    if (oldWidget.videoId != widget.videoId) {
      _loadPersistentState();
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
    if (!_isPressed) {
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
    // Immediate UI feedback - no loading state needed
    HapticFeedback.lightImpact();
    
    // Update UI instantly - this should be immediate
    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });

    // Quick visual feedback animation
    _animationController.forward().then((_) {
      _animationController.reverse();
    });

    // Create floating hearts animation on like
    if (_isLiked) {
      _createFloatingHearts();
    }

    // Notify parent of change immediately
    widget.onLikeChanged?.call();

    // Perform background operations without blocking UI
    _performBackgroundLikeOperation();
  }

  Future<void> _performBackgroundLikeOperation() async {
    try {
      // Track engagement
      LikeService().trackLikeEngagement(widget.videoId, _isLiked);

      // Try to perform like/unlike operation in background
      // Don't revert on failure - keep the UI state as is
      await LikeService().toggleLike(widget.videoId);
    } catch (e) {
      // Don't revert on error - keep the UI state
      // The like state should persist locally even if Firebase fails
    // print('Background like operation failed (keeping UI state): $e');
    }
  }

  void _createFloatingHearts() {
    try {
      final RenderBox? box = widget.iconKey?.currentContext?.findRenderObject() as RenderBox?;
      final Offset origin = box != null
          ? box.localToGlobal(Offset(box.size.width / 2, box.size.height / 2))
          : Offset(MediaQuery.of(context).size.width / 2, MediaQuery.of(context).size.height / 2);
      
      // Create multiple hearts for better effect
      for (int i = 0; i < 3; i++) {
        Future.delayed(Duration(milliseconds: i * 100), () {
          if (mounted) {
            FloatingHeartsAnimation.createFloatingHearts(
              context,
              origin,
              () {}, // No callback needed
            );
          }
        });
      }
    } catch (e) {
      // If floating hearts fail, just continue - not critical
    // print('Floating hearts animation error: $e');
    }
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
                  Icon(
                    _isLiked ? Icons.favorite : Icons.favorite_border,
                    color: _isLiked 
                        ? const Color(0xFF9248D2) 
                        : Colors.white.withValues(alpha: 0.85),
                    size: 28,
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