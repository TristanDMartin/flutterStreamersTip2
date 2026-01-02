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
    if (_isPicking) return; // Prevent multiple simultaneous picks

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

        // Validate the selected file
        final file = File(image.path);
        if (await file.exists()) {
          final fileSize = await file.length();
          debugPrint('📁 ImagePickerWidget: File size: $fileSize bytes');

          if (fileSize > 10 * 1024 * 1024) {
            // 10MB limit
            debugPrint('❌ ImagePickerWidget: File too large');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'Image file is too large. Please choose a smaller image (max 10MB).'),
                  backgroundColor: Colors.red,
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

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
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
    if (_isPicking) return; // Prevent multiple simultaneous picks

    setState(() {
      _isPicking = true;
    });

    try {
      // Get available cameras
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw Exception('No cameras available');
      }

      // Navigate to custom camera screen
      if (!mounted) return;
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: '/camera'),
          builder: (context) => CustomCameraScreen(
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

      // If no result (user cancelled), call onCancel
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
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6137EB), Color(0xFF1C135D)],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  const Text(
                    'Select Photo',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // Options
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                children: [
                  // Gallery option
                  _buildOption(
                    icon: Icons.photo_library,
                    title: 'Choose from Gallery',
                    subtitle: 'Select a photo from your gallery',
                    onTap: _pickImageFromGallery,
                  ),

                  const SizedBox(height: 12),

                  // Camera option
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                icon,
                color: Colors.white,
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Colors.grey,
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
      // print('❌ Error initializing camera: $e');
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
      // print('❌ Error capturing photo: $e');
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview
          if (_isInitialized && _controller != null)
            Positioned.fill(
              child: CameraPreview(_controller!),
            )
          else
            const Positioned.fill(
              child: Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              ),
            ),

          // Top bar with close button
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
                    // Close button
                    GestureDetector(
                      onTap: () {
                        // Close camera screen and image picker modal to return to edit profile
                        Navigator.pop(context); // Close camera screen
                        Navigator.pop(context); // Close image picker modal
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Camera switch button (if multiple cameras available)
                    if (widget.cameras.length > 1)
                      GestureDetector(
                        onTap: _switchCamera,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.flip_camera_ios,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Gallery button
                    GestureDetector(
                      onTap: () async {
                        final navigator = Navigator.of(context);
                        navigator.pop(); // Close camera screen
                        // Open gallery instead
                        final XFile? image = await _picker.pickImage(
                          source: ImageSource.gallery,
                          maxWidth: 1024,
                          maxHeight: 1024,
                          imageQuality: 85,
                        );
                        if (image != null) {
                          widget.onImageCaptured(File(image.path));
                        } else {
                          // If user cancels gallery, close image picker modal too
                          if (mounted && navigator.canPop()) {
                            navigator.pop();
                          }
                        }
                      },
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.photo_library,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),

                    // Capture button
                    GestureDetector(
                      onTap: _isCapturing ? null : _capturePhoto,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: _isCapturing ? Colors.grey : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 4,
                          ),
                        ),
                        child: _isCapturing
                            ? const Center(
                                child: SizedBox(
                                  width: 30,
                                  height: 30,
                                  child: CircularProgressIndicator(
                                    color: Colors.black,
                                    strokeWidth: 3,
                                  ),
                                ),
                              )
                            : const Center(
                                child: Icon(
                                  Icons.camera_alt,
                                  color: Colors.black,
                                  size: 32,
                                ),
                              ),
                      ),
                    ),

                    // Placeholder for symmetry
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

    final currentIndex = widget.cameras.indexOf(_controller!.description);
    final nextIndex = (currentIndex + 1) % widget.cameras.length;

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
