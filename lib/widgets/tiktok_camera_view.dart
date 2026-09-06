import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/publish/publish_validation_limits.dart';
import '../features/publish/video_draft.dart';
import '../utils/publish_artifact_audit.dart';
import '../utils/camera_file_audit.dart';
import '../services/tiktok_camera_service.dart';
import '../services/video_draft_store.dart';
import '../services/global_playback_manager.dart';
import '../providers/home_provider.dart';
import 'video_recording_preview.dart';
import 'package:streamers_tip/utils/secure_log.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Camera capture screen styled like a clean ChatGPT-style viewfinder:
/// rounded preview, back + shutter + overflow menu (flip / flash / gallery).
class TikTokCameraView extends ConsumerStatefulWidget {
  const TikTokCameraView({super.key});

  @override
  ConsumerState<TikTokCameraView> createState() => _TikTokCameraViewState();
}

class _TikTokCameraViewState extends ConsumerState<TikTokCameraView>
    with WidgetsBindingObserver {
  static const Color _ringGold = Color(0xFFC9B896);
  static const Color _controlFill = Color(0x99000000);
  static const double _previewRadius = 36;
  static final int _maxRecordingSeconds =
      PublishValidationLimits.maxVideoDurationSeconds.toInt();

  final TikTokCameraService _cameraService = TikTokCameraService();
  final ImagePicker _imagePicker = ImagePicker();
  final GlobalKey _previewKey = GlobalKey();

  bool _isInitialized = false;
  bool _isRecording = false;
  bool _isFocusing = false;
  bool _isMenuOpen = false;
  bool _isFlashOn = false;
  bool _isReleasingCamera = false;
  bool _isOpeningSettings = false;
  bool _startInFlight = false;
  bool _stopInFlight = false;
  bool _stopRequested = false;
  DateTime? _pressDownAt;
  DateTime? _recordStartedAt;
  TikTokCameraPermissionResult? _permissionBlocker;
  Offset? _focusPoint;
  double _currentZoom = 1.0;
  Timer? _recordingTimer;
  int _recordingDuration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    GlobalPlaybackManager.instance.block(reason: 'cameraViewOpened');
    GlobalPlaybackManager.instance.pauseAll();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        ref.read(homeProvider.notifier).pauseAllVideos();
      } catch (e) {
        secureLog('⚠️ TikTokCameraView: Could not pause via home provider: $e');
      }
    });
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _initializeCamera();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_maybeOfferResumeDraft());
    });
  }

  Future<void> _maybeOfferResumeDraft() async {
    if (!mounted) {
      return;
    }
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    final VideoDraft? draft =
        await VideoDraftStore.instance.latestResumable(ownerUid: uid);
    if (draft == null || !mounted || !draft.hasMeaningfulEdits) {
      return;
    }
    final bool? resume = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Resume draft?'),
          content: const Text(
            'You have an unfinished video edit. Continue where you left off?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Discard'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Resume'),
            ),
          ],
        );
      },
    );
    if (!mounted) {
      return;
    }
    if (resume == true) {
      await _openDraftEditor(draft);
      return;
    }
    await VideoDraftStore.instance.delete(draft.draftId);
  }

  Future<void> _openDraftEditor(VideoDraft draft) async {
    if (mounted) {
      setState(() {
        _isInitialized = false;
        _isReleasingCamera = true;
        _isRecording = false;
        _isMenuOpen = false;
      });
    }
    await _cameraService.dispose();
    if (!mounted) {
      return;
    }
    setState(() => _isReleasingCamera = false);
    await Navigator.of(context).push<Object?>(
      MaterialPageRoute<Object?>(
        settings: const RouteSettings(name: '/camera/preview'),
        builder: (BuildContext context) => VideoRecordingPreview(draft: draft),
      ),
    );
    if (!mounted) {
      return;
    }
    await _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recordingTimer?.cancel();
    _isInitialized = false;
    _isReleasingCamera = true;
    unawaited(_cameraService.dispose());
    GlobalPlaybackManager.instance.unblock();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      _pauseCamera();
    } else if (state == AppLifecycleState.resumed) {
      _resumeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final TikTokCameraPermissionResult permission =
          await _cameraService.ensurePermissions();
      if (permission != TikTokCameraPermissionResult.granted) {
        if (mounted) {
          setState(() {
            _isInitialized = false;
            _permissionBlocker = permission;
          });
        }
        return;
      }
      if (mounted) {
        setState(() => _permissionBlocker = null);
      }
      await _cameraService.initialize();
      if (_cameraService.controller != null &&
          _cameraService.controller!.value.isInitialized) {
        try {
          final double minZoom =
              await _cameraService.controller!.getMinZoomLevel();
          await _cameraService.controller!.setZoomLevel(minZoom);
          _currentZoom = minZoom;
        } catch (e) {
          secureLog('⚠️ TikTokCameraView: Could not set min zoom: $e');
        }
      }
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isFlashOn = _cameraService.isFlashOn;
          _permissionBlocker = null;
        });
      }
    } catch (e) {
      secureLog('❌ TikTokCameraView: Camera initialization failed: $e');
      final String message = e.toString();
      if (message.contains('Camera permission') ||
          message.contains('permission')) {
        if (mounted) {
          setState(() {
            _permissionBlocker =
                TikTokCameraPermissionResult.permanentlyDenied;
          });
        }
        return;
      }
      _showErrorDialog('Camera initialization failed: ${e.toString()}');
    }
  }

  Future<void> _pauseCamera() async {
    if (_isRecording) {
      await _stopRecording();
    }
  }

  Future<void> _resumeCamera() async {
    if (_isOpeningSettings || _permissionBlocker != null || !_isInitialized) {
      await _initializeCamera();
    }
  }

  Future<void> _openAppSettingsForCamera() async {
    setState(() => _isOpeningSettings = true);
    await _cameraService.openSystemSettings();
    if (mounted) {
      setState(() => _isOpeningSettings = false);
    }
  }

  void _onTapToFocus(TapDownDetails details) async {
    if (!_isInitialized || _isRecording) return;
    try {
      final RenderObject? renderObject =
          _previewKey.currentContext?.findRenderObject();
      if (renderObject is! RenderBox) return;
      final Offset localPoint =
          renderObject.globalToLocal(details.globalPosition);
      final double clampedX =
          (localPoint.dx / renderObject.size.width).clamp(0.0, 1.0);
      final double clampedY =
          (localPoint.dy / renderObject.size.height).clamp(0.0, 1.0);
      setState(() {
        _focusPoint = localPoint;
        _isFocusing = true;
        _isMenuOpen = false;
      });
      await _cameraService.setFocusPoint(Offset(clampedX, clampedY));
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() => _isFocusing = false);
        }
      });
      HapticFeedback.lightImpact();
    } catch (e) {
      secureLog('❌ Error setting focus: $e');
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails details) async {
    if (!_isInitialized || _isRecording) return;
    try {
      final double newZoom = (_currentZoom * details.scale).clamp(1.0, 4.0);
      setState(() => _currentZoom = newZoom);
      await _cameraService.setZoomLevel(newZoom);
    } catch (e) {
      secureLog('❌ Error setting zoom: $e');
    }
  }

  Future<void> _onRecordPressDown() async {
    debugPrint(
      'RECORD_PRESS_DOWN timestamp=${DateTime.now().millisecondsSinceEpoch}',
    );
    _pressDownAt = DateTime.now();
    _stopRequested = false;
    await _startRecording();
  }

  Future<void> _onRecordPressUp() async {
    debugPrint(
      'RECORD_PRESS_UP timestamp=${DateTime.now().millisecondsSinceEpoch}',
    );
    _stopRequested = true;
    // Wait for in-flight start so we never drop the stop.
    while (_startInFlight) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    await _stopRecording();
  }

  Future<void> _startRecording() async {
    if (!_isInitialized || _isRecording || _startInFlight || _stopInFlight) {
      return;
    }
    _startInFlight = true;
    try {
      setState(() => _isMenuOpen = false);
      await _cameraService.startRecording();
      if (!mounted) {
        return;
      }
      _recordStartedAt = DateTime.now();
      setState(() {
        _isRecording = true;
        _recordingDuration = 0;
      });
      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() => _recordingDuration++);
        if (_recordingDuration >= _maxRecordingSeconds) {
          timer.cancel();
          unawaited(_stopRecording());
        }
      });
      HapticFeedback.mediumImpact();
      // If finger already released during start, stop immediately after min hold.
      if (_stopRequested) {
        await _stopRecording();
      }
    } catch (e) {
      secureLog('❌ Error starting recording: $e');
      _showErrorDialog('Failed to start recording: ${e.toString()}');
    } finally {
      _startInFlight = false;
    }
  }

  Future<void> _stopRecording() async {
    if (_stopInFlight) {
      return;
    }
    if (!_isRecording && !_cameraService.isRecording) {
      return;
    }
    _stopInFlight = true;
    try {
      // Enforce a short minimum record window so MediaRecorder can flush.
      final DateTime? started = _recordStartedAt;
      if (started != null) {
        final int elapsedMs =
            DateTime.now().difference(started).inMilliseconds;
        if (elapsedMs < 1000) {
          await Future<void>.delayed(
            Duration(milliseconds: 1000 - elapsedMs),
          );
        }
      }
      final XFile videoFile = await _cameraService.stopRecording();
      _recordingTimer?.cancel();
      _recordingTimer = null;
      _recordStartedAt = null;
      if (mounted) {
        setState(() => _isRecording = false);
      }
      HapticFeedback.lightImpact();
      final File recorded = File(videoFile.path);
      final int recordedBytes = await waitForStableFileBytes(recorded);
      final int holdMs = _pressDownAt == null
          ? 0
          : DateTime.now().difference(_pressDownAt!).inMilliseconds;
      debugPrint(
        'CAMERA_RECORD_STOP originalPath=${recorded.path} '
        'exists=${await recorded.exists()} bytes=$recordedBytes '
        'durationMs=$holdMs width=0 height=0',
      );
      logCameraFileAudit(
        stage: 'camera_original',
        path: recorded.path,
        bytes: recordedBytes,
      );
      if (recordedBytes < PublishArtifactAudit.minBytes) {
        _showErrorDialog(
          'Recording is incomplete (${(recordedBytes / 1024).toStringAsFixed(1)} KB). '
          'Hold to record for at least 1 second.',
        );
        return;
      }
      if (mounted) {
        await _openPreviewAndMaybePublish(
          recorded,
          sourceType: VideoDraftSourceType.camera,
        );
      }
    } catch (e) {
      secureLog('❌ Error stopping recording: $e');
      if (mounted) {
        setState(() => _isRecording = false);
      }
      _showErrorDialog('Failed to stop recording: ${e.toString()}');
    } finally {
      _stopInFlight = false;
      _stopRequested = false;
    }
  }

  Future<void> _switchCamera() async {
    if (!_isInitialized || _isRecording || _isReleasingCamera) return;
    try {
      setState(() {
        _isInitialized = false;
        _isMenuOpen = false;
      });
      await _cameraService.switchCamera();
      if (_cameraService.currentLensDirection == CameraLensDirection.front &&
          _cameraService.isFlashOn) {
        await _cameraService.setFlashMode(FlashMode.off);
      }
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isFlashOn = _cameraService.isFlashOn;
        });
      }
      HapticFeedback.lightImpact();
    } catch (e) {
      secureLog('❌ Error switching camera: $e');
      if (mounted) {
        setState(() => _isInitialized = _cameraService.isInitialized);
      }
      _showErrorDialog('Failed to switch camera: ${e.toString()}');
    }
  }

  Future<void> _toggleFlash() async {
    if (!_isInitialized || _isRecording) return;
    if (_cameraService.currentLensDirection == CameraLensDirection.front) {
      _showErrorDialog('Flash is unavailable on the front camera.');
      return;
    }
    try {
      await _cameraService.toggleFlash();
      if (mounted) {
        setState(() => _isFlashOn = _cameraService.isFlashOn);
      }
      HapticFeedback.lightImpact();
    } catch (e) {
      secureLog('❌ Error toggling flash: $e');
      _showErrorDialog('Failed to toggle flash: ${e.toString()}');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      setState(() => _isMenuOpen = false);
      final XFile? video = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );
      if (video != null && mounted) {
        HapticFeedback.lightImpact();
        await _openPreviewAndMaybePublish(
          File(video.path),
          sourceType: VideoDraftSourceType.gallery,
        );
      }
    } catch (e) {
      secureLog('❌ Error picking video from gallery: $e');
      _showErrorDialog('Error selecting video: ${e.toString()}');
    }
  }

  Future<void> _openPreviewAndMaybePublish(
    File videoFile, {
    required VideoDraftSourceType sourceType,
  }) async {
    // Fast gate only — full decode probe belongs at publish, not selection.
    // VideoPlayer.initialize on large gallery clips was blocking the editor
    // for many seconds after pick.
    if (mounted) {
      setState(() {
        _isReleasingCamera = true;
        _isMenuOpen = false;
      });
    }
    final PublishArtifactAudit previewAudit = await PublishArtifactAudit.inspect(
      file: videoFile,
      stage: 'preview_input',
      probeDecode: false,
    );
    if (!previewAudit.isAcceptable) {
      if (mounted) {
        setState(() => _isReleasingCamera = false);
      }
      _showErrorDialog(
        previewAudit.rejectReason ??
            'Recording is incomplete. Please record again.',
      );
      return;
    }
    late final VideoDraft draft;
    try {
      draft = await VideoDraftStore.instance.createFromSource(
        sourceFile: videoFile,
        duration: Duration.zero,
        sourceType: sourceType,
      );
    } catch (e) {
      secureLog('❌ Draft create failed: $e');
      if (mounted) {
        setState(() => _isReleasingCamera = false);
        _showErrorDialog('Could not save recording. Please try again.');
      }
      return;
    }
    final int draftBytes = await fileByteLengthOrZero(draft.sourceFile);
    logCameraFileAudit(
      stage: 'publish_input',
      path: draft.sourceFilePath,
      bytes: draftBytes,
    );
    if (draftBytes < PublishArtifactAudit.minBytes) {
      await VideoDraftStore.instance.delete(draft.draftId);
      if (mounted) {
        setState(() => _isReleasingCamera = false);
        _showErrorDialog(
          'Recording copy is incomplete. Please record again.',
        );
      }
      return;
    }
    if (!mounted) {
      return;
    }
    if (mounted) {
      setState(() {
        _isInitialized = false;
        _isRecording = false;
        _isReleasingCamera = false;
      });
    }
    // Push editor first so selection feels instant; release camera underneath.
    final Future<Object?> opened = Navigator.of(context).push<Object?>(
      MaterialPageRoute<Object?>(
        settings: const RouteSettings(name: '/camera/preview'),
        builder: (BuildContext context) => VideoRecordingPreview(draft: draft),
      ),
    );
    unawaited(_cameraService.dispose());
    await opened;
    if (!mounted) {
      return;
    }
    secureLog('🎬 TikTokCameraView: Returned from edit/share flow');
    await _initializeCamera();
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Camera Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final int minutes = seconds ~/ 60;
    final int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:'
        '${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _toggleMenu() {
    if (_isRecording || !_isInitialized) return;
    HapticFeedback.selectionClick();
    setState(() => _isMenuOpen = !_isMenuOpen);
  }

  @override
  Widget build(BuildContext context) {
    final EdgeInsets padding = MediaQuery.of(context).padding;
    final Size screen = MediaQuery.of(context).size;
    // Match ChatGPT: large black top field, viewfinder in lower ~70%.
    final double topFieldHeight = math.max(120.0, screen.height * 0.26);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: topFieldHeight,
            child: Padding(
              padding: EdgeInsets.only(
                top: padding.top + 12,
                left: 20,
                right: 20,
              ),
              child: const Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: EdgeInsets.only(bottom: 14),
                  child: Text(
                    'Create',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                12,
                0,
                12,
                padding.bottom + 10,
              ),
              child: _buildViewfinder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewfinder() {
    if (_permissionBlocker != null) {
      return _buildPermissionGate(_permissionBlocker!);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(_previewRadius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildCameraPreview(),
          if (_isFocusing) _buildFocusIndicator(),
          if (_isRecording) _buildRecordingBadge(),
          _buildBottomControls(),
          if (_isMenuOpen) _buildMenuScrim(),
          if (_isMenuOpen) _buildOverflowMenu(),
        ],
      ),
    );
  }

  Widget _buildPermissionGate(TikTokCameraPermissionResult blocker) {
    final bool needsMic =
        blocker == TikTokCameraPermissionResult.microphoneDenied;
    final String title = needsMic
        ? 'Microphone access needed'
        : 'Camera access needed';
    final String body = needsMic
        ? 'StreamersTip needs microphone access to record videos with sound.'
        : 'StreamersTip needs camera access to record videos.';
    return ClipRRect(
      borderRadius: BorderRadius.circular(_previewRadius),
      child: ColoredBox(
        color: Colors.black,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.videocam_off_outlined,
                color: Colors.white70,
                size: 48,
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                body,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isOpeningSettings
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        unawaited(_openAppSettingsForCamera());
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: _ringGold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 14,
                  ),
                ),
                child: Text(
                  _isOpeningSettings ? 'Opening…' : 'Open Settings',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  unawaited(_initializeCamera());
                },
                child: const Text(
                  'Try again',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (_isReleasingCamera || !_isInitialized) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }
    final bool isFrontCamera =
        _cameraService.currentLensDirection == CameraLensDirection.front;
    final CameraController? controller = _cameraService.controller;
    if (controller == null) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }
    final Size? previewSize;
    try {
      if (!controller.value.isInitialized) {
        return const ColoredBox(
          color: Colors.black,
          child: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        );
      }
      previewSize = controller.value.previewSize;
    } catch (_) {
      return const ColoredBox(color: Colors.black);
    }
    if (previewSize == null) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }
    final Size ps = previewSize;
    final double cameraAspectPortrait = ps.height / ps.width;
    final bool is16by9 = (cameraAspectPortrait - 1.778).abs() < 0.02;
    const double target16by9Portrait = 16.0 / 9.0;
    final double displayAspectRatio =
        is16by9 ? cameraAspectPortrait : target16by9Portrait;
    final Widget cameraPreview = AspectRatio(
      aspectRatio: displayAspectRatio,
      child: Transform(
        alignment: Alignment.center,
        transform:
            isFrontCamera ? Matrix4.rotationY(math.pi) : Matrix4.identity(),
        child: ClipRect(
          child: CameraPreview(
            controller,
            key: ValueKey<String>(
              '${_cameraService.currentLensDirection}_'
              '${identityHashCode(controller)}',
            ),
          ),
        ),
      ),
    );
    return GestureDetector(
      key: _previewKey,
      onTapDown: _onTapToFocus,
      onScaleUpdate: _onScaleUpdate,
      child: ColoredBox(
        color: Colors.black,
        child: FittedBox(
          fit: BoxFit.cover,
          alignment: Alignment.center,
          child: SizedBox(
            width: is16by9 ? ps.height : ps.width * (9.0 / 16.0),
            height: ps.width,
            child: cameraPreview,
          ),
        ),
      ),
    );
  }

  Widget _buildFocusIndicator() {
    if (_focusPoint == null) return const SizedBox.shrink();
    return Positioned(
      left: _focusPoint!.dx - 30,
      top: _focusPoint!.dy - 30,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 2),
          borderRadius: BorderRadius.circular(30),
        ),
      ),
    );
  }

  Widget _buildRecordingBadge() {
    return Positioned(
      top: 20,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xE6FF3B30),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatDuration(_recordingDuration),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      left: 20,
      right: 20,
      bottom: 22,
      child: Opacity(
        opacity: _isInitialized ? 1 : 0.55,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildCircleButton(
              icon: Icons.chevron_left_rounded,
              onTap: () => Navigator.of(context).pop(),
              semanticLabel: 'Close camera',
            ),
            _buildShutterButton(),
            _buildCircleButton(
              icon: Icons.more_horiz_rounded,
              onTap: _toggleMenu,
              semanticLabel: 'Camera options',
              isActive: _isMenuOpen,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuScrim() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _isMenuOpen = false),
        behavior: HitTestBehavior.opaque,
        child: const ColoredBox(color: Color(0x33000000)),
      ),
    );
  }

  Widget _buildOverflowMenu() {
    final bool isFront =
        _cameraService.currentLensDirection == CameraLensDirection.front;
    return Positioned(
      right: 20,
      bottom: 92,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildMenuAction(
            icon: Icons.photo_library_outlined,
            label: 'Gallery',
            onTap: _pickFromGallery,
          ),
          const SizedBox(height: 12),
          _buildMenuAction(
            icon: _isFlashOn
                ? Icons.flash_on_rounded
                : Icons.flash_off_rounded,
            label: _isFlashOn ? 'Flash on' : 'Flash off',
            onTap: _toggleFlash,
            isActive: _isFlashOn,
            isDisabled: isFront,
          ),
          const SizedBox(height: 12),
          _buildMenuAction(
            icon: Icons.cameraswitch_rounded,
            label: isFront ? 'Front camera' : 'Rear camera',
            onTap: _switchCamera,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
    bool isDisabled = false,
  }) {
    return Semantics(
      button: true,
      label: label,
      enabled: !isDisabled,
      child: GestureDetector(
        onTap: isDisabled ? null : onTap,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: isDisabled ? 0.4 : 1,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isActive ? _ringGold.withValues(alpha: 0.28) : _controlFill,
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive ? _ringGold : _ringGold.withValues(alpha: 0.55),
                width: 1.2,
              ),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onTap,
    required String semanticLabel,
    bool isActive = false,
  }) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isActive ? _ringGold.withValues(alpha: 0.22) : _controlFill,
            shape: BoxShape.circle,
            border: Border.all(
              color: _ringGold.withValues(alpha: 0.7),
              width: 1.2,
            ),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 26,
          ),
        ),
      ),
    );
  }

  Widget _buildShutterButton() {
    return Semantics(
      button: true,
      label: _isRecording ? 'Stop recording' : 'Start recording',
      child: GestureDetector(
        onTapDown: (_) {
          unawaited(_onRecordPressDown());
        },
        onTapUp: (_) {
          unawaited(_onRecordPressUp());
        },
        onTapCancel: () {
          unawaited(_onRecordPressUp());
        },
        child: Container(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: _isRecording ? const Color(0xFFFF5F57) : _ringGold,
              width: 3,
            ),
          ),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: _isRecording ? 30 : 62,
              height: _isRecording ? 30 : 62,
              decoration: BoxDecoration(
                color: _isRecording ? const Color(0xFFFF5F57) : Colors.white,
                borderRadius: BorderRadius.circular(_isRecording ? 8 : 31),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
