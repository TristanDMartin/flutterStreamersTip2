import 'dart:ui';

import 'package:flutter/material.dart';

/// Slow crossfade + gentle zoom collage used when cinematic video is unavailable.
class AuthKenBurnsCollage extends StatefulWidget {
  const AuthKenBurnsCollage({
    super.key,
    this.animate = true,
  });

  final bool animate;

  static const List<String> frameAssets = <String>[
    'assets/splash_composite.png',
    'assets/background.png',
    'assets/logo1-0.PNG',
  ];

  @override
  State<AuthKenBurnsCollage> createState() => _AuthKenBurnsCollageState();
}

class _AuthKenBurnsCollageState extends State<AuthKenBurnsCollage>
    with TickerProviderStateMixin {
  late final AnimationController _crossfadeController;
  late final AnimationController _zoomController;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _crossfadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _zoomController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
    if (widget.animate) {
      _zoomController.repeat(reverse: true);
      _scheduleNextCrossfade();
    }
  }

  @override
  void didUpdateWidget(covariant AuthKenBurnsCollage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animate == widget.animate) {
      return;
    }
    if (widget.animate) {
      _zoomController.repeat(reverse: true);
      _scheduleNextCrossfade();
    } else {
      _zoomController.stop();
      _crossfadeController.stop();
    }
  }

  void _scheduleNextCrossfade() {
    Future<void>.delayed(const Duration(seconds: 4), () async {
      if (!mounted || !widget.animate) {
        return;
      }
      await _crossfadeController.forward(from: 0);
      if (!mounted) {
        return;
      }
      setState(() {
        _index = (_index + 1) % AuthKenBurnsCollage.frameAssets.length;
      });
      _crossfadeController.value = 0;
      _scheduleNextCrossfade();
    });
  }

  @override
  void dispose() {
    _crossfadeController.dispose();
    _zoomController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String current = AuthKenBurnsCollage.frameAssets[_index];
    final String next = AuthKenBurnsCollage
        .frameAssets[(_index + 1) % AuthKenBurnsCollage.frameAssets.length];
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        _crossfadeController,
        _zoomController,
      ]),
      builder: (BuildContext context, Widget? child) {
        final double zoom = 1.0 + (_zoomController.value * 0.14);
        final double fade = Curves.easeInOut.transform(_crossfadeController.value);
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Transform.scale(
              scale: zoom,
              child: _frame(current),
            ),
            Opacity(
              opacity: fade,
              child: Transform.scale(
                scale: zoom,
                child: _frame(next),
              ),
            ),
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: const ColoredBox(color: Colors.transparent),
            ),
            ColoredBox(
              color: Colors.black.withValues(alpha: 0.28),
            ),
          ],
        );
      },
    );
  }

  Widget _frame(String asset) {
    return Image.asset(
      asset,
      fit: BoxFit.cover,
      alignment: Alignment.center,
      errorBuilder: (
        BuildContext context,
        Object error,
        StackTrace? stackTrace,
      ) {
        return const ColoredBox(color: Color(0xFF0B1224));
      },
    );
  }
}
