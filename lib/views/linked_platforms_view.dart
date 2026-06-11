import 'dart:async';

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../core/theme/support_shell_style.dart';
import '../models/scheduled_post.dart';
import '../services/creator_intelligence_analytics_service.dart';
import '../services/scheduled_post_service.dart';

class LinkedPlatformsView extends StatefulWidget {
  const LinkedPlatformsView({
    super.key,
    this.initialPlatforms = const [],
  });

  final List<String> initialPlatforms;

  @override
  State<LinkedPlatformsView> createState() => _LinkedPlatformsViewState();
}

class _LinkedPlatformsViewState extends State<LinkedPlatformsView> {
  final ScheduledPostService _scheduledPostService = ScheduledPostService();
  Map<String, bool> _connections = const {};
  bool _isLoading = true;
  String? _reconnectingPlatform;
  bool _didUpdateConnections = false;

  @override
  void initState() {
    super.initState();
    _loadConnections();
  }

  Future<void> _loadConnections() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final connections = await _scheduledPostService.getPlatformConnections();
      if (!mounted) return;
      setState(() {
        _connections = connections;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load linked platforms: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _reconnectPlatform(PlatformKey platform) async {
    setState(() {
      _reconnectingPlatform = platform.name;
    });

    try {
      await _scheduledPostService.reconnectPlatform(platform);
      unawaited(
        CreatorIntelligenceAnalyticsService().trackPlatformConnected(
          platform: platform.name,
        ),
      );
      _didUpdateConnections = true;
      await _loadConnections();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_displayName(platform.name)} reconnect started'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Failed to reconnect ${_displayName(platform.name)}: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _reconnectingPlatform = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final highlightedPlatforms = widget.initialPlatforms
        .map((platform) => platform.toLowerCase())
        .toSet();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, __) {
        Navigator.of(context).pop(_didUpdateConnections);
      },
      child: Scaffold(
        backgroundColor: shell.scaffold,
        appBar: AppBar(
          backgroundColor: shell.panelSurface,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: shell.onChrome),
            onPressed: () => Navigator.of(context).pop(_didUpdateConnections),
          ),
          title: Text(
            'Linked Platforms',
            style: TextStyle(color: shell.onChrome),
          ),
        ),
        body: RefreshIndicator(
          color: shell.refreshColor,
          backgroundColor: shell.refreshBackground,
          onRefresh: _loadConnections,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (highlightedPlatforms.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: shell.surfaceCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: scheme.primary.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    'Reconnect ${highlightedPlatforms.map(_displayName).join(', ')} to retry publishing from Manage Posts.',
                    style: TextStyle(
                      color: shell.onChrome,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              Text(
                'Connection Status',
                style: TextStyle(
                  color: shell.onChrome,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Keep your connected destinations healthy here so cross-post retries can succeed later.',
                style: TextStyle(
                  color: shell.muted,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                ...PlatformKey.values.map(
                  (platform) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildPlatformCard(
                      platform,
                      highlightedPlatforms.contains(platform.name),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () =>
                      Navigator.of(context).pop(_didUpdateConnections),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: shell.surfaceCardBorder,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    'Done',
                    style: TextStyle(color: shell.onChrome),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlatformCard(PlatformKey platform, bool highlighted) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final isConnected = _connections[platform.name] ?? false;
    final isReconnecting = _reconnectingPlatform == platform.name;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlighted
            ? scheme.primary.withValues(alpha: shell.isLight ? 0.12 : 0.22)
            : shell.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlighted
              ? scheme.primary.withValues(alpha: 0.55)
              : shell.surfaceCardBorder,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: isConnected
                ? Colors.greenAccent.withValues(alpha: 0.18)
                : Colors.orangeAccent.withValues(alpha: 0.18),
            child: Icon(
              isConnected ? Icons.link : Icons.link_off,
              color: isConnected ? Colors.greenAccent : Colors.orangeAccent,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _displayName(platform.name),
                  style: TextStyle(
                    color: shell.onChrome,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isConnected
                      ? 'Connected and ready for cross-posting.'
                      : 'Reconnect this destination before retrying failed posts.',
                  style: TextStyle(
                    color: shell.muted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed:
                isReconnecting ? null : () => _reconnectPlatform(platform),
            style: ElevatedButton.styleFrom(
              backgroundColor: isConnected
                  ? const Color(0xFF2B3548)
                  : AppColors.supportAccent,
              foregroundColor: Colors.white,
            ),
            child: Text(
              isReconnecting
                  ? 'Working...'
                  : isConnected
                      ? 'Refresh'
                      : 'Reconnect',
            ),
          ),
        ],
      ),
    );
  }

  String _displayName(String key) {
    switch (key.toLowerCase()) {
      case 'youtube':
        return 'YouTube';
      case 'tiktok':
        return 'TikTok';
      case 'instagram':
        return 'Instagram';
      case 'x':
        return 'X';
      case 'facebook':
        return 'Facebook';
      case 'linkedin':
        return 'LinkedIn';
      default:
        return key.isEmpty
            ? 'Platform'
            : '${key[0].toUpperCase()}${key.substring(1)}';
    }
  }
}
