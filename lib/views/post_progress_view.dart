import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/scheduled_post.dart';

class PostProgressView extends StatefulWidget {
  final ScheduledPost post;

  const PostProgressView({
    super.key,
    required this.post,
  });

  @override
  State<PostProgressView> createState() => _PostProgressViewState();
}

class _PostProgressViewState extends State<PostProgressView> with TickerProviderStateMixin {
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;
  
  bool _isLoading = true;
  Map<String, PlatformProgress> _platformProgress = {};
  String _overallStatus = 'Initializing...';
  double _overallProgress = 0.0;
  List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );
    _startProgressTracking();
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  Future<void> _startProgressTracking() async {
    // Simulate progress tracking
    await Future.delayed(const Duration(milliseconds: 500));
    
    setState(() {
      _isLoading = false;
      _overallStatus = 'Publishing to platforms...';
      _platformProgress = {
        'youtube': PlatformProgress(
          platform: 'YouTube',
          status: 'Uploading video...',
          progress: 0.3,
          isCompleted: false,
        ),
        'tiktok': PlatformProgress(
          platform: 'TikTok',
          status: 'Processing...',
          progress: 0.1,
          isCompleted: false,
        ),
        'instagram': PlatformProgress(
          platform: 'Instagram',
          status: 'Preparing content...',
          progress: 0.0,
          isCompleted: false,
        ),
      };
      _logs = [
        'Starting publication process...',
        'Uploading to YouTube (30% complete)',
        'Processing for TikTok...',
        'Preparing Instagram content...',
      ];
    });

    _progressController.forward();
    _simulateProgress();
  }

  void _simulateProgress() async {
    // Simulate YouTube progress
    for (int i = 30; i <= 100; i += 10) {
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() {
          _platformProgress['youtube'] = PlatformProgress(
            platform: 'YouTube',
            status: i == 100 ? 'Published successfully!' : 'Uploading video... ($i%)',
            progress: i / 100,
            isCompleted: i == 100,
          );
          _logs.add('YouTube: ${i}% complete');
        });
        _updateOverallProgress();
      }
    }

    // Simulate TikTok progress
    await Future.delayed(const Duration(seconds: 1));
    for (int i = 10; i <= 100; i += 15) {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() {
          _platformProgress['tiktok'] = PlatformProgress(
            platform: 'TikTok',
            status: i == 100 ? 'Published successfully!' : 'Processing... ($i%)',
            progress: i / 100,
            isCompleted: i == 100,
          );
          _logs.add('TikTok: ${i}% complete');
        });
        _updateOverallProgress();
      }
    }

    // Simulate Instagram progress
    await Future.delayed(const Duration(seconds: 1));
    for (int i = 0; i <= 100; i += 20) {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() {
          _platformProgress['instagram'] = PlatformProgress(
            platform: 'Instagram',
            status: i == 100 ? 'Published successfully!' : 'Preparing content... ($i%)',
            progress: i / 100,
            isCompleted: i == 100,
          );
          _logs.add('Instagram: ${i}% complete');
        });
        _updateOverallProgress();
      }
    }

    // All completed
    if (mounted) {
      setState(() {
        _overallStatus = 'All platforms published successfully!';
        _logs.add('Publication completed successfully!');
      });
    }
  }

  void _updateOverallProgress() {
    final totalProgress = _platformProgress.values
        .map((p) => p.progress)
        .reduce((a, b) => a + b) / _platformProgress.length;
    
    setState(() {
      _overallProgress = totalProgress;
      if (totalProgress == 1.0) {
        _overallStatus = 'All platforms published successfully!';
      } else {
        _overallStatus = 'Publishing to platforms...';
      }
    });
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
          'Publishing Progress',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _refreshProgress,
          ),
        ],
      ),
          body: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9248D2)),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildOverallProgress(),
                      const SizedBox(height: 24),
                      _buildPlatformProgress(),
                      const SizedBox(height: 24),
                      _buildLogsSection(),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildOverallProgress() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getOverallStatusIcon(),
                color: _getOverallStatusColor(),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _overallStatus,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, child) {
              return LinearProgressIndicator(
                value: _overallProgress * _progressAnimation.value,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(_getOverallStatusColor()),
                minHeight: 8,
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            '${(_overallProgress * 100).toInt()}% Complete',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformProgress() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Platform Status',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        ..._platformProgress.values.map((progress) => _buildPlatformCard(progress)),
      ],
    );
  }

  Widget _buildPlatformCard(PlatformProgress progress) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: progress.isCompleted 
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
                _getPlatformIcon(progress.platform),
                color: progress.isCompleted ? Colors.green : const Color(0xFF9248D2),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  progress.platform,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (progress.isCompleted)
                const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 20,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            progress.status,
            style: TextStyle(
              color: progress.isCompleted ? Colors.green : Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress.progress,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(
              progress.isCompleted ? Colors.green : const Color(0xFF9248D2),
            ),
            minHeight: 4,
          ),
        ],
      ),
    );
  }

  Widget _buildLogsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Activity Log',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 200,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: ListView.builder(
            itemCount: _logs.length,
            itemBuilder: (context, index) {
              final log = _logs[index];
              final isRecent = index >= _logs.length - 3;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 6,
                      color: isRecent ? const Color(0xFF9248D2) : Colors.white30,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        log,
                        style: TextStyle(
                          color: isRecent ? Colors.white : Colors.white70,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  IconData _getOverallStatusIcon() {
    if (_overallProgress == 1.0) {
      return Icons.check_circle;
    } else if (_overallProgress > 0) {
      return Icons.hourglass_empty;
    } else {
      return Icons.schedule;
    }
  }

  Color _getOverallStatusColor() {
    if (_overallProgress == 1.0) {
      return Colors.green;
    } else if (_overallProgress > 0) {
      return const Color(0xFF9248D2);
    } else {
      return Colors.orange;
    }
  }

  IconData _getPlatformIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'youtube':
        return Icons.play_circle_filled;
      case 'tiktok':
        return Icons.music_note;
      case 'instagram':
        return Icons.camera_alt;
      case 'x':
      case 'twitter':
        return Icons.alternate_email;
      case 'facebook':
        return Icons.facebook;
      case 'linkedin':
        return Icons.business;
      default:
        return Icons.public;
    }
  }

  void _refreshProgress() {
    HapticFeedback.lightImpact();
    _startProgressTracking();
  }
}

class PlatformProgress {
  final String platform;
  final String status;
  final double progress;
  final bool isCompleted;

  PlatformProgress({
    required this.platform,
    required this.status,
    required this.progress,
    required this.isCompleted,
  });
}
