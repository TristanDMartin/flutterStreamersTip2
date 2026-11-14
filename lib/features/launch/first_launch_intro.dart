import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/st_theme_tokens.dart';

/// Official assets supplied for the opening sequence.
///
/// The requested files
/// `hf_20261029_050150_3df3a8c8-ed22-475c-8736-e8d250c1282b`
/// and `hf_20261029_023135_10071274-5dc2-4217-85d1-7417009da88a`
/// were not in this workspace. The opening uses the Tippy GIF and
/// StreamersTip logo files that were supplied with them.
const String kTippyOpeningWaveAsset =
    'assets/brand/official/tippy-opening-wave.gif';
const String kTippyOpeningStillAsset =
    'assets/brand/official/tippy-wave-full.png';
const String kStreamersTipGradientLogoAsset =
    'assets/brand/official/streamerstip-icon-gradient.png';
const String kStreamersTipWordmarkAsset =
    'assets/brand/official/streamerstip-wordmark-white.png';

class FirstLaunchIntroDecision {
  const FirstLaunchIntroDecision({
    required this.play,
  });

  final bool play;
}

/// Full introduction only for a first open with no returning session and
/// no pending deep link. Reduced motion still counts as a first open; the
/// sequence itself drops the motion.
FirstLaunchIntroDecision decideFirstLaunchIntro({
  required bool alreadySeen,
  required bool hasPriorSession,
  required bool hasPendingDeepLink,
}) {
  final bool play = !alreadySeen && !hasPriorSession && !hasPendingDeepLink;
  return FirstLaunchIntroDecision(play: play);
}

class FirstLaunchSequence extends StatefulWidget {
  const FirstLaunchSequence({
    super.key,
    required this.onFinished,
    this.reduceMotion = false,
    this.tippyDuration = const Duration(milliseconds: 2200),
    this.logoDuration = const Duration(milliseconds: 1600),
    this.reducedMotionDuration = const Duration(milliseconds: 500),
  });

  final VoidCallback onFinished;
  final bool reduceMotion;
  final Duration tippyDuration;
  final Duration logoDuration;
  final Duration reducedMotionDuration;

  @override
  State<FirstLaunchSequence> createState() => _FirstLaunchSequenceState();
}

class _FirstLaunchSequenceState extends State<FirstLaunchSequence>
    with SingleTickerProviderStateMixin {
  late final AnimationController _logoController;
  Timer? _phaseTimer;
  bool _showLogo = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(
      vsync: this,
      duration: widget.reduceMotion
          ? widget.reducedMotionDuration
          : widget.logoDuration,
    );
    if (widget.reduceMotion) {
      _showLogo = true;
      _logoController.value = 1;
      _phaseTimer = Timer(widget.reducedMotionDuration, _finish);
      return;
    }
    _phaseTimer = Timer(widget.tippyDuration, () {
      if (!mounted || _finished) {
        return;
      }
      setState(() => _showLogo = true);
      _logoController.forward().whenComplete(_finish);
    });
  }

  @override
  void dispose() {
    _phaseTimer?.cancel();
    _logoController.dispose();
    super.dispose();
  }

  void _finish() {
    if (_finished || !mounted) {
      return;
    }
    _finished = true;
    _phaseTimer?.cancel();
    _logoController.stop();
    widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    final Animation<double> curved = CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeOutCubic,
    );
    return Material(
      color: StThemeColors.darkBackground,
      child: SafeArea(
        child: Stack(
          children: <Widget>[
            Center(
              child: AnimatedSwitcher(
                duration: widget.reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 420),
                child: _showLogo
                    ? _LogoFrame(
                        key: const Key('first_launch_logo'), animation: curved)
                    : const _TippyFrame(key: Key('first_launch_tippy')),
              ),
            ),
            Positioned(
              top: 8,
              right: 12,
              child: TextButton(
                key: const Key('first_launch_skip'),
                onPressed: _finish,
                child: const Text('Skip'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TippyFrame extends StatelessWidget {
  const _TippyFrame({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Tippy waving',
      child: Image.asset(
        kTippyOpeningWaveAsset,
        width: 280,
        height: 280,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (BuildContext context, Object error, StackTrace? stack) {
          return Image.asset(
            kTippyOpeningStillAsset,
            width: 280,
            height: 280,
            fit: BoxFit.contain,
            errorBuilder:
                (BuildContext context, Object error, StackTrace? stack) {
              return const SizedBox(width: 280, height: 280);
            },
          );
        },
      ),
    );
  }
}

class _LogoFrame extends StatelessWidget {
  const _LogoFrame({
    super.key,
    required this.animation,
  });

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? child) {
        final double t = animation.value;
        return Opacity(
          opacity: t.clamp(0, 1),
          child: Transform.scale(
            scale: 0.88 + (0.12 * t),
            child: child,
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: StThemeColors.brandPurple.withValues(alpha: 0.45),
                  blurRadius: 36,
                  spreadRadius: 4,
                ),
                BoxShadow(
                  color: StThemeColors.brandBlue.withValues(alpha: 0.28),
                  blurRadius: 48,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(36),
              child: Image.asset(
                kStreamersTipGradientLogoAsset,
                width: 168,
                height: 168,
                fit: BoxFit.cover,
                errorBuilder:
                    (BuildContext context, Object error, StackTrace? stack) {
                  return const SizedBox(width: 168, height: 168);
                },
              ),
            ),
          ),
          const SizedBox(height: 28),
          Image.asset(
            kStreamersTipWordmarkAsset,
            width: 240,
            fit: BoxFit.contain,
            errorBuilder:
                (BuildContext context, Object error, StackTrace? stack) {
              return const SizedBox(width: 240, height: 36);
            },
          ),
        ],
      ),
    );
  }
}
