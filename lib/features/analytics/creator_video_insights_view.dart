import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/support_shell_style.dart';
import '../../models/profile_video.dart';
import '../../services/insights_firebase_service.dart';
import '../../models/insights_data.dart';
import 'modern_creator_insights_view.dart';

/// Entry screen for per-video creator insights dashboard.
class CreatorVideoInsightsView extends ConsumerStatefulWidget {
  const CreatorVideoInsightsView({super.key});

  @override
  ConsumerState<CreatorVideoInsightsView> createState() =>
      _CreatorVideoInsightsViewState();
}

class _CreatorVideoInsightsViewState
    extends ConsumerState<CreatorVideoInsightsView> {
  bool _isLoading = true;
  String? _errorMessage;
  ProfileVideo? _initialVideo;
  InsightsData? _insights;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialVideo();
    });
  }

  Future<void> _loadInitialVideo() async {
    try {
      final InsightsFirebaseService service =
          ref.read(insightsFirebaseServiceProvider);
      final List<ProfileVideo> videos = await service.getUserProfileVideos();
      if (!mounted) {
        return;
      }
      
      if (videos.isNotEmpty) {
        final video = videos.first;
        final snapshot = await service.getCreatorInsights(
          videoId: video.id,
          analyticsWindowDays: 7,
        );
        
        setState(() {
          _initialVideo = video;
          _insights = snapshot?.insights;
          _isLoading = false;
          _errorMessage = null;
        });
      } else {
        setState(() {
          _initialVideo = null;
          _insights = null;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not load your videos.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0A0F),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    if (_initialVideo != null && _insights != null) {
      return ModernCreatorInsightsView(
        video: _initialVideo!,
        insights: _insights!,
      );
    }
    
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Scaffold(
      backgroundColor: shell.scaffold,
      appBar: AppBar(
        backgroundColor: shell.scaffold,
        foregroundColor: shell.onChrome,
        title: const Text('Creator Insights'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(Icons.insights_outlined, size: 56, color: shell.muted),
              const SizedBox(height: 16),
              Text(
                _errorMessage ??
                    'Upload your first video to unlock creator insights.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color:
                      _errorMessage != null ? Colors.redAccent : shell.muted,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_errorMessage != null) ...<Widget>[
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _errorMessage = null;
                    });
                    _loadInitialVideo();
                  },
                  child: const Text('Try again'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
