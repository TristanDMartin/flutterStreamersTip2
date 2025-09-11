import 'package:flutter/material.dart';
import 'dart:async'; // Added for Timer

class UploadManager extends ChangeNotifier {
  bool _isUploading = false;
  double _progress = 0.0;
  String _tipText = "Uploading your video...";

  bool get isUploading => _isUploading;
  double get progress => _progress;
  String get tipText => _tipText;

  void startUpload() {
    _isUploading = true;
    _progress = 0.0;
    _tipText = "Uploading your video...";
    notifyListeners();
    
    // Simulate upload progress
    _simulateUpload();
  }

  void updateProgress(double progress) {
    _progress = progress;
    notifyListeners();
  }

  void updateTipText(String tipText) {
    _tipText = tipText;
    notifyListeners();
  }

  void completeUpload() {
    _isUploading = false;
    _progress = 1.0;
    _tipText = "Upload completed!";
    notifyListeners();
    
    // Reset after a delay
    Future.delayed(const Duration(seconds: 2), () {
      _progress = 0.0;
      _tipText = "Uploading your video...";
      notifyListeners();
    });
  }

  void failUpload() {
    _isUploading = false;
    _progress = 0.0;
    _tipText = "Upload failed";
    notifyListeners();
    
    // Reset after a delay
    Future.delayed(const Duration(seconds: 2), () {
      _tipText = "Uploading your video...";
      notifyListeners();
    });
  }

  void _simulateUpload() {
    const uploadDuration = Duration(seconds: 5);
    const updateInterval = Duration(milliseconds: 100);
    final totalSteps = uploadDuration.inMilliseconds ~/ updateInterval.inMilliseconds;
    int currentStep = 0;

    Timer.periodic(updateInterval, (timer) {
      if (!_isUploading) {
        timer.cancel();
        return;
      }

      currentStep++;
      final progress = currentStep / totalSteps;
      
      if (progress >= 1.0) {
        completeUpload();
        timer.cancel();
      } else {
        updateProgress(progress);
        
        // Update tip text based on progress
        if (progress < 0.3) {
          updateTipText("Preparing video...");
        } else if (progress < 0.7) {
          updateTipText("Uploading to server...");
        } else {
          updateTipText("Finalizing upload...");
        }
      }
    });
  }
}

class UploadBannerView extends StatelessWidget {
  final UploadManager uploadManager;

  const UploadBannerView({
    super.key,
    required this.uploadManager,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: uploadManager,
      builder: (context, child) {
        if (!uploadManager.isUploading) {
          return const SizedBox.shrink();
        }

        return AnimatedSlide(
          offset: Offset.zero,
          duration: const Duration(milliseconds: 300),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 40, 16, 0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha:0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Progress indicator
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Text(
                          "${(uploadManager.progress * 100).toInt()}%",
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      // Circular progress indicator
                      CircularProgressIndicator(
                        value: uploadManager.progress,
                        backgroundColor: Colors.grey.withValues(alpha: 0.3),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        strokeWidth: 3,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Text content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Uploading",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        uploadManager.tipText,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Cancel button
                GestureDetector(
                  onTap: uploadManager.failUpload,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 17,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Usage example
class UploadBannerViewExample extends StatefulWidget {
  const UploadBannerViewExample({super.key});

  @override
  State<UploadBannerViewExample> createState() => _UploadBannerViewExampleState();
}

class _UploadBannerViewExampleState extends State<UploadBannerViewExample> {
  late UploadManager uploadManager;

  @override
  void initState() {
    super.initState();
    uploadManager = UploadManager();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Main content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: uploadManager.startUpload,
                  child: const Text('Start Upload'),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: uploadManager.completeUpload,
                  child: const Text('Complete Upload'),
                ),
              ],
            ),
          ),
          
          // Upload banner (overlay)
          UploadBannerView(uploadManager: uploadManager),
        ],
      ),
    );
  }
}
