import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_colors.dart';
import '../core/theme/support_shell_style.dart';
import '../features/activity/pulse/activity_pulse_logic.dart';
import '../features/activity/pulse/activity_pulse_tokens.dart';
import '../features/activity/activity_notification_rules.dart';
import '../models/activity_notification.dart';
import '../models/user.dart';
import '../services/robust_auth_service.dart';
import '../services/follows_service.dart';
import '../providers/follow_refresh_provider.dart';

class ActivityRowView extends ConsumerStatefulWidget {
  final ActivityNotification notification;
  final ValueChanged<User> onProfileTap;
  final ValueChanged<ActivityNotification> onPostTap;
  final ValueChanged<ActivityNotification>? onCardTap;

  const ActivityRowView({
    super.key,
    required this.notification,
    required this.onProfileTap,
    required this.onPostTap,
    this.onCardTap,
  });

  @override
  ConsumerState<ActivityRowView> createState() => _ActivityRowViewState();
}

class _ActivityRowViewState extends ConsumerState<ActivityRowView>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _fadeController;
  bool _isPressed = false;

  // Follow status state
  bool _isFollowing = false;
  bool _isFollowedBy = false;
  bool _isLoadingFollowStatus = true;

  final FollowsService _followsService = FollowsService();

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeController.forward();
    _loadFollowStatus();
  }

  Future<void> _loadFollowStatus() async {
    final auth = ref.read(robustAuthServiceProvider);
    final currentUserId = auth.currentUser?.id;

    if (currentUserId == null || widget.notification.user.id == currentUserId) {
      setState(() {
        _isLoadingFollowStatus = false;
      });
      return;
    }

    try {
      // Load all follow status in parallel for efficiency
      final results = await Future.wait([
        _followsService.isFollowing(widget.notification.user.id),
        _followsService.isFollowedBy(widget.notification.user.id),
      ]);

      if (mounted) {
        setState(() {
          _isFollowing = results[0];
          _isFollowedBy = results[1];
          _isLoadingFollowStatus = false;
        });

        debugPrint(
            '✅ ActivityRowView: Follow status loaded - following: ${results[0]}, followedBy: ${results[1]}');
      }
    } catch (e) {
      debugPrint('❌ ActivityRowView: Error loading follow status: $e');
      if (mounted) {
        setState(() {
          _isLoadingFollowStatus = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  bool get _canOpenActorProfile {
    final id = widget.notification.user.id.toLowerCase().trim();
    final username = widget.notification.user.username.toLowerCase().trim();
    return id.isNotEmpty &&
        !id.contains('system') &&
        username != 'streamerstip' &&
        username != 'system';
  }

  void _handleActorTap() {
    HapticFeedback.lightImpact();
    if (_canOpenActorProfile) {
      widget.onProfileTap(widget.notification.user);
    } else {
      widget.onCardTap?.call(widget.notification);
    }
  }

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    // Get actual user management from Riverpod
    final auth = ref.watch(robustAuthServiceProvider);
    final currentUserId = auth.currentUser?.id;

    // Calculate follow status
    final isFollowing = _isFollowing;
    final isMutualFollow = _isFollowing && _isFollowedBy;

    final ActivityNotification n = widget.notification;
    final bool highPriority = n.isHighPriority;
    final bool isActionItem = n.isContentPlanType ||
        n.pulseAccent == ActivityPulseAccent.action;
    final Color accent = ActivityPulseTokens.accentColor(n.pulseAccent);
    return FadeTransition(
      opacity: _fadeController,
      child: GestureDetector(
        onTapDown: (_) {
          setState(() {
            _isPressed = true;
          });
          _scaleController.forward();
        },
        onTapUp: (_) {
          setState(() {
            _isPressed = false;
          });
          _scaleController.reverse();
          // Handle card tap
          if (widget.onCardTap != null) {
            widget.onCardTap!(widget.notification);
          }
        },
        onTapCancel: () {
          setState(() {
            _isPressed = false;
          });
          _scaleController.reverse();
        },
        child: AnimatedBuilder(
          animation: _scaleController,
          builder: (context, child) {
            return Transform.scale(
              scale: 1.0 - (_scaleController.value * 0.025),
              child: Container(
                margin: EdgeInsets.symmetric(
                  vertical: isActionItem || highPriority ? 5 : 3,
                ),
                decoration: BoxDecoration(
                  color: _isPressed
                      ? accent.withValues(alpha: 0.1)
                      : shell.surfaceCard,
                  borderRadius: BorderRadius.circular(
                    isActionItem || highPriority ? 16 : 14,
                  ),
                  border: Border.all(
                    color: isActionItem
                        ? shell.surfaceCardBorder
                        : (_isPressed
                            ? accent.withValues(alpha: 0.45)
                            : highPriority
                                ? accent.withValues(alpha: 0.32)
                                : shell.surfaceCardBorder),
                    width: !isActionItem && highPriority ? 1.2 : 1,
                  ),
                  boxShadow: isActionItem
                      ? null
                      : <BoxShadow>[
                          if (highPriority)
                            BoxShadow(
                              color: accent.withValues(alpha: 0.14),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            )
                          else
                            BoxShadow(
                              color: shell.shadowSoft,
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                        ],
                ),
                clipBehavior: Clip.antiAlias,
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      if (isActionItem)
                        Container(
                          width: 3,
                          color: accent,
                        ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isActionItem || highPriority ? 14 : 12,
                            vertical: isActionItem || highPriority ? 14 : 11,
                          ),
                          child: Stack(
                            children: <Widget>[
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      if (isActionItem)
                                        _buildActionAvatar(shell, accent)
                                      else
                                        _buildAvatarWithRing(
                                          context,
                                          shell,
                                          accent,
                                        ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _buildNotificationText(
                                          shell,
                                          accent,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        flex: 0,
                                        child: isActionItem
                                            ? _buildActionRelativeTime(shell)
                                            : _buildActionItem(
                                                context,
                                                shell,
                                                isFollowing,
                                                isMutualFollow,
                                                currentUserId,
                                              ),
                                      ),
                                    ],
                                  ),
                                  if (n.showThreadContinueCta) ...<Widget>[
                                    const SizedBox(height: 10),
                                    _ThreadContinueCta(accent: accent),
                                  ],
                                ],
                              ),
                              if (widget.notification.status == 'pending')
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: AppColors.accent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              if (widget.notification.status == 'processing')
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  bottom: 0,
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.black
                                            .withValues(alpha: 0.7),
                                        shape: BoxShape.circle,
                                      ),
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            shell.onChrome,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildActionRelativeTime(StSupportShellStyle shell) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        _getCompactRelativeTime(),
        style: TextStyle(
          color: shell.mutedStrong,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildActionAvatar(StSupportShellStyle shell, Color accent) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accent.withValues(alpha: 0.15),
      ),
      child: Icon(
        Icons.checklist_rounded,
        size: 18,
        color: accent,
      ),
    );
  }

  Widget _buildAvatarWithRing(
    BuildContext context,
    StSupportShellStyle shell,
    Color accent,
  ) {
    final user = widget.notification.user;
    final avatarURL = user.avatarURL ?? '';
    final Color ringOuter = Theme.of(context).colorScheme.surface;

    return GestureDetector(
      onTap: _handleActorTap,
      child: Stack(
        children: [
          // User avatar - Always show user's avatar using UnifiedAvatarService
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: shell.surfaceCardBorder.withValues(alpha: 0.8),
                width: 2,
              ),
            ),
            child: ClipOval(
              child: avatarURL.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: avatarURL,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      fadeInDuration: const Duration(milliseconds: 180),
                      placeholder: (_, __) => Container(
                        width: 40,
                        height: 40,
                        color: shell.skeletonFill,
                      ),
                      errorWidget: (_, __, ___) => Container(
                        width: 40,
                        height: 40,
                        color: shell.skeletonLineDim,
                        child: Icon(
                          Icons.person_rounded,
                          color: shell.iconDim,
                          size: 22,
                        ),
                      ),
                    )
                  : Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: shell.skeletonLineDim,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.person_rounded,
                        color: shell.iconDim,
                        size: 22,
                      ),
                    ),
            ),
          ),

          // Notification type ring
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: accent, width: 2),
            ),
          ),

          // Online status indicator
          if (widget.notification.user.onlineStatus == 'online')
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: ringOuter,
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNotificationText(
    StSupportShellStyle shell,
    Color accent,
  ) {
    final ActivityNotification n = widget.notification;
    final bool isActionItem = n.isContentPlanType ||
        n.pulseAccent == ActivityPulseAccent.action;
    if (isActionItem) {
      return _buildActionItemText(shell);
    }
    final bool isMessage = isActivityMessageNotification(
      type: n.actionType,
      actionType: n.actionType,
      chatId: n.chatId,
      actionUrl: n.actionUrl,
    );
    final bool isSystemBroadcast =
        n.type == ActivityNotificationType.adminBroadcast && !isMessage;
    final String fullText = n.commentText?.trim() ?? '';
    final List<String> lines = fullText
        .split('\n')
        .map((String line) => line.trim())
        .where((String line) => line.isNotEmpty)
        .toList(growable: false);
    final String headline = isMessage
        ? 'sent you a message'
        : (isSystemBroadcast && lines.isNotEmpty
            ? lines.first
            : _getNotificationMessage());
    final String? preview = isMessage
        ? (fullText.isNotEmpty ? fullText : null)
        : (isSystemBroadcast
            ? (lines.length > 1 ? lines.sublist(1).join(' ') : null)
            : n.commentText?.trim());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: 15,
              color: shell.onChrome.withValues(alpha: 0.96),
              height: 1.32,
            ),
            children: [
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _handleActorTap,
                  child: Text(
                    widget.notification.user.displayName,
                    style: TextStyle(
                      color: shell.onChrome,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.32,
                    ),
                  ),
                ),
              ),
              if (!isSystemBroadcast)
                TextSpan(
                  text: ' $headline',
                  style: TextStyle(
                    color: shell.muted,
                    fontWeight: FontWeight.w400,
                  ),
                ),
            ],
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (isSystemBroadcast && headline.isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            headline,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: shell.onChrome.withValues(alpha: 0.92),
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
        ],
        if (preview != null && preview.isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            isSystemBroadcast ? preview : '"$preview"',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: shell.onChrome.withValues(alpha: 0.88),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ],
        const SizedBox(height: 6),
        Text(
          '${_getTimestampString()} • Tap to ${_tapHint()}',
          style: TextStyle(
            color: shell.mutedStrong,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildActionItemText(StSupportShellStyle shell) {
    final String fullText = widget.notification.commentText?.trim() ?? '';
    final List<String> lines = fullText
        .split('\n')
        .map((String line) => line.trim())
        .where((String line) => line.isNotEmpty)
        .toList(growable: false);
    final String title = lines.isNotEmpty
        ? lines.first
        : (widget.notification.user.displayName.isNotEmpty
            ? widget.notification.user.displayName
            : 'Reminder');
    String? body = lines.length > 1 ? lines.sublist(1).join(' ') : null;
    if (body != null) {
      body = body
          .replaceAll(' · Tap to open Content Planner.', '')
          .replaceAll(' • Tap to open Content Planner.', '')
          .replaceAll('Tap to open Content Planner.', '')
          .trim();
      if (body.isEmpty) {
        body = null;
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: shell.onChrome,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
        ),
        if (body != null) ...<Widget>[
          const SizedBox(height: 2),
          Text(
            body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: shell.muted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
        ],
      ],
    );
  }

  String _tapHint() {
    if (widget.notification.showThreadContinueCta) {
      return 'continue conversation';
    }
    if (widget.notification.videoId?.isNotEmpty == true) {
      return 'view clip';
    }
    if (widget.notification.isContentPlanType) {
      return 'open Content Planner';
    }
    if (widget.notification.isTippyType ||
        activityActionUrlLooksLikeTrendDiscovery(
          widget.notification.actionUrl,
        )) {
      return activityActionUrlLooksLikeTrendDiscovery(
            widget.notification.actionUrl,
          )
          ? 'open Trend Discovery'
          : 'ask Tippy';
    }
    return 'open';
  }

  Widget _buildActionItem(
    BuildContext context,
    StSupportShellStyle shell,
    bool isFollowing,
    bool isMutualFollow,
    String? currentUserId,
  ) {
    if (widget.notification.postThumbnailUrl != null &&
        widget.notification.postThumbnailUrl!.isNotEmpty) {
      return GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onPostTap(widget.notification);
        },
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: shell.surfaceCardBorder,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: shell.shadowSoft,
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: widget.notification.postThumbnailUrl!,
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              memCacheWidth: (44 * MediaQuery.devicePixelRatioOf(context))
                  .round()
                  .clamp(88, 256),
              memCacheHeight: (44 * MediaQuery.devicePixelRatioOf(context))
                  .round()
                  .clamp(88, 256),
              filterQuality: FilterQuality.high,
              fadeInDuration: const Duration(milliseconds: 120),
              placeholder: (_, __) => Container(
                color: shell.skeletonFill,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.play_circle_outline,
                      color: shell.muted,
                      size: 20,
                    ),
                    const SizedBox(height: 2),
                    Icon(
                      Icons.photo,
                      color: shell.iconDim,
                      size: 12,
                    ),
                  ],
                ),
              ),
              errorWidget: (_, __, ___) => Container(
                color: shell.skeletonFill,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.play_circle_outline,
                      color: shell.muted,
                      size: 20,
                    ),
                    const SizedBox(height: 2),
                    Icon(
                      Icons.photo,
                      color: shell.iconDim,
                      size: 12,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    } else if (widget.notification.type == ActivityNotificationType.follow &&
        widget.notification.user.id != currentUserId) {
      return GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          _handleFollowAction(isFollowing, isMutualFollow);
        },
        child: AbsorbPointer(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: AppColors.primaryGradient,
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.22),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.28),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _isLoadingFollowStatus
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  )
                : Text(
                    _getFollowButtonText(
                      isFollowing: isFollowing,
                      isMutualFollow: isMutualFollow,
                    ),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  String _getNotificationMessage() {
    switch (widget.notification.type) {
      case ActivityNotificationType.like:
        if (widget.notification.commentId?.isNotEmpty == true) {
          return 'liked your comment';
        }
        return 'liked your post';
      case ActivityNotificationType.follow:
        return 'started following you';
      case ActivityNotificationType.comment:
        if (widget.notification.commentText != null) {
          return 'commented: "${widget.notification.commentText}"';
        } else {
          return 'commented on your post';
        }
      case ActivityNotificationType.tag:
        return 'tagged you in their video';
      case ActivityNotificationType.mention:
        if (widget.notification.commentText != null) {
          return 'mentioned you: "${widget.notification.commentText}"';
        } else {
          return 'mentioned you in a comment';
        }
      case ActivityNotificationType.commentReply:
        return 'replied to your thread';
      case ActivityNotificationType.newVideo:
        return 'posted a new video';
      case ActivityNotificationType.milestone:
        if (widget.notification.milestoneType != null &&
            widget.notification.milestoneValue != null) {
          final formattedValue = _formatMilestone(
            widget.notification.milestoneValue!,
          );
          return 'Your video reached $formattedValue ${widget.notification.milestoneType}! 🎉';
        } else {
          return 'reached a milestone! 🎉';
        }
      case ActivityNotificationType.liveStream:
        if (widget.notification.commentText != null) {
          return widget.notification.commentText!;
        } else {
          return 'is live now! 🔴';
        }
      case ActivityNotificationType.adminBroadcast:
        if (isActivityMessageNotification(
          type: widget.notification.actionType,
          actionType: widget.notification.actionType,
          chatId: widget.notification.chatId,
          actionUrl: widget.notification.actionUrl,
        )) {
          return 'sent you a message';
        }
        if (widget.notification.commentText != null &&
            widget.notification.commentText!.trim().isNotEmpty) {
          return widget.notification.commentText!;
        }
        return 'sent you an update';
    }
  }

  String _getTimestampString() {
    final now = DateTime.now();
    final difference = now.difference(widget.notification.timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'now';
    }
  }

  String _getCompactRelativeTime() {
    final Duration difference =
        DateTime.now().difference(widget.notification.timestamp);
    if (difference.inDays > 0) {
      return '${difference.inDays}d';
    }
    if (difference.inHours > 0) {
      return '${difference.inHours}h';
    }
    if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    }
    return 'now';
  }

  String _formatMilestone(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    } else {
      return value.toString();
    }
  }

  String _getFollowButtonText({
    required bool isFollowing,
    required bool isMutualFollow,
  }) {
    if (isMutualFollow) {
      return 'Connected';
    }
    if (isFollowing) {
      return 'Following';
    }
    return 'Follow';
  }

  void _handleFollowAction(bool isFollowing, bool isMutualFollow) async {
    try {
      setState(() {
        _isLoadingFollowStatus = true;
      });
      bool success;
      if (isFollowing) {
        success =
            await _followsService.unfollowUser(widget.notification.user.id);
        if (success) {
          setState(() {
            _isFollowing = false;
            _isLoadingFollowStatus = false;
          });
        }
      } else {
        success = await _followsService.followUser(widget.notification.user.id);
        if (success) {
          setState(() {
            _isFollowing = true;
            _isLoadingFollowStatus = false;
          });
          await _loadFollowStatus();
        }
      }
      if (success) {
        ref.read(followRefreshProvider.notifier).state++;
      }
      if (mounted) {
        final String username = widget.notification.user.username;
        final String message = success
            ? (isFollowing
                ? 'Unfollowed @$username'
                : (isMutualFollow
                    ? 'Stayed connected with @$username'
                    : 'Following @$username'))
            : 'Unable to update follow status for @$username';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: success ? AppColors.success : AppColors.error,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ ActivityRowView: Error handling follow action: $e');
      if (mounted) {
        setState(() {
          _isLoadingFollowStatus = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}

class _ThreadContinueCta extends StatelessWidget {
  const _ThreadContinueCta({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            'Continue thread',
            style: TextStyle(
              color: accent,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.arrow_forward_rounded, size: 14, color: accent),
        ],
      ),
    );
  }
}
