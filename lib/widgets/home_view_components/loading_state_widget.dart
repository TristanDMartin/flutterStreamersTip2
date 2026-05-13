import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';

/// Loading state widget for HomeView.
class LoadingStateWidget extends StatelessWidget {
  const LoadingStateWidget({
    super.key,
    this.message = 'Loading videos...',
    this.showProgress = true,
  });

  final String message;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    if (showProgress) {
      return _FeedStartupPreview(message: message);
    }

    final ColorScheme c = Theme.of(context).colorScheme;
    final bool dark = c.brightness == Brightness.dark;
    final Color on = dark ? Colors.white : Colors.black;
    return ColoredBox(
      color: dark ? Colors.black : Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (showProgress) ...<Widget>[
                SizedBox(
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      c.primary.withValues(alpha: 0.82),
                    ),
                    strokeWidth: 2,
                  ),
                ),
                const SizedBox(height: 18),
              ],
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: on.withValues(alpha: 0.72),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedStartupPreview extends StatelessWidget {
  const _FeedStartupPreview({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final EdgeInsets padding = MediaQuery.paddingOf(context);
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const _PosterWash(),
          Positioned(
            top: padding.top + 18,
            left: 22,
            right: 22,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                _SkeletonPill(width: 76, height: 12, opacity: 0.38),
                const SizedBox(width: 18),
                _SkeletonPill(width: 58, height: 12, opacity: 0.2),
              ],
            ),
          ),
          Positioned(
            right: 18,
            bottom: padding.bottom + 126,
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _SkeletonCircle(size: 50),
                SizedBox(height: 20),
                _SkeletonCircle(size: 50),
                SizedBox(height: 20),
                _SkeletonCircle(size: 50),
                SizedBox(height: 20),
                _SkeletonCircle(size: 50),
              ],
            ),
          ),
          Positioned(
            left: 22,
            right: 92,
            bottom: padding.bottom + 104,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const _SkeletonPill(width: 118, height: 16, opacity: 0.45),
                const SizedBox(height: 12),
                const _SkeletonPill(width: double.infinity, height: 13),
                const SizedBox(height: 8),
                const FractionallySizedBox(
                  widthFactor: 0.72,
                  child: _SkeletonPill(width: double.infinity, height: 13),
                ),
                const SizedBox(height: 18),
                Text(
                  message == 'Loading videos...'
                      ? 'Getting your feed ready'
                      : message,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    shadows: <Shadow>[
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: padding.bottom + 84,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.86),
                border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PosterWash extends StatelessWidget {
  const _PosterWash();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            const Color(0xFF101827),
            const Color(0xFF182235),
            const Color(0xFF101010),
            Colors.black.withValues(alpha: 0.96),
          ],
          stops: const <double>[0, 0.34, 0.72, 1],
        ),
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _SkeletonCircle extends StatelessWidget {
  const _SkeletonCircle({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
    );
  }
}

class _SkeletonPill extends StatelessWidget {
  const _SkeletonPill({
    required this.width,
    required this.height,
    this.opacity = 0.24,
  });

  final double width;
  final double height;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

/// Error state widget for HomeView.
class ErrorStateWidget extends StatelessWidget {
  const ErrorStateWidget({
    super.key,
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final ColorScheme c = Theme.of(context).colorScheme;
    final Color on = c.onSurface;
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 30),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: c.outline.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.error_outline,
                color: c.error,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                'Something went wrong',
                style: TextStyle(
                  color: on,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: TextStyle(
                  color: on.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              if (onRetry != null) ...<Widget>[
                const SizedBox(height: 24),
                DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: AppColors.supportAccentGradient,
                    ),
                    borderRadius: BorderRadius.all(
                      Radius.circular(16),
                    ),
                  ),
                  child: ElevatedButton(
                    onPressed: onRetry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: c.onPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('Try Again'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
