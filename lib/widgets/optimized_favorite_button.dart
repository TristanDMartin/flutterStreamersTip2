import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/favorites_service_optimized.dart';

class OptimizedFavoriteButton extends StatefulWidget {
  final String videoId;
  final bool initialIsFavorited;
  final VoidCallback? onFavoriteChanged;
  final double? size;
  final Color? activeColor;
  final Color? inactiveColor;

  const OptimizedFavoriteButton({
    super.key,
    required this.videoId,
    required this.initialIsFavorited,
    this.onFavoriteChanged,
    this.size,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  State<OptimizedFavoriteButton> createState() => _OptimizedFavoriteButtonState();
}

class _OptimizedFavoriteButtonState extends State<OptimizedFavoriteButton> {
  late bool _isFavorited;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _isFavorited = widget.initialIsFavorited;
  }

  @override
  void didUpdateWidget(OptimizedFavoriteButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIsFavorited != widget.initialIsFavorited) {
      _isFavorited = widget.initialIsFavorited;
    }
  }

  Future<void> _toggleFavorite() async {
    if (_isLoading) return;

    // Immediate UI feedback
    HapticFeedback.lightImpact();
    setState(() {
      _isLoading = true;
      _isFavorited = !_isFavorited;
    });

    try {
      final success = await FavoritesServiceOptimized().toggleFavorite(widget.videoId);
      
      if (!success) {
        // Revert on failure
        setState(() {
          _isFavorited = !_isFavorited;
        });
        return;
      }

      // Notify parent of change
      widget.onFavoriteChanged?.call();
    } catch (e) {
      // Revert on error
      setState(() {
        _isFavorited = !_isFavorited;
      });
    // print('Error toggling favorite: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size ?? 24.0;
    final activeColor = widget.activeColor ?? const Color(0xFF9248D2);
    final inactiveColor = widget.inactiveColor ?? Colors.white.withValues(alpha:0.85);

    return GestureDetector(
      onTap: _toggleFavorite,
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Stack(
          children: [
            Icon(
              _isFavorited ? Icons.bookmark : Icons.bookmark_border,
              color: _isFavorited ? activeColor : inactiveColor,
              size: size,
            ),
            if (_isLoading)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha:0.3),
                    borderRadius: BorderRadius.circular(size / 2),
                  ),
                  child: Center(
                    child: SizedBox(
                      width: size * 0.6,
                      height: size * 0.6,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(activeColor),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
