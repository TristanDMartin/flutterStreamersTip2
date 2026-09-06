import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/home_video.dart';
import '../../providers/video_service_provider.dart';
import '../../utils/post_count_rules.dart';
import '../../features/creator_score/creator_score_widgets.dart';
import '../../models/user_status.dart' show UserPresence, UserStatus;
import '../../providers/status_provider.dart';
import '../../routing/app_routes.dart';
import '../../utils/avatar_url_resolver.dart';
import '../edit_profile_view.dart';
import '../share_profile_view.dart';
import '../streamer_card_sections.dart';
import '../user_stats_row.dart';
import '../profile/profile_username_utils.dart';
import 'user_status_color.dart';

/// Tippy-aligned identity header: avatar, name, handle, quiet stats, CTAs.
/// Bio lives on the flip-side [ProfileBackView], matching Streamer Card.
class ProfileViewHeaderSection extends StatelessWidget {
  const ProfileViewHeaderSection({
    super.key,
    required this.userData,
    required this.profileUserId,
    required this.isCurrentUser,
    this.useInitialDataOnly = false,
  });

  final Map<String, dynamic> userData;
  final String profileUserId;
  final bool isCurrentUser;
  final bool useInitialDataOnly;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Column(
            children: <Widget>[
              const SizedBox(height: 8),
              _ProfileAvatarRing(
                userData: userData,
                isCurrentUser: isCurrentUser,
              ),
              const SizedBox(height: 14),
              _ProfileNameAndHandle(userData: userData),
              const SizedBox(height: 14),
              _ProfileQuietStats(
                profileUserId: profileUserId,
                useInitialDataOnly: useInitialDataOnly,
              ),
              if (isCurrentUser) ...<Widget>[
                const SizedBox(height: 14),
                _ProfilePrimaryButtonsRow(userData: userData),
              ],
            ],
          ),
          if (!useInitialDataOnly)
            Positioned(
              top: 4,
              right: 0,
              child: CreatorScoreBadge(
                userId: profileUserId,
                compact: true,
              ),
            ),
        ],
      ),
    );
  }
}

class _ProfileAvatarRing extends StatelessWidget {
  const _ProfileAvatarRing({
    required this.userData,
    required this.isCurrentUser,
  });

  final Map<String, dynamic> userData;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    final String? avatarUrl = resolveAvatarUrl(userData);
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Container(
          width: 104,
          height: 104,
          padding: const EdgeInsets.all(2.5),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                StreamerCardBackStyle.ringBlue,
                StreamerCardBackStyle.ringPurple,
              ],
            ),
          ),
          child: ClipOval(
            child: ColoredBox(
              color: StreamerCardBackStyle.avatarFill,
              child: avatarUrl != null && avatarUrl.isNotEmpty
                  ? Image.network(
                      avatarUrl,
                      key: ValueKey<String>(avatarUrl),
                      fit: BoxFit.cover,
                      errorBuilder: (BuildContext c, Object e, StackTrace? s) =>
                          _AvatarInitial(userData: userData),
                    )
                  : _AvatarInitial(userData: userData),
            ),
          ),
        ),
        if (isCurrentUser)
          Consumer(
            builder: (BuildContext context, WidgetRef ref, Widget? child) {
              final AsyncValue<UserPresence> statusAsync = ref.watch(
                userStatusProvider(userData['id'] ?? ''),
              );
              return statusAsync.when(
                data: (UserPresence presence) {
                  if (presence.status == UserStatus.offline) {
                    return const SizedBox.shrink();
                  }
                  final Color c = profileUserStatusColor(presence.status);
                  return Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: StreamerCardBackStyle.background,
                          width: 2,
                        ),
                      ),
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (Object e, StackTrace s) => const SizedBox.shrink(),
              );
            },
          ),
      ],
    );
  }
}

class _AvatarInitial extends StatelessWidget {
  const _AvatarInitial({required this.userData});

  final Map<String, dynamic> userData;

  @override
  Widget build(BuildContext context) {
    final String letter =
        ProfileUsernameUtils.resolveAvatarInitialLetter(userData);
    return ColoredBox(
      color: StreamerCardBackStyle.avatarFill,
      child: Center(
        child: Text(
          letter,
          style: const TextStyle(
            color: StreamerCardBackStyle.softText,
            fontSize: 36,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ProfileNameAndHandle extends StatelessWidget {
  const _ProfileNameAndHandle({required this.userData});

  final Map<String, dynamic> userData;

  @override
  Widget build(BuildContext context) {
    final String displayName =
        ProfileUsernameUtils.resolveDisplayName(userData);
    final String atHandle = ProfileUsernameUtils.formatAtHandle(userData);
    return Column(
      children: <Widget>[
        Text(
          displayName.isNotEmpty ? displayName : 'Unknown User',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: StreamerCardBackStyle.softText,
            fontSize: 22,
            fontWeight: FontWeight.w600,
            height: 1.1,
          ),
        ),
        if (atHandle.isNotEmpty) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            atHandle,
            style: const TextStyle(
              color: StreamerCardBackStyle.muted,
              fontSize: 13,
              fontWeight: FontWeight.w400,
              height: 1.0,
            ),
          ),
        ],
      ],
    );
  }
}

class _ProfileQuietStats extends ConsumerWidget {
  const _ProfileQuietStats({
    required this.profileUserId,
    required this.useInitialDataOnly,
  });

  final String profileUserId;
  final bool useInitialDataOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (useInitialDataOnly) {
      return const _StaticProfileQuietStats();
    }
    final List<HomeVideo> allVideos = ref.watch(videoServiceStateProvider);
    final bool isVideoServiceLoading = ref.watch(videoServiceLoadingProvider);
    final List<HomeVideo> userVideos =
        ref.watch(userVideosProvider(profileUserId));
    final int? postsCountOverride = resolvePostsCountOverride(
      userVideos: userVideos,
      allVideos: allVideos,
      isVideoServiceLoading: isVideoServiceLoading,
    );
    return UserStatsRow(
      userId: profileUserId,
      postsCountOverride: postsCountOverride,
      spacing: 28,
      valueTextStyle: const TextStyle(
        color: StreamerCardBackStyle.softText,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.0,
      ),
      labelTextStyle: const TextStyle(
        color: StreamerCardBackStyle.muted,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.0,
      ),
    );
  }
}

class _StaticProfileQuietStats extends StatelessWidget {
  const _StaticProfileQuietStats();

  @override
  Widget build(BuildContext context) {
    const TextStyle valueStyle = TextStyle(
      color: StreamerCardBackStyle.softText,
      fontSize: 18,
      fontWeight: FontWeight.w600,
      height: 1.0,
    );
    const TextStyle labelStyle = TextStyle(
      color: StreamerCardBackStyle.muted,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.0,
    );
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: _StaticProfileStat(
            label: 'Posts',
            value: '0',
            valueStyle: valueStyle,
            labelStyle: labelStyle,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _StaticProfileStat(
            label: 'Followers',
            value: '0',
            valueStyle: valueStyle,
            labelStyle: labelStyle,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _StaticProfileStat(
            label: 'Following',
            value: '0',
            valueStyle: valueStyle,
            labelStyle: labelStyle,
          ),
        ),
      ],
    );
  }
}

class _StaticProfileStat extends StatelessWidget {
  const _StaticProfileStat({
    required this.label,
    required this.value,
    required this.valueStyle,
    required this.labelStyle,
  });

  final String label;
  final String value;
  final TextStyle valueStyle;
  final TextStyle labelStyle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(value, style: valueStyle),
        const SizedBox(height: 6),
        Text(label, style: labelStyle),
      ],
    );
  }
}

class _ProfilePrimaryButtonsRow extends StatelessWidget {
  const _ProfilePrimaryButtonsRow({required this.userData});

  final Map<String, dynamic> userData;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _ProfileHeaderActionButton(
            text: 'Edit Profile',
            icon: Icons.edit_outlined,
            isPrimary: true,
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  settings: const RouteSettings(
                    name: AppRoutes.editProfile,
                  ),
                  builder: (BuildContext context) => EditProfileView(
                    user: userData,
                    onUserUpdated: (Map<String, dynamic> updatedUser) {
                      HapticFeedback.lightImpact();
                    },
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ProfileHeaderActionButton(
            text: 'Share Profile',
            icon: Icons.ios_share_rounded,
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  settings: const RouteSettings(
                    name: AppRoutes.shareProfile,
                  ),
                  builder: (BuildContext context) => ShareProfileView(
                    user: userData,
                    dismiss: () => Navigator.of(context).pop(),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ProfileHeaderActionButton extends StatelessWidget {
  const _ProfileHeaderActionButton({
    required this.text,
    required this.icon,
    required this.onPressed,
    this.isPrimary = false,
  });

  final String text;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: isPrimary
              ? StreamerCardBackStyle.accent.withValues(alpha: 0.22)
              : StreamerCardBackStyle.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPrimary
                ? StreamerCardBackStyle.accent.withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              icon,
              color: isPrimary
                  ? StreamerCardBackStyle.lavender
                  : StreamerCardBackStyle.softText,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(
                color: isPrimary
                    ? StreamerCardBackStyle.lavender
                    : StreamerCardBackStyle.softText,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
