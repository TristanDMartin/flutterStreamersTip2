import 'package:flutter/material.dart';

/// Floating brand mark for the cinematic auth journey (no card wrapper).
class AuthBrandHeader extends StatefulWidget {
  const AuthBrandHeader({
    super.key,
    this.logoSize = 96,
    this.showTagline = true,
    this.compact = false,
  });

  final double logoSize;
  final bool showTagline;
  final bool compact;

  @override
  State<AuthBrandHeader> createState() => _AuthBrandHeaderState();
}

class _AuthBrandHeaderState extends State<AuthBrandHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _floatController;
  late final Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    );
    _floatAnimation = Tween<double>(begin: -4, end: 4).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
    final bool reduceMotion = WidgetsBinding
            .instance.platformDispatcher.accessibilityFeatures.reduceMotion ==
        true;
    if (!reduceMotion) {
      _floatController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double logoSize = widget.compact ? widget.logoSize * 0.78 : widget.logoSize;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AnimatedBuilder(
          animation: _floatAnimation,
          builder: (BuildContext context, Widget? child) {
            return Transform.translate(
              offset: Offset(0, _floatController.isAnimating ? _floatAnimation.value : 0),
              child: child,
            );
          },
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: const Color(0xFF9248D2).withValues(alpha: 0.35),
                  blurRadius: 28,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: const Color(0xFF4897D2).withValues(alpha: 0.22),
                  blurRadius: 40,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Image.asset(
              'assets/logo.png',
              width: logoSize,
              height: logoSize,
              fit: BoxFit.contain,
              errorBuilder: (
                BuildContext context,
                Object error,
                StackTrace? stackTrace,
              ) {
                return ShaderMask(
                  shaderCallback: (Rect rect) {
                    return const LinearGradient(
                      colors: <Color>[
                        Color(0xFFFFD76A),
                        Color(0xFF9F80FF),
                        Color(0xFF52B6FF),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(rect);
                  },
                  blendMode: BlendMode.srcIn,
                  child: Icon(
                    Icons.play_circle_filled,
                    size: logoSize,
                    color: Colors.white,
                  ),
                );
              },
            ),
          ),
        ),
        SizedBox(height: widget.compact ? 12 : 18),
        Text(
          'StreamersTip',
          style: TextStyle(
            fontSize: widget.compact ? 28 : 34,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: Colors.white,
            shadows: <Shadow>[
              Shadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
        ),
        if (widget.showTagline) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            'Creator Growth OS',
            style: TextStyle(
              fontSize: widget.compact ? 13 : 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
              color: Colors.white.withValues(alpha: 0.78),
            ),
          ),
        ],
      ],
    );
  }
}
