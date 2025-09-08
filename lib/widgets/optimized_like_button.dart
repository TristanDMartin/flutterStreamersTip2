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

class _OptimizedLikeButtonState extends State<OptimizedLikeButton> {
  late bool _isLiked;
  late int _likeCount;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.initialIsLiked;
    _likeCount = widget.initialLikeCount;
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
      print('Error toggling like: $e');
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
                  color: _isLiked ? const Color(0xFF9248D2) : Colors.white.withOpacity(0.85),
                  size: 28,
                ),
                if (_isLoading)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
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
                color: Colors.white.withOpacity(0.85),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
