import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../services/navigation_observer.dart';
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
    with WidgetsBindingObserver, RouteAware {
  VideoPlayerController? _videoController;
  bool _useVideo = false;
  bool _videoReady = false;
  bool _preferStatic = false;
  bool _lifecyclePaused = false;
  bool _routeCovered = false;
  PageRoute<dynamic>? _route;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ModalRoute<dynamic>? route = ModalRoute.of(context);
    if (route != _route) {
      if (_route != null) {
        AppNavigationObserver.instance.unsubscribe(this);
      }
      _route = route is PageRoute<dynamic> ? route : null;
      if (_route != null) {
        AppNavigationObserver.instance.subscribe(this, _route!);
      }
    }
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.maybeOf(context)?.disableAnimations == true ||
        WidgetsBinding
                .instance.platformDispatcher.accessibilityFeatures.reduceMotion ==
            true;
    if (reduceMotion && !_preferStatic) {
      _preferStatic = true;
      unawaited(_tearDownVideo());
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  void didPushNext() {
    _setRouteCovered(true);
  }

  @override
  void didPopNext() {
    _setRouteCovered(false);
  }

  void _setRouteCovered(bool covered) {
    if (_routeCovered == covered) {
      return;
    }
    _routeCovered = covered;
    if (covered) {
      // Platform video views can punch through pushed Flutter routes.
      unawaited(_tearDownVideo());
      if (mounted) {
        setState(() {});
      }
      return;
    }
    if (!_preferStatic && !_lifecyclePaused) {
      unawaited(_initVideo());
    } else if (mounted) {
      setState(() {});
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
    if (_routeCovered || _preferStatic || _lifecyclePaused) {
      return;
    }
    if (_videoController != null && _videoReady) {
      return;
    }
    try {
      final VideoPlayerController controller = VideoPlayerController.asset(
        AuthCinematicBackground.cinematicAssetPath,
      );
      _videoController = controller;
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      if (!mounted || _routeCovered) {
        await controller.dispose();
        _videoController = null;
        return;
      }
      setState(() {
        _useVideo = true;
        _videoReady = true;
      });
      if (!_lifecyclePaused && !_preferStatic && !_routeCovered) {
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
    if (_route != null) {
      AppNavigationObserver.instance.unsubscribe(this);
    }
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
        !_lifecyclePaused &&
        !_routeCovered;

    Widget media;
    if (!_routeCovered &&
        _useVideo &&
        _videoReady &&
        _videoController != null) {
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
    } else if (_preferStatic || _routeCovered) {
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
