import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/scheduled_post.dart';
import '../services/scheduled_post_service.dart';

class PlatformReconnectionView extends StatefulWidget {
  final ScheduledPost post;

  const PlatformReconnectionView({
    super.key,
    required this.post,
  });

  @override
  State<PlatformReconnectionView> createState() => _PlatformReconnectionViewState();
}

class _PlatformReconnectionViewState extends State<PlatformReconnectionView> {
  final ScheduledPostService _postService = ScheduledPostService();
  
  bool _isLoading = false;
  Map<String, bool> _reconnectionStatus = {};
  Map<String, String> _reconnectionErrors = {};

  @override
  void initState() {
    super.initState();
    _initializeReconnectionStatus();
  }

  void _initializeReconnectionStatus() {
    for (final platform in widget.post.platforms) {
      _reconnectionStatus[platform.key] = false;
      _reconnectionErrors[platform.key] = '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6137EB), Color(0xFF1C135D)],
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Fix Platform Connections',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildPlatformsList(),
                const SizedBox(height: 24),
                _buildActionButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.amber,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Platform Connection Issues',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Some platforms need to be reconnected to continue publishing. Please re-authenticate with each platform.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Platforms Requiring Reconnection',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        ...widget.post.platforms
            .where((platform) => platform.status == PlatformStatus.needsReauth)
            .map((platform) => _buildPlatformCard(platform)),
      ],
    );
  }

  Widget _buildPlatformCard(PlatformConfig platform) {
    final isReconnecting = _reconnectionStatus[platform.key] ?? false;
    final hasError = _reconnectionErrors[platform.key]?.isNotEmpty ?? false;
    final isConnected = platform.status == PlatformStatus.published || 
                       platform.status == PlatformStatus.pending;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasError 
              ? Colors.red.withValues(alpha: 0.3)
              : isConnected 
                  ? Colors.green.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getPlatformIcon(platform.key),
                color: _getPlatformColor(platform.key),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getPlatformName(platform.key),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getPlatformStatusText(platform.status ?? PlatformStatus.pending),
                      style: TextStyle(
                        color: _getPlatformStatusColor(platform.status ?? PlatformStatus.pending),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (isConnected)
                const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 20,
                )
              else if (isReconnecting)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9248D2)),
                  ),
                )
              else
                IconButton(
                  icon: const Icon(Icons.refresh, color: Color(0xFF9248D2)),
                  onPressed: () => _reconnectPlatform(platform),
                ),
            ],
          ),
          if (hasError) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _reconnectionErrors[platform.key]!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (platform.status == PlatformStatus.needsReauth) ...[
            const SizedBox(height: 12),
            Text(
              _getReconnectionInstructions(platform.key),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final needsReconnection = widget.post.platforms
        .any((platform) => platform.status == PlatformStatus.needsReauth);
    
    if (!needsReconnection) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 24),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'All platforms are connected and ready to publish!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _reconnectAllPlatforms,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9248D2),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Reconnect All Platforms',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _isLoading ? null : _retryFailedPublishes,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF9248D2)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Retry Failed Publishes',
              style: TextStyle(
                color: Color(0xFF9248D2),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _reconnectPlatform(PlatformConfig platform) async {
    setState(() {
      _reconnectionStatus[platform.key] = true;
      _reconnectionErrors[platform.key] = '';
    });

    try {
      HapticFeedback.lightImpact();
      
      // Simulate reconnection process
      await Future.delayed(const Duration(seconds: 2));
      
      // Simulate success/failure
      final success = DateTime.now().millisecond % 2 == 0;
      
      if (success) {
        setState(() {
          // Create a new PlatformConfig with updated status
          final updatedPlatform = platform.copyWith(status: PlatformStatus.pending);
          final postIndex = widget.post.platforms.indexOf(platform);
          widget.post.platforms[postIndex] = updatedPlatform;
          _reconnectionStatus[platform.key] = false;
        });
        _showSuccessSnackBar('${_getPlatformName(platform.key)} reconnected successfully!');
      } else {
        setState(() {
          _reconnectionStatus[platform.key] = false;
          _reconnectionErrors[platform.key] = 'Failed to authenticate. Please try again.';
        });
        _showErrorSnackBar('Failed to reconnect ${_getPlatformName(platform.key)}');
      }
    } catch (e) {
      setState(() {
        _reconnectionStatus[platform.key] = false;
        _reconnectionErrors[platform.key] = 'Connection error: $e';
      });
      _showErrorSnackBar('Error reconnecting ${_getPlatformName(platform.key)}: $e');
    }
  }

  Future<void> _reconnectAllPlatforms() async {
    setState(() {
      _isLoading = true;
    });

    try {
      HapticFeedback.lightImpact();
      
      final platformsToReconnect = widget.post.platforms
          .where((platform) => platform.status == PlatformStatus.needsReauth)
          .toList();

      for (final platform in platformsToReconnect) {
        await _reconnectPlatform(platform);
        await Future.delayed(const Duration(milliseconds: 500));
      }

      _showSuccessSnackBar('All platforms reconnection completed!');
    } catch (e) {
      _showErrorSnackBar('Error during bulk reconnection: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _retryFailedPublishes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      HapticFeedback.lightImpact();
      
      // Simulate retry process
      await Future.delayed(const Duration(seconds: 2));
      
      _showSuccessSnackBar('Retrying failed publishes...');
      
      // Navigate back to manage posts
      Navigator.pop(context);
    } catch (e) {
      _showErrorSnackBar('Error retrying publishes: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getPlatformName(String platform) {
    switch (platform) {
      case 'youtube':
        return 'YouTube';
      case 'tiktok':
        return 'TikTok';
      case 'instagram':
        return 'Instagram';
      case 'x':
        return 'X (Twitter)';
      case 'facebook':
        return 'Facebook';
      case 'linkedin':
        return 'LinkedIn';
      default:
        return platform;
    }
  }

  IconData _getPlatformIcon(String platform) {
    switch (platform) {
      case 'youtube':
        return Icons.play_circle_filled;
      case 'tiktok':
        return Icons.music_note;
      case 'instagram':
        return Icons.camera_alt;
      case 'x':
        return Icons.alternate_email;
      case 'facebook':
        return Icons.facebook;
      case 'linkedin':
        return Icons.business;
      default:
        return Icons.public;
    }
  }

  Color _getPlatformColor(String platform) {
    switch (platform) {
      case 'youtube':
        return Colors.red;
      case 'tiktok':
        return Colors.black;
      case 'instagram':
        return Colors.purple;
      case 'x':
        return Colors.blue;
      case 'facebook':
        return Colors.blue;
      case 'linkedin':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getPlatformStatusText(PlatformStatus status) {
    switch (status) {
      case PlatformStatus.pending:
        return 'Ready to publish';
      case PlatformStatus.publishing:
        return 'Publishing...';
      case PlatformStatus.published:
        return 'Published successfully';
      case PlatformStatus.failed:
        return 'Publishing failed';
      case PlatformStatus.needsReauth:
        return 'Needs re-authentication';
      case PlatformStatus.canceled:
        return 'Publishing canceled';
    }
  }

  Color _getPlatformStatusColor(PlatformStatus status) {
    switch (status) {
      case PlatformStatus.pending:
        return Colors.blue;
      case PlatformStatus.publishing:
        return Colors.orange;
      case PlatformStatus.published:
        return Colors.green;
      case PlatformStatus.failed:
        return Colors.red;
      case PlatformStatus.needsReauth:
        return Colors.amber;
      case PlatformStatus.canceled:
        return Colors.grey;
    }
  }

  String _getReconnectionInstructions(String platform) {
    switch (platform) {
      case 'youtube':
        return 'Click reconnect to sign in to your YouTube account and grant publishing permissions.';
      case 'tiktok':
        return 'Click reconnect to sign in to your TikTok account and grant publishing permissions.';
      case 'instagram':
        return 'Click reconnect to sign in to your Instagram account and grant publishing permissions.';
      case 'x':
        return 'Click reconnect to sign in to your X (Twitter) account and grant publishing permissions.';
      case 'facebook':
        return 'Click reconnect to sign in to your Facebook account and grant publishing permissions.';
      case 'linkedin':
        return 'Click reconnect to sign in to your LinkedIn account and grant publishing permissions.';
      default:
        return 'Click reconnect to sign in to your account and grant publishing permissions.';
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}
