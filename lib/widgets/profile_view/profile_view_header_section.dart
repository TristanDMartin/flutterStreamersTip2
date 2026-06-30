import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/app_colors.dart';
import '../../models/home_video.dart';
import '../../providers/video_service_provider.dart';
import '../../utils/post_count_rules.dart';
import '../../core/theme/support_shell_style.dart';
import '../../features/creator_score/creator_score_widgets.dart';
import '../../models/user_status.dart' show UserPresence, UserStatus;
import '../../providers/status_provider.dart';
import '../../routing/app_routes.dart';
import '../../utils/avatar_url_resolver.dart';
import '../edit_profile_view.dart';
import '../share_profile_view.dart';
import '../user_stats_row.dart';
import 'user_status_color.dart';

/// Avatar, name, stats card, and primary actions for the profile header.
class ProfileViewHeaderSection extends StatelessWidget {
  const ProfileViewHeaderSection({
    super.key,
    required this.userData,
    required this.profileUserId,
    required this.isCurrentUser,
  });

  final Map<String, dynamic> userData;
  final String profileUserId;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _ProfileAvatarRing(
          userData: userData,
          isCurrentUser: isCurrentUser,
        ),
        const SizedBox(height: 18),
        _ProfileNameAndHandle(userData: userData),
        const SizedBox(height: 22),
        _ProfileStatsSystemCard(
          userData: userData,
          profileUserId: profileUserId,
          isCurrentUser: isCurrentUser,
        ),
      ],
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
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final String? avatarUrl = resolveAvatarUrl(userData);
    final Color avatarInnerRing = shell.isLight
        ? scheme.surfaceContainerHighest.withValues(alpha: 0.85)
        : Colors.black.withValues(alpha: 0.2);
    final Color placeholderIcon = shell.iconDim;
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Container(
          width: 112,
          height: 112,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              colors: <Color>[
                Color(0xFFFF6CAB),
                Color(0xFF8E54E9),
                Color(0xFF3D99F7),
                Color(0xFFFF6CAB),
              ],
            ),
          ),
          child: Center(
            child: Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: avatarInnerRing,
              ),
              child: ClipOval(
                child: avatarUrl != null && avatarUrl.isNotEmpty
                    ? Image.network(
                        avatarUrl,
                        key: ValueKey<String>(avatarUrl),
                        fit: BoxFit.cover,
                        errorBuilder:
                            (BuildContext c, Object e, StackTrace? s) => Icon(
                          Icons.person,
                          color: placeholderIcon,
                          size: 48,
                        ),
                      )
                    : Icon(
                        Icons.person,
                        color: placeholderIcon,
                        size: 48,
                      ),
              ),
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
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.surface,
                          width: 2,
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: c.withValues(alpha: 0.5),
                            blurRadius: 6,
                          ),
                        ],
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

class _ProfileNameAndHandle extends StatelessWidget {
  const _ProfileNameAndHandle({required this.userData});

  final Map<String, dynamic> userData;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Column(
      children: <Widget>[
        Text(
          userData['displayName'] as String? ?? 'Unknown User',
          style: TextStyle(
            color: scheme.onSurface,
            fontSize: 34,
            fontWeight: FontWeight.w900,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '@${userData['username'] ?? 'unknown'}',
          style: TextStyle(
            color: scheme.onSurface.withValues(alpha: 0.72),
            fontSize: 18,
            fontWeight: FontWeight.w600,
            height: 1.0,
          ),
        ),
      ],
    );
  }
}

class _ProfileStatsSystemCard extends ConsumerWidget {
  const _ProfileStatsSystemCard({
    required this.userData,
    required this.profileUserId,
    required this.isCurrentUser,
  });

  final Map<String, dynamic> userData;
  final String profileUserId;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<HomeVideo> allVideos =
        ref.watch(videoServiceStateProvider);
    final bool isVideoServiceLoading =
        ref.watch(videoServiceLoadingProvider);
    final List<HomeVideo> userVideos =
        ref.watch(userVideosProvider(profileUserId));
    final int? postsCountOverride = resolvePostsCountOverride(
      userVideos: userVideos,
      allVideos: allVideos,
      isVideoServiceLoading: isVideoServiceLoading,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: scheme.outline.withValues(alpha: 0.35),
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: <Widget>[
                UserStatsRow(
                  userId: profileUserId,
                  postsCountOverride: postsCountOverride,
                  spacing: 28,
                  valueTextStyle: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                  labelTextStyle: TextStyle(
                    color: scheme.onSurface.withValues(alpha: 0.62),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.0,
                  ),
                ),
                if (isCurrentUser) ...<Widget>[
                  const SizedBox(height: 18),
                  Container(
                    height: 1,
                    color: scheme.outline.withValues(alpha: 0.25),
                  ),
                  const SizedBox(height: 18),
                  _ProfilePrimaryButtonsRow(userData: userData),
                ],
              ],
            ),
          ),
          Positioned(
            top: -24,
            right: -10,
            child: CreatorScoreBadge(userId: profileUserId),
          ),
        ],
      ),
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
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color fg = isPrimary ? scheme.onPrimary : scheme.onSurface;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          gradient: isPrimary
              ? const LinearGradient(
                  colors: AppColors.supportAccentGradient,
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          color: isPrimary ? null : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isPrimary
                ? scheme.onPrimary.withValues(alpha: 0.22)
                : scheme.outline.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, color: fg, size: 18),
            const SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(
                color: fg,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
