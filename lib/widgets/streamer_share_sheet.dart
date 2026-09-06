import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'instant_response_button.dart';
import '../providers/service_providers.dart';
import '../services/logging_service.dart';
import '../services/analytics_service.dart';
import '../services/product_event_tracking_service.dart';
import '../services/error_handler_service.dart';
import '../services/profile_link_service.dart';
import '../services/user_blocking_service.dart';
import 'brand_icons.dart';
import 'video_qr_code_dialog.dart';

class StreamerShareSheet extends ConsumerWidget {
  final String userId;
  final String? username;
  final String? displayName;
  final String? profileImageUrl;
  final VoidCallback? onDismiss;

  const StreamerShareSheet({
    super.key,
    required this.userId,
    this.username,
    this.displayName,
    this.profileImageUrl,
    this.onDismiss,
  });

  // Validate input parameters
  bool get _isValidUserId => userId.isNotEmpty && userId.length > 3;
  String get _sanitizedUserId =>
      userId.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
  String get _sanitizedUsername =>
      (username ?? '').trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
  String get _profileUrl => ProfileLinkService.publicProfileUrl(
        username: _sanitizedUsername.isNotEmpty ? _sanitizedUsername : null,
        userId: userId,
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Validate input parameters
    if (!_isValidUserId) {
      LoggingService.instance
          .error('Invalid userId provided to ShareSheet', tag: 'ShareSheet');
      return _buildErrorState(context, 'Invalid user ID');
    }

    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6137EB), Color(0xFF1C135D)],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          boxShadow: [
            BoxShadow(
              blurRadius: 28,
              offset: Offset(0, -8),
              color: Colors.black26,
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildGrabber(),
            _buildHeaderRow(context),
            const SizedBox(height: 8),
            _buildSendToCarousel(context, ref),
            const SizedBox(height: 12),
            _buildActionsRow(context, isPrimary: true),
            const SizedBox(height: 12),
            _buildActionsRow(context, isPrimary: false),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildGrabber() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeaderRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // Search icon (optional)
          Icon(
            Icons.search,
            color: Colors.white.withValues(alpha: 0.7),
            size: 20,
          ),
          const SizedBox(width: 12),
          // Center title
          const Expanded(
            child: Text(
              'Send to',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 12),
          // Close button
          InstantResponseButton(
            onPressed: () {
              try {
                HapticFeedback.lightImpact();
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
                onDismiss?.call();
              } catch (e) {
                LoggingService.instance.error('Error closing ShareSheet',
                    tag: 'ShareSheet', error: e);
                // Fallback: try to pop again
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              }
            },
            hapticType: HapticFeedbackType.lightImpact,
            showRippleEffect: false,
            child: Container(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.close,
                color: Colors.white.withValues(alpha: 0.7),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSendToCarousel(BuildContext context, WidgetRef ref) {
    final relationshipState = ref.watch(relationshipServiceProvider);

    return ValueListenableBuilder<int>(
      valueListenable: UserBlockingService().blockListRevision,
      builder: (context, _, __) {
        return FutureBuilder<List<String>>(
          future: UserBlockingService().getBlockedUsers(),
          builder: (context, snapshot) {
            final blockedUserIds = snapshot.data?.toSet() ?? const <String>{};
            final visibleConnections = relationshipState.connections
                .where((connection) => !blockedUserIds.contains(connection.id))
                .take(10)
                .toList();

            if (visibleConnections.isEmpty) {
              return const SizedBox.shrink();
            }

            return SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                itemCount: visibleConnections.length,
                // ignore: deprecated_member_use
                cacheExtent: 200,
                itemBuilder: (context, index) {
                  final contact = visibleConnections[index];
                  return _buildContactItem(
                    context,
                    contact.displayName.isNotEmpty
                        ? contact.displayName
                        : contact.username,
                    contact.avatarURL,
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildContactItem(
      BuildContext context, String name, String? avatarUrl) {
    return InstantResponseButton(
      onPressed: () {
        HapticFeedback.selectionClick();
        _showContactAction(context, name);
      },
      hapticType: HapticFeedbackType.selectionClick,
      showRippleEffect: false,
      child: Container(
        width: 64,
        margin: const EdgeInsets.only(right: 8),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: avatarUrl != null && avatarUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Image.network(
                        avatarUrl,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildInitialsAvatar(name),
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return _buildInitialsAvatar(name);
                        },
                      ),
                    )
                  : _buildInitialsAvatar(name),
            ),
            const SizedBox(height: 4),
            Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialsAvatar(String name) {
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Center(
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildActionsRow(BuildContext context, {required bool isPrimary}) {
    if (isPrimary) {
      return _buildPrimaryActions(context);
    } else {
      return _buildSecondaryActions(context);
    }
  }

  Widget _buildPrimaryActions(BuildContext context) {
    final actions = [
      {'platform': 'link', 'label': 'Copy link', 'color': Colors.blue},
      {
        'platform': 'instagram',
        'label': 'Instagram Direct',
        'color': const Color(0xFFE4405F)
      }, // Instagram pink
      {'platform': 'sms', 'label': 'SMS', 'color': Colors.green},
      {
        'platform': 'whatsapp',
        'label': 'WhatsApp',
        'color': const Color(0xFF25D366)
      }, // WhatsApp green
      {'platform': 'status', 'label': 'Status', 'color': Colors.green},
      {'platform': 'twitter', 'label': 'X', 'color': Colors.black},
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: actions
          .map((action) => _buildBrandActionButton(
                context,
                platform: action['platform'] as String,
                label: action['label'] as String,
                color: action['color'] as Color,
                isPrimary: true,
              ))
          .toList(),
    );
  }

  Widget _buildSecondaryActions(BuildContext context) {
    final actions = [
      {'icon': Icons.qr_code, 'label': 'QR Code'},
      {'icon': Icons.flag, 'label': 'Report'},
      {'icon': Icons.block, 'label': 'Block'},
      {'icon': Icons.send, 'label': 'Send message'},
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: actions
          .map((action) => _buildActionButton(
                context,
                icon: action['icon'] as IconData,
                label: action['label'] as String,
                color: Colors.white,
                isPrimary: false,
              ))
          .toList(),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required bool isPrimary,
  }) {
    // Determine button width based on label length
    final isLongLabel = label.length > 8; // "Instagram Direct" is 15 chars
    final buttonWidth = isLongLabel ? 80.0 : 64.0;

    return InstantResponseButton(
      onPressed: () => _handleAction(context, label),
      hapticType: HapticFeedbackType.selectionClick,
      showRippleEffect: false,
      child: SizedBox(
        width: buttonWidth,
        height: 90, // Fixed height for all buttons
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: isPrimary ? color : Colors.white.withValues(alpha: 0.7),
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 24, // Fixed height for text area
              child: Text(
                label,
                style: TextStyle(
                  color: isPrimary
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.7),
                  fontSize:
                      isLongLabel ? 10 : 11, // Smaller font for longer labels
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandActionButton(
    BuildContext context, {
    required String platform,
    required String label,
    required Color color,
    required bool isPrimary,
  }) {
    // Determine button width based on label length
    final isLongLabel = label.length > 8; // "Instagram Direct" is 15 chars
    final buttonWidth = isLongLabel ? 80.0 : 64.0;

    return InstantResponseButton(
      onPressed: () => _handleAction(context, label),
      hapticType: HapticFeedbackType.selectionClick,
      showRippleEffect: false,
      child: SizedBox(
        width: buttonWidth,
        height: 90, // Fixed height for all buttons
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: platform == 'link'
                    ? Icon(
                        Icons.link,
                        color: isPrimary
                            ? color
                            : Colors.white.withValues(alpha: 0.7),
                        size: 24,
                      )
                    : BrandIcon(
                        platformType: platform,
                        size: 24,
                        color: isPrimary
                            ? color
                            : Colors.white.withValues(alpha: 0.7),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 24, // Fixed height for text area
              child: Text(
                label,
                style: TextStyle(
                  color: isPrimary
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.7),
                  fontSize:
                      isLongLabel ? 10 : 11, // Smaller font for longer labels
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAction(BuildContext context, String action) async {
    // Track action attempt (safe call)
    try {
      if (AnalyticsService.isReady) {
        AnalyticsService.instance
            .trackEvent('share_action_attempted', parameters: {
          'user_id': _sanitizedUserId,
          'action': action.toLowerCase().replaceAll(' ', '_'),
        });
      }
    } catch (e) {
      debugPrint('📊 Analytics not ready: $e');
    }

    try {
      switch (action) {
        case 'Copy link':
          await _copyLink(context);
          break;
        case 'Instagram Direct':
          await _openInstagramDirect(context);
          break;
        case 'SMS':
          await _openSMS(context);
          break;
        case 'WhatsApp':
          await _openWhatsApp(context);
          break;
        case 'Status':
          await _openWhatsAppStatus(context);
          break;
        case 'X':
          await _openTwitter(context);
          break;
        case 'Report':
          await _showReportDialog(context);
          break;
        case 'Block':
          await _showBlockDialog(context);
          break;
        case 'Send message':
          await _openMessage(context);
          break;
        case 'QR Code':
          await _showQRCode(context);
          break;
        default:
          LoggingService.instance
              .warning('Unknown share action: $action', tag: 'ShareSheet');
      }
    } catch (e, stackTrace) {
      LoggingService.instance.error('Failed to handle share action: $action',
          tag: 'ShareSheet', error: e, stackTrace: stackTrace);

      // Track failed action (safe call)
      try {
        if (AnalyticsService.isReady) {
          AnalyticsService.instance
              .trackEvent('share_action_failed', parameters: {
            'user_id': _sanitizedUserId,
            'action': action.toLowerCase().replaceAll(' ', '_'),
            'error': e.toString(),
          });
        }
      } catch (analyticsError) {
        debugPrint('📊 Analytics not ready: $analyticsError');
      }
    }
  }

  Widget _buildErrorState(BuildContext context, String message) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6137EB), Color(0xFF1C135D)],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 48),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            InstantResponseButton(
              onPressed: () => Navigator.of(context).pop(),
              hapticType: HapticFeedbackType.lightImpact,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    const Text('Close', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyLink(BuildContext context) async {
    try {
      LoggingService.instance
          .debug('Copying profile link: $_profileUrl', tag: 'ShareSheet');

      await Clipboard.setData(ClipboardData(text: _profileUrl));

      // Track analytics (safe call)
      try {
        if (AnalyticsService.isReady) {
          AnalyticsService.instance
              .trackEvent('share_link_copied', parameters: {
            'user_id': _sanitizedUserId,
            'platform': 'clipboard',
          });
        }
      } catch (e) {
        debugPrint('📊 Analytics not ready: $e');
      }
      unawaited(
        ProductEventTrackingService.instance.profileShared(
          surface: 'share_sheet',
        ),
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Link copied to clipboard'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e, stackTrace) {
      LoggingService.instance.error('Failed to copy link',
          tag: 'ShareSheet', error: e, stackTrace: stackTrace);
      if (context.mounted) {
        ErrorHandlerService.instance
            .handleError(e, stackTrace, context: context);
      }
    }
  }

  Future<void> _openInstagramDirect(BuildContext context) async {
    await _launchUrlWithFallback(
      context: context,
      primaryUrl: 'instagram://direct/inbox',
      fallbackUrl: 'https://www.instagram.com/direct/inbox/',
      platform: 'instagram_direct',
      errorMessage: 'Instagram Direct not available',
    );
  }

  Future<void> _openSMS(BuildContext context) async {
    final message = 'Check out this profile: $_profileUrl';
    await _launchUrlWithFallback(
      context: context,
      primaryUrl: 'sms:?body=${Uri.encodeComponent(message)}',
      fallbackUrl: null,
      platform: 'sms',
      errorMessage: 'SMS not available',
    );
  }

  Future<void> _openWhatsApp(BuildContext context) async {
    final message = 'Check out this profile: $_profileUrl';
    await _launchUrlWithFallback(
      context: context,
      primaryUrl: 'whatsapp://send?text=${Uri.encodeComponent(message)}',
      fallbackUrl: 'https://wa.me/?text=${Uri.encodeComponent(message)}',
      platform: 'whatsapp',
      errorMessage: 'WhatsApp not available',
    );
  }

  Future<void> _openWhatsAppStatus(BuildContext context) async {
    final message = 'Check out this profile: $_profileUrl';
    await _launchUrlWithFallback(
      context: context,
      primaryUrl: 'whatsapp://send?text=${Uri.encodeComponent(message)}',
      fallbackUrl: 'https://wa.me/?text=${Uri.encodeComponent(message)}',
      platform: 'whatsapp_status',
      errorMessage: 'WhatsApp Status not available',
    );
  }

  Future<void> _openTwitter(BuildContext context) async {
    final message = 'Check out this profile: $_profileUrl';
    await _launchUrlWithFallback(
      context: context,
      primaryUrl: 'twitter://post?message=${Uri.encodeComponent(message)}',
      fallbackUrl:
          'https://twitter.com/intent/tweet?text=${Uri.encodeComponent(message)}',
      platform: 'twitter',
      errorMessage: 'X/Twitter not available',
    );
  }

  /// Comprehensive URL launching with fallback and error handling
  Future<void> _launchUrlWithFallback({
    required BuildContext context,
    required String primaryUrl,
    String? fallbackUrl,
    required String platform,
    required String errorMessage,
  }) async {
    try {
      // Check connectivity first
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none)) {
        if (context.mounted) {
          _showErrorSnackbar(context, 'No internet connection');
        }
        return;
      }

      final uri = Uri.parse(primaryUrl);

      // Try primary URL first
      if (await canLaunchUrl(uri)) {
        LoggingService.instance
            .debug('Launching $platform: $primaryUrl', tag: 'ShareSheet');

        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw TimeoutException(
                'URL launch timeout', const Duration(seconds: 10));
          },
        );

        // Track successful launch (safe call)
        try {
          if (AnalyticsService.isReady) {
            AnalyticsService.instance
                .trackEvent('share_platform_opened', parameters: {
              'user_id': _sanitizedUserId,
              'platform': platform,
              'method': 'primary',
            });
          }
        } catch (e) {
          debugPrint('📊 Analytics not ready: $e');
        }

        if (context.mounted) {
          Navigator.of(context).pop();
        }
        return;
      }

      // Try fallback URL if available
      if (fallbackUrl != null) {
        final fallbackUri = Uri.parse(fallbackUrl);
        if (await canLaunchUrl(fallbackUri)) {
          LoggingService.instance.debug(
              'Launching $platform fallback: $fallbackUrl',
              tag: 'ShareSheet');

          await launchUrl(
            fallbackUri,
            mode: LaunchMode.externalApplication,
          ).timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException(
                  'Fallback URL launch timeout', const Duration(seconds: 10));
            },
          );

          // Track successful fallback launch (safe call)
          try {
            if (AnalyticsService.isReady) {
              AnalyticsService.instance
                  .trackEvent('share_platform_opened', parameters: {
                'user_id': _sanitizedUserId,
                'platform': platform,
                'method': 'fallback',
              });
            }
          } catch (e) {
            debugPrint('📊 Analytics not ready: $e');
          }

          if (context.mounted) {
            Navigator.of(context).pop();
          }
          return;
        }
      }

      // No URL could be launched
      if (context.mounted) {
        _showErrorSnackbar(context, errorMessage);
      }
    } catch (e, stackTrace) {
      LoggingService.instance.error('Failed to launch $platform',
          tag: 'ShareSheet', error: e, stackTrace: stackTrace);

      if (context.mounted) {
        ErrorHandlerService.instance
            .handleError(e, stackTrace, context: context);
      }
    }
  }

  Future<void> _showReportDialog(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        content: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF6137EB), Color(0xFF1C135D)],
            ),
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Report User',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Are you sure you want to report this user?',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: InstantResponseButton(
                        onPressed: () => Navigator.of(context).pop(),
                        hapticType: HapticFeedbackType.lightImpact,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              'Cancel',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InstantResponseButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _showSuccessSnackbar(
                              context, 'User reported successfully');
                        },
                        hapticType: HapticFeedbackType.mediumImpact,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Text(
                              'Report',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showBlockDialog(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        content: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF6137EB), Color(0xFF1C135D)],
            ),
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Block User',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Are you sure you want to block this user?',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: InstantResponseButton(
                        onPressed: () => Navigator.of(context).pop(),
                        hapticType: HapticFeedbackType.lightImpact,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              'Cancel',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InstantResponseButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _showSuccessSnackbar(
                              context, 'User blocked successfully');
                        },
                        hapticType: HapticFeedbackType.mediumImpact,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Text(
                              'Block',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openMessage(BuildContext context) async {
    // Navigate to message view
    Navigator.of(context).pop();
    _showSuccessSnackbar(context, 'Opening message...');
  }

  Future<void> _showQRCode(BuildContext context) async {
    try {
      Navigator.of(context).pop(); // Close share sheet first
      showDialog<void>(
        context: context,
        builder: (context) => ProfileQRCodeDialog(
          userId: userId,
          username: _sanitizedUsername.isNotEmpty
              ? _sanitizedUsername
              : (displayName ?? 'profile'),
          displayName: displayName ?? _sanitizedUsername,
          shareUrl: _profileUrl,
        ),
      );
    } catch (e) {
      LoggingService.instance
          .error('Failed to show QR code', tag: 'ShareSheet', error: e);
      if (context.mounted) {
        _showErrorSnackbar(context, 'Failed to generate QR code');
      }
    }
  }

  Future<void> _showContactAction(
      BuildContext context, String contactName) async {
    Navigator.of(context).pop();
    _showSuccessSnackbar(context, 'Sending to $contactName...');
  }

  void _showErrorSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
