import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'instant_response_button.dart';
import '../providers/service_providers.dart';
import '../services/unified_avatar_service.dart';

class StreamerShareSheet extends ConsumerWidget {
  final String userId;
  final String? displayName;
  final String? profileImageUrl;
  final VoidCallback? onDismiss;

  const StreamerShareSheet({
    super.key,
    required this.userId,
    this.displayName,
    this.profileImageUrl,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              HapticFeedback.lightImpact();
              Navigator.of(context).pop();
              onDismiss?.call();
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
    final relationshipService = ref.watch(relationshipServiceProvider);
    final connections = relationshipService.connections;

    // If no connections, don't show the carousel
    if (connections.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: connections.length,
        itemBuilder: (context, index) {
          final contact = connections[index];
          return _buildContactItem(
            context, 
            contact.displayName.isNotEmpty ? contact.displayName : contact.username,
            contact.avatarURL,
          );
        },
      ),
    );
  }

  Widget _buildContactItem(BuildContext context, String name, String? avatarUrl) {
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
        child: avatarUrl != null
            ? UnifiedAvatarService().getAvatar(
                imageUrl: avatarUrl,
                radius: 28,
                errorWidget: _buildInitialsAvatar(name),
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
      {'icon': Icons.link, 'label': 'Copy link', 'color': Colors.blue},
      {'icon': Icons.camera_alt, 'label': 'Instagram Direct', 'color': const Color(0xFFE4405F)}, // Instagram pink
      {'icon': Icons.sms, 'label': 'SMS', 'color': Colors.green},
      {'icon': Icons.chat, 'label': 'WhatsApp', 'color': const Color(0xFF25D366)}, // WhatsApp green
      {'icon': Icons.auto_awesome, 'label': 'Status', 'color': Colors.green},
      {'icon': Icons.close, 'label': 'X', 'color': Colors.black},
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: actions.map((action) => _buildActionButton(
        context,
        icon: action['icon'] as IconData,
        label: action['label'] as String,
        color: action['color'] as Color,
        isPrimary: true,
      )).toList(),
    );
  }

  Widget _buildSecondaryActions(BuildContext context) {
    final actions = [
      {'icon': Icons.flag, 'label': 'Report'},
      {'icon': Icons.block, 'label': 'Block'},
      {'icon': Icons.send, 'label': 'Send message'},
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: actions.map((action) => _buildActionButton(
        context,
        icon: action['icon'] as IconData,
        label: action['label'] as String,
        color: Colors.white,
        isPrimary: false,
      )).toList(),
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
      child: Container(
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
                  fontSize: isLongLabel ? 10 : 11, // Smaller font for longer labels
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
    }
  }

  Future<void> _copyLink(BuildContext context) async {
    try {
      final link = 'https://streamerstip.app/profile/$userId';
      await Clipboard.setData(ClipboardData(text: link));
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Link copied to clipboard'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to copy link: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _openInstagramDirect(BuildContext context) async {
    try {
      final url = 'https://www.instagram.com/direct/inbox/';
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      }
    } catch (e) {
      _showErrorSnackbar(context, 'Failed to open Instagram Direct');
    }
  }

  Future<void> _openSMS(BuildContext context) async {
    try {
      final url = 'sms:?body=Check out this profile: https://streamerstip.app/profile/$userId';
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      }
    } catch (e) {
      _showErrorSnackbar(context, 'Failed to open SMS');
    }
  }

  Future<void> _openWhatsApp(BuildContext context) async {
    try {
      final url = 'https://wa.me/?text=Check out this profile: https://streamerstip.app/profile/$userId';
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      }
    } catch (e) {
      _showErrorSnackbar(context, 'Failed to open WhatsApp');
    }
  }

  Future<void> _openWhatsAppStatus(BuildContext context) async {
    try {
      final url = 'https://wa.me/?text=Check out this profile: https://streamerstip.app/profile/$userId';
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      }
    } catch (e) {
      _showErrorSnackbar(context, 'Failed to open WhatsApp Status');
    }
  }

  Future<void> _openTwitter(BuildContext context) async {
    try {
      final url = 'https://twitter.com/intent/tweet?text=Check out this profile: https://streamerstip.app/profile/$userId';
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      }
    } catch (e) {
      _showErrorSnackbar(context, 'Failed to open X/Twitter');
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
                          _showSuccessSnackbar(context, 'User reported successfully');
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
                          _showSuccessSnackbar(context, 'User blocked successfully');
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


  Future<void> _showContactAction(BuildContext context, String contactName) async {
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
