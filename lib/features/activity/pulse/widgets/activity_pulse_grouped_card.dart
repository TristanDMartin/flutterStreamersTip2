import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/support_shell_style.dart';
import '../../../../models/activity_notification.dart';
import '../activity_pulse_tokens.dart';

class ActivityPulseGroupedCard extends StatefulWidget {
  const ActivityPulseGroupedCard({
    super.key,
    required this.notifications,
    required this.onTap,
  });

  final List<ActivityNotification> notifications;
  final VoidCallback onTap;

  @override
  State<ActivityPulseGroupedCard> createState() =>
      _ActivityPulseGroupedCardState();
}

class _ActivityPulseGroupedCardState extends State<ActivityPulseGroupedCard> {
  double _scale = 1;

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final ActivityNotification first = widget.notifications.first;
    final int count = widget.notifications.length;
    final String names = widget.notifications
        .take(3)
        .map((ActivityNotification n) => n.user.displayName)
        .join(', ');
    final String suffix = count > 3 ? ' +${count - 3} more' : '';
    final Color glow = ActivityPulseTokens.likeGlow;
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.98),
      onTapUp: (_) => setState(() => _scale = 1),
      onTapCancel: () => setState(() => _scale = 1),
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: shell.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: glow.withValues(alpha: 0.28),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: glow.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              _AvatarStack(notifications: widget.notifications),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '$count creators liked your clip',
                      style: TextStyle(
                        color: shell.onChrome,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$names$suffix',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: shell.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (first.postThumbnailUrl?.isNotEmpty == true)
                _Thumb(url: first.postThumbnailUrl!),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.notifications});

  final List<ActivityNotification> notifications;

  @override
  Widget build(BuildContext context) {
    final int show = notifications.length.clamp(1, 3);
    return SizedBox(
      width: 36 + (show - 1) * 14.0,
      height: 40,
      child: Stack(
        children: List<Widget>.generate(show, (int i) {
          final String? url = notifications[i].user.avatarURL;
          return Positioned(
            left: i * 14.0,
            child: CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF1E293B),
              backgroundImage:
                  url != null && url.isNotEmpty ? NetworkImage(url) : null,
              child: url == null || url.isEmpty
                  ? const Icon(Icons.person, size: 18, color: Colors.white54)
                  : null,
            ),
          );
        }),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: CachedNetworkImage(
        imageUrl: url,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
      ),
    );
  }
}
