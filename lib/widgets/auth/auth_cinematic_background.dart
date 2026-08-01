import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import 'auth_ken_burns_collage.dart';

/// Full-bleed auth media: cinematic MP4 when present, else Ken Burns collage.
class AuthCinematicBackground extends StatefulWidget {
  const AuthCinematicBackground({super.key});

  static const String cinematicAssetPath = 'assets/auth/auth_cinematic.mp4';
  static const String staticFallbackAsset = 'assets/background.png';

  @override
  State<AuthCinematicBackground> createState() =>
      _AuthCinematicBackgroundState();
}

class _AuthCinematicBackgroundState extends State<AuthCinematicBackground>
    with WidgetsBindingObserver {
  VideoPlayerController? _videoController;
  bool _useVideo = false;
  bool _videoReady = false;
  bool _preferStatic = false;
  bool _lifecyclePaused = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.maybeOf(context)
                ?.disableAnimations ==
            true ||
        WidgetsBinding
                .instance.platformDispatcher.accessibilityFeatures.reduceMotion ==
            true;
    if (reduceMotion && !_preferStatic) {
      _preferStatic = true;
      _tearDownVideo();
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _bootstrap() async {
    final bool reduceMotion = WidgetsBinding
            .instance.platformDispatcher.accessibilityFeatures.reduceMotion ==
        true;
    if (reduceMotion) {
      if (mounted) {
        setState(() {
          _preferStatic = true;
        });
      }
      return;
    }
    final bool assetExists = await _cinematicAssetExists();
    if (!assetExists || !mounted) {
      return;
    }
    await _initVideo();
  }

  Future<bool> _cinematicAssetExists() async {
    try {
      final AssetManifest manifest =
          await AssetManifest.loadFromAssetBundle(rootBundle);
      final List<String> keys = manifest.listAssets();
      return keys.contains(AuthCinematicBackground.cinematicAssetPath);
    } catch (_) {
      try {
        await rootBundle.load(AuthCinematicBackground.cinematicAssetPath);
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  Future<void> _initVideo() async {
    try {
      final VideoPlayerController controller = VideoPlayerController.asset(
        AuthCinematicBackground.cinematicAssetPath,
      );
      _videoController = controller;
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _useVideo = true;
        _videoReady = true;
      });
      if (!_lifecyclePaused && !_preferStatic) {
        await controller.play();
      }
      debugPrint(
        'AuthCinematicBackground: playing '
        '${AuthCinematicBackground.cinematicAssetPath}',
      );
    } catch (error) {
      debugPrint('AuthCinematicBackground: video unavailable ($error)');
      await _tearDownVideo();
      if (mounted) {
        setState(() {
          _useVideo = false;
          _videoReady = false;
        });
      }
    }
  }

  Future<void> _tearDownVideo() async {
    final VideoPlayerController? controller = _videoController;
    _videoController = null;
    _useVideo = false;
    _videoReady = false;
    if (controller != null) {
      try {
        await controller.pause();
      } catch (_) {}
      await controller.dispose();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final VideoPlayerController? controller = _videoController;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _lifecyclePaused = true;
      if (controller != null && controller.value.isInitialized) {
        controller.pause();
      }
      return;
    }
    if (state == AppLifecycleState.resumed) {
      _lifecyclePaused = false;
      if (_useVideo &&
          !_preferStatic &&
          controller != null &&
          controller.value.isInitialized) {
        controller.play();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final VideoPlayerController? controller = _videoController;
    _videoController = null;
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool animateCollage = !_preferStatic &&
        !MediaQuery.disableAnimationsOf(context) &&
        !_lifecyclePaused;

    Widget media;
    if (_useVideo && _videoReady && _videoController != null) {
      media = SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: _videoController!.value.size.width,
            height: _videoController!.value.size.height,
            child: VideoPlayer(_videoController!),
          ),
        ),
      );
    } else if (_preferStatic) {
      media = Image.asset(
        AuthCinematicBackground.staticFallbackAsset,
        fit: BoxFit.cover,
        errorBuilder: (
          BuildContext context,
          Object error,
          StackTrace? stackTrace,
        ) {
          return const ColoredBox(color: Color(0xFF0B1224));
        },
      );
    } else {
      media = AuthKenBurnsCollage(animate: animateCollage);
    }

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // Soft blur keeps UI readable while motion remains visible.
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: media,
        ),
        // Brand wash — keep StreamersTip identity while letting motion show.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Color(0x999248D2),
                Color(0x804897D2),
                Color(0xB30B1224),
              ],
              stops: <double>[0.0, 0.48, 1.0],
            ),
          ),
        ),
        ColoredBox(
          color: Colors.black.withValues(alpha: 0.18),
        ),
      ],
    );
  }
}
