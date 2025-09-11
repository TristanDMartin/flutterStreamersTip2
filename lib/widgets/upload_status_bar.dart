import 'package:flutter/material.dart';
import '../services/upload_status_manager.dart';

class UploadStatusBar extends StatefulWidget {
  const UploadStatusBar({super.key});

  @override
  State<UploadStatusBar> createState() => _UploadStatusBarState();
}

class _UploadStatusBarState extends State<UploadStatusBar> {
  final UploadStatusManager _uploadStatusManager = UploadStatusManager();

  @override
  void initState() {
    super.initState();
    _uploadStatusManager.addListener(_onUploadStatusChanged);
  }

  @override
  void dispose() {
    _uploadStatusManager.removeListener(_onUploadStatusChanged);
    super.dispose();
  }

  void _onUploadStatusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_uploadStatusManager.showStatusBar) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF9248D2).withValues(alpha:0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Progress indicator
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              value: _uploadStatusManager.currentProgress,
              strokeWidth: 2,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF9248D2)),
            ),
          ),
          const SizedBox(width: 12),
          
          // Status message
          Expanded(
            child: Text(
              _uploadStatusManager.currentStatusMessage,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          
          // Tap to view button
          if (_uploadStatusManager.currentJobId != null)
            GestureDetector(
              onTap: () => _showUploadDetails(context, _uploadStatusManager),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF9248D2).withValues(alpha:0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'View',
                  style: TextStyle(
                    color: Color(0xFF9248D2),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showUploadDetails(BuildContext context, UploadStatusManager uploadStatusManager) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(
                  Icons.cloud_upload,
                  color: Color(0xFF9248D2),
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Upload Progress',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Progress bar
            LinearProgressIndicator(
              value: uploadStatusManager.currentProgress,
              backgroundColor: Colors.white.withValues(alpha:0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF9248D2)),
            ),
            const SizedBox(height: 12),
            
            // Status text
            Text(
              uploadStatusManager.currentStatusMessage,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      if (uploadStatusManager.currentJobId != null) {
                        uploadStatusManager.cancelUpload(uploadStatusManager.currentJobId!);
                        Navigator.pop(context);
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // TODO: Implement retry functionality
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9248D2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Retry',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
