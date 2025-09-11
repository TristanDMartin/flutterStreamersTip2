import 'package:flutter/material.dart';

class PopCheckmark extends StatefulWidget {
  final VoidCallback? onDone;

  const PopCheckmark({
    super.key,
    this.onDone,
  });

  @override
  State<PopCheckmark> createState() => _PopCheckmarkState();
}

class _PopCheckmarkState extends State<PopCheckmark>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    // Start animation when widget appears
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animationController.forward();
      
      // Call onDone after animation completes
      Future.delayed(const Duration(milliseconds: 300), () {
        widget.onDone?.call();
      });
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF34C759), // #34C759
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha:0.2),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: const Icon(
              Icons.check_circle,
              color: Colors.white,
              size: 36,
            ),
          ),
        );
      },
    );
  }
}

// Preview widget for testing
class PopCheckmarkPreview extends StatelessWidget {
  const PopCheckmarkPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(20),
      child: Center(
        child: PopCheckmark(
          onDone: () => {}, // Checkmark animation completed
        ),
      ),
    );
  }
}
