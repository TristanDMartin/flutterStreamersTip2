import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/app_colors.dart';
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
  });

  final Map<String, dynamic> userData;
  final String profileUserId;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Column(
            children: <Widget>[
              const SizedBox(height: 14),
              _ProfileAvatarRing(
                userData: userData,
                isCurrentUser: isCurrentUser,
              ),
              const SizedBox(height: 16),
              _ProfileNameAndHandle(userData: userData),
              const SizedBox(height: 18),
              _ProfileQuietStats(
                profileUserId: profileUserId,
              ),
              if (isCurrentUser) ...<Widget>[
                const SizedBox(height: 18),
                _ProfilePrimaryButtonsRow(userData: userData),
              ],
            ],
          ),
          Positioned(
            top: 10,
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
                color: Colors.black.withValues(alpha: 0.35),
              ),
              child: ClipOval(
                child: avatarUrl != null && avatarUrl.isNotEmpty
                    ? Image.network(
                        avatarUrl,
                        key: ValueKey<String>(avatarUrl),
                        fit: BoxFit.cover,
                        errorBuilder:
                            (BuildContext c, Object e, StackTrace? s) =>
                                _AvatarInitial(userData: userData),
                      )
                    : _AvatarInitial(userData: userData),
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
                          color: AppColors.profileViewBackground,
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

class _AvatarInitial extends StatelessWidget {
  const _AvatarInitial({required this.userData});

  final Map<String, dynamic> userData;

  @override
  Widget build(BuildContext context) {
    final String letter =
        ProfileUsernameUtils.resolveAvatarInitialLetter(userData);
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.25),
      child: Center(
        child: Text(
          letter,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 40,
            fontWeight: FontWeight.w700,
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
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w900,
            height: 1.05,
          ),
        ),
        if (atHandle.isNotEmpty) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            atHandle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontSize: 16,
              fontWeight: FontWeight.w600,
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
  });

  final String profileUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w800,
        height: 1.0,
      ),
      labelTextStyle: TextStyle(
        color: Colors.white.withValues(alpha: 0.55),
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 1.0,
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
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          gradient: isPrimary
              ? const LinearGradient(
                  colors: <Color>[
                    AppColors.primary,
                    Color(0xFF7768DF),
                    Color(0xFF4897D2),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          color: isPrimary
              ? null
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isPrimary
                ? Colors.white.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.12),
          ),
          boxShadow: isPrimary
              ? <BoxShadow>[
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.32),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
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
