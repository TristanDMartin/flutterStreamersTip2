import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/feature_flags.dart';
import '../core/theme/support_shell_style.dart';
import '../models/scheduled_post.dart';
import '../services/creator_intelligence_analytics_service.dart';
import '../services/linked_platform_service.dart';
import '../services/retention_tracking_service.dart';

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
  final LinkedPlatformService _linkedPlatformService = LinkedPlatformService();
  Map<String, bool> _connections = const {};
  bool _isLoading = true;
  String? _reconnectingPlatform;
  bool _didUpdateConnections = false;

  bool get _isComingSoon => !FeatureFlags.linkedPlatforms;

  @override
  void initState() {
    super.initState();
    if (_isComingSoon) {
      _isLoading = false;
      return;
    }
    _loadConnections();
  }

  Future<void> _loadConnections() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final Map<String, bool> connections =
          await _linkedPlatformService.getPlatformConnections();
      if (!mounted) {
        return;
      }
      setState(() {
        _connections = connections;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load linked platforms: $e'),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
        ),
      );
    }
  }

  Future<void> _reconnectPlatform(PlatformKey platform) async {
    setState(() {
      _reconnectingPlatform = platform.name;
    });
    try {
      await _linkedPlatformService.reconnectPlatform(platform);
      final bool hadAnyConnection =
          _connections.values.any((bool connected) => connected);
      unawaited(
        CreatorIntelligenceAnalyticsService().trackPlatformConnected(
          platform: platform.name,
        ),
      );
      final String? uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        unawaited(
          RetentionTrackingService.instance.trackPlatformConnected(
            uid: uid,
            platform: platform.name,
            isFirstPlatform: !hadAnyConnection,
          ),
        );
      }
      _didUpdateConnections = true;
      await _loadConnections();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_displayName(platform.name)} reconnect started'),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is LinkedPlatformReconnectUnavailableException
                ? e.message
                : 'Failed to reconnect ${_displayName(platform.name)}: $e',
          ),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
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

  void _requestPop() {
    if (!mounted) {
      return;
    }
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop || !mounted) {
          return;
        }
        Navigator.of(context).pop(_didUpdateConnections);
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: shell.pageGradient,
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: shell.onChrome),
              onPressed: _requestPop,
            ),
            title: Text(
              'Linked Platforms',
              style: TextStyle(
                color: shell.onChrome,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          body: _isComingSoon
              ? _buildComingSoonBody(context, shell, scheme)
              : _buildConnectionsBody(context, shell, scheme),
        ),
      ),
    );
  }

  Widget _buildComingSoonBody(
    BuildContext context,
    StSupportShellStyle shell,
    ColorScheme scheme,
  ) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scheme.primary.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.schedule_rounded, color: scheme.primary, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'Coming soon',
                    style: TextStyle(
                      color: shell.onChrome,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Linked Platforms will let you connect YouTube, TikTok, '
                'Instagram, and more so you can cross-post and retry failed '
                'publishes from Manage Posts.',
                style: TextStyle(
                  color: shell.muted,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'What you can do today',
          style: TextStyle(
            color: shell.onChrome,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        _buildComingSoonTip(
          shell,
          scheme,
          icon: Icons.person_outline_rounded,
          title: 'Add profile links',
          body:
              'Open Edit Profile → Platforms to show where you stream and post.',
        ),
        const SizedBox(height: 10),
        _buildComingSoonTip(
          shell,
          scheme,
          icon: Icons.calendar_month_outlined,
          title: 'Schedule in StreamersTip',
          body:
              'Use Manage Posts to draft and schedule clips inside the app today.',
        ),
        const SizedBox(height: 10),
        _buildComingSoonTip(
          shell,
          scheme,
          icon: Icons.notifications_active_outlined,
          title: 'Get notified at launch',
          body:
              'We will enable OAuth reconnect here when cross-posting is ready '
              '— no account action needed until then.',
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _requestPop,
            style: FilledButton.styleFrom(
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Got it'),
          ),
        ),
      ],
    );
  }

  Widget _buildComingSoonTip(
    StSupportShellStyle shell,
    ColorScheme scheme, {
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: shell.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: shell.surfaceCardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: shell.chipUnselectedBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: shell.chipUnselectedBorder),
            ),
            child: Icon(icon, color: scheme.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(
                    color: shell.onChrome,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                    color: shell.muted,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionsBody(
    BuildContext context,
    StSupportShellStyle shell,
    ColorScheme scheme,
  ) {
    final Set<String> highlightedPlatforms = widget.initialPlatforms
        .map((String platform) => platform.toLowerCase())
        .toSet();
    return RefreshIndicator(
      color: shell.refreshColor,
      backgroundColor: shell.refreshBackground,
      onRefresh: _loadConnections,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          if (highlightedPlatforms.isNotEmpty) ...<Widget>[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: shell.surfaceCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.35),
                ),
              ),
              child: Text(
                'Reconnect ${highlightedPlatforms.map(_displayName).join(', ')} '
                'to retry publishing from Manage Posts.',
                style: TextStyle(color: shell.onChrome, fontSize: 14),
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
            'Keep your connected destinations healthy here so cross-post '
            'retries can succeed later.',
            style: TextStyle(color: shell.muted, fontSize: 14),
          ),
          const SizedBox(height: 20),
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: CircularProgressIndicator(color: scheme.primary),
              ),
            )
          else
            ...PlatformKey.values.map(
              (PlatformKey platform) => Padding(
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
              onPressed: _requestPop,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: shell.surfaceCardBorder),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text('Done', style: TextStyle(color: shell.onChrome)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformCard(PlatformKey platform, bool highlighted) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isConnected = _connections[platform.name] ?? false;
    final bool isReconnecting = _reconnectingPlatform == platform.name;
    final bool supportsOAuth =
        LinkedPlatformService.supportsOAuthReconnect(platform);
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
        children: <Widget>[
          CircleAvatar(
            backgroundColor: isConnected
                ? scheme.primaryContainer.withValues(alpha: 0.55)
                : scheme.tertiaryContainer.withValues(alpha: 0.45),
            child: Icon(
              isConnected ? Icons.link : Icons.link_off,
              color: isConnected ? scheme.primary : scheme.tertiary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
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
                      ? supportsOAuth
                          ? 'Connected and ready for cross-posting.'
                          : 'Profile link saved. Cross-post OAuth is not available yet.'
                      : supportsOAuth
                          ? 'Reconnect this destination before retrying failed posts.'
                          : 'Add this platform under Edit Profile → Platforms, or wait for OAuth support.',
                  style: TextStyle(color: shell.muted, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: isReconnecting || !supportsOAuth
                ? null
                : () => _reconnectPlatform(platform),
            style: FilledButton.styleFrom(
              backgroundColor:
                  isConnected ? shell.panelSurface : scheme.primary,
              foregroundColor: isConnected ? shell.onChrome : scheme.onPrimary,
            ),
            child: Text(
              isReconnecting
                  ? 'Working...'
                  : !supportsOAuth
                      ? 'OAuth soon'
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
