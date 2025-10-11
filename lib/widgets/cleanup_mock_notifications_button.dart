import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/cleanup_mock_notifications.dart';

/// Temporary widget to clean up mock notifications
///
/// Usage: Add this button to ActivityView temporarily, tap to clean up,
/// then remove this widget after cleanup is done.
class CleanupMockNotificationsButton extends StatelessWidget {
  const CleanupMockNotificationsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 100,
      right: 16,
      child: FloatingActionButton.extended(
        onPressed: () => _handleCleanup(context),
        backgroundColor: Colors.red.shade700,
        icon: const Icon(Icons.cleaning_services),
        label: const Text('Clean Mock Data'),
      ),
    );
  }

  Future<void> _handleCleanup(BuildContext context) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      _showSnackBar(context, 'Not signed in');
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Clean Mock Data?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will delete all test notifications (test_user_1, video_1, etc.) but keep your real notifications.\n\nContinue?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Clean Up',
              style: TextStyle(color: Colors.red.shade400),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      _showSnackBar(context, 'Cleaning up mock notifications...');

      final cleanup = CleanupMockNotifications();
      await cleanup.cleanupForUser(userId);

      if (context.mounted) {
        _showSnackBar(context, 'Cleanup complete! Pull to refresh.',
            isSuccess: true);
      }
    } catch (e) {
      if (context.mounted) {
        _showSnackBar(context, 'Error: $e', isError: true);
      }
    }
  }

  void _showSnackBar(BuildContext context, String message,
      {bool isSuccess = false, bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Colors.red.shade900
            : isSuccess
                ? Colors.green.shade700
                : const Color(0xFF9248D2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        duration: Duration(seconds: isSuccess || isError ? 3 : 2),
      ),
    );
  }
}
