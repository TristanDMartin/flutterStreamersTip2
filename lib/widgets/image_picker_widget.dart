import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';

class ImagePickerWidget extends StatefulWidget {
  final Function(File) onImageSelected;
  final VoidCallback? onCancel;

  const ImagePickerWidget({
    super.key,
    required this.onImageSelected,
    this.onCancel,
  });

  @override
  State<ImagePickerWidget> createState() => _ImagePickerWidgetState();
}

class _ImagePickerWidgetState extends State<ImagePickerWidget> {
  final ImagePicker _picker = ImagePicker();
  bool _isPicking = false;

  Future<void> _pickImageFromGallery() async {
    if (_isPicking) return;
    setState(() {
      _isPicking = true;
    });
    try {
      debugPrint('📱 ImagePickerWidget: Opening gallery picker');
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image != null) {
        debugPrint(
            '✅ ImagePickerWidget: Image selected from gallery: ${image.path}');
        final file = File(image.path);
        if (await file.exists()) {
          final int fileSize = await file.length();
          debugPrint('📁 ImagePickerWidget: File size: $fileSize bytes');
          if (fileSize > 10 * 1024 * 1024) {
            debugPrint('❌ ImagePickerWidget: File too large');
            if (mounted) {
              final ColorScheme scheme = Theme.of(context).colorScheme;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text(
                    'Image file is too large. Please choose a smaller image (max 10MB).',
                  ),
                  backgroundColor: scheme.error,
                ),
              );
            }
            widget.onCancel?.call();
            return;
          }
          debugPrint('✅ ImagePickerWidget: Calling onImageSelected callback');
          widget.onImageSelected(file);
        } else {
          debugPrint('❌ ImagePickerWidget: Selected file does not exist');
          widget.onCancel?.call();
        }
      } else {
        debugPrint('ℹ️ ImagePickerWidget: Gallery picker cancelled');
        widget.onCancel?.call();
      }
    } catch (e) {
      debugPrint('❌ ImagePickerWidget: Error picking image from gallery: $e');
      if (mounted) {
        String errorMessage = 'Failed to pick image';
        if (e.toString().contains('Permission denied')) {
          errorMessage =
              'Permission denied. Please allow access to photos in settings.';
        } else if (e.toString().contains('User cancelled')) {
          errorMessage = 'Image selection cancelled.';
        } else {
          errorMessage = 'Failed to pick image: ${e.toString()}';
        }
        final ColorScheme scheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: scheme.error,
          ),
        );
      }
      widget.onCancel?.call();
    } finally {
      if (mounted) {
        setState(() {
          _isPicking = false;
        });
      }
    }
  }

  Future<void> _pickImageFromCamera() async {
    if (_isPicking) return;
    setState(() {
      _isPicking = true;
    });
    try {
      final List<CameraDescription> cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw Exception('No cameras available');
      }
      if (!mounted) return;
      final Object? result = await Navigator.push(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: '/camera'),
          builder: (BuildContext context) => CustomCameraScreen(
            cameras: cameras,
            onImageCaptured: (File imageFile) {
              widget.onImageSelected(imageFile);
            },
            onCancel: () {
              widget.onCancel?.call();
            },
          ),
        ),
      );
      if (result == null) {
        widget.onCancel?.call();
      }
    } catch (e) {
      debugPrint('❌ Error opening camera: $e');
      widget.onCancel?.call();
    } finally {
      if (mounted) {
        setState(() {
          _isPicking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color on = scheme.onSurface;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: scheme.outline.withValues(alpha: 0.35),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Text(
                    'Select Photo',
                    style: TextStyle(
                      color: on,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close,
                      color: on.withValues(alpha: 0.72),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                children: [
                  _buildOption(
                    icon: Icons.photo_library,
                    title: 'Choose from Gallery',
                    subtitle: 'Select a photo from your gallery',
                    onTap: _pickImageFromGallery,
                  ),
                  const SizedBox(height: 12),
                  _buildOption(
                    icon: Icons.camera_alt,
                    title: 'Take Photo',
                    subtitle: 'Take a new photo with camera',
                    onTap: _pickImageFromCamera,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color on = scheme.onSurface;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: on.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: scheme.outline.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                icon,
                color: scheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: on,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: on.withValues(alpha: 0.62),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: on.withValues(alpha: 0.45),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomCameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final Function(File) onImageCaptured;
  final VoidCallback onCancel;

  const CustomCameraScreen({
    super.key,
    required this.cameras,
    required this.onImageCaptured,
    required this.onCancel,
  });

  @override
  State<CustomCameraScreen> createState() => _CustomCameraScreenState();
}

class _CustomCameraScreenState extends State<CustomCameraScreen> {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isCapturing = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _controller = CameraController(
        widget.cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await _controller!.initialize();
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      widget.onCancel();
    }
  }

  Future<void> _capturePhoto() async {
    if (_controller == null || !_isInitialized || _isCapturing) return;
    setState(() {
      _isCapturing = true;
    });
    try {
      final XFile image = await _controller!.takePicture();
      widget.onImageCaptured(File(image.path));
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _isCapturing = false;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: Stack(
        children: [
          if (_isInitialized && _controller != null)
            Positioned.fill(
              child: CameraPreview(_controller!),
            )
          else
            Positioned.fill(
              child: ColoredBox(
                color: scheme.surface,
                child: Center(
                  child: CircularProgressIndicator(
                    color: scheme.primary,
                  ),
                ),
              ),
            ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pop(context);
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: scheme.scrim.withValues(alpha: 0.45),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close,
                          color: scheme.onPrimary,
                          size: 24,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (widget.cameras.length > 1)
                      GestureDetector(
                        onTap: _switchCamera,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: scheme.scrim.withValues(alpha: 0.45),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.flip_camera_ios,
                            color: scheme.onPrimary,
                            size: 24,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(alpha: 0.92),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final NavigatorState navigator =
                            Navigator.of(context);
                        navigator.pop();
                        final XFile? image = await _picker.pickImage(
                          source: ImageSource.gallery,
                          maxWidth: 1024,
                          maxHeight: 1024,
                          imageQuality: 85,
                        );
                        if (image != null) {
                          widget.onImageCaptured(File(image.path));
                        } else {
                          if (mounted && navigator.canPop()) {
                            navigator.pop();
                          }
                        }
                      },
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: scheme.onSurface.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.photo_library,
                          color: scheme.onSurface,
                          size: 24,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _isCapturing ? null : _capturePhoto,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: _isCapturing
                              ? scheme.onSurface.withValues(alpha: 0.25)
                              : scheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: scheme.onPrimary,
                            width: 4,
                          ),
                        ),
                        child: _isCapturing
                            ? Center(
                                child: SizedBox(
                                  width: 30,
                                  height: 30,
                                  child: CircularProgressIndicator(
                                    color: scheme.onPrimary,
                                    strokeWidth: 3,
                                  ),
                                ),
                              )
                            : Center(
                                child: Icon(
                                  Icons.camera_alt,
                                  color: scheme.onPrimary,
                                  size: 32,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 50),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _switchCamera() async {
    if (widget.cameras.length <= 1) return;
    final int currentIndex =
        widget.cameras.indexOf(_controller!.description);
    final int nextIndex = (currentIndex + 1) % widget.cameras.length;
    await _controller!.dispose();
    _controller = CameraController(
      widget.cameras[nextIndex],
      ResolutionPreset.high,
      enableAudio: false,
    );
    await _controller!.initialize();
    setState(() {});
  }
}
