import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/design/apple_material_design_system.dart';
import '../../core/design/adaptive_widgets.dart';
import '../../models/user_model.dart';
import '../status_aware_avatar.dart';

/// Adaptive list tile for displaying users in network views
/// Uses iOS grouped list style on iOS and Material cards on Android
class AdaptiveUserListTile extends StatelessWidget {
  const AdaptiveUserListTile({
    super.key,
    required this.user,
    this.onTap,
    this.trailing,
    this.showFollowButton = false,
    this.isFollowing = false,
    this.onFollowTap,
  });

  final User user;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool showFollowButton;
  final bool isFollowing;
  final VoidCallback? onFollowTap;

  @override
  Widget build(BuildContext context) {
    final displayName = user.displayName ?? 'Unknown';
    final username = user.username ?? '';
    
    final leadingAvatar = StatusAwareAvatar(
      userId: user.id,
      avatarUrl: user.avatarUrl,
      size: 48,
      showStatusRing: true,
    );

    final titleWidget = Text(
      displayName,
      style: AppleMaterialDesign.headlineStyle(context),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    final subtitleWidget = username.isNotEmpty
        ? Text(
            '@$username',
            style: AppleMaterialDesign.subheadlineStyle(context).copyWith(
              color: AppleMaterialDesign.isIOS
                  ? CupertinoColors.secondaryLabel
                  : Colors.grey[600],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          )
        : null;

    final trailingWidget = trailing ??
        (showFollowButton ? _buildFollowButton(context) : null);

    if (AppleMaterialDesign.isIOS) {
      return Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppleMaterialDesign.paddingMedium,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground.resolveFrom(context),
          borderRadius: BorderRadius.circular(AppleMaterialDesign.cardRadiusIOS),
          boxShadow: AppleMaterialDesign.iosShadowSmall,
        ),
        child: CupertinoListTile(
          leading: leadingAvatar,
          title: titleWidget,
          subtitle: subtitleWidget,
          trailing: trailingWidget,
          onTap: onTap != null
              ? () {
                  HapticFeedback.selectionClick();
                  onTap!();
                }
              : null,
          padding: const EdgeInsets.symmetric(
            horizontal: AppleMaterialDesign.paddingMedium,
            vertical: AppleMaterialDesign.paddingSmall,
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppleMaterialDesign.paddingMedium,
        vertical: 6,
      ),
      elevation: AppleMaterialDesign.materialElevationMedium,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppleMaterialDesign.cardRadiusAndroid),
      ),
      child: ListTile(
        leading: leadingAvatar,
        title: titleWidget,
        subtitle: subtitleWidget,
        trailing: trailingWidget,
        onTap: onTap != null
            ? () {
                HapticFeedback.selectionClick();
                onTap!();
              }
            : null,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppleMaterialDesign.paddingMedium,
          vertical: AppleMaterialDesign.paddingSmall,
        ),
      ),
    );
  }

  Widget _buildFollowButton(BuildContext context) {
    if (AppleMaterialDesign.isIOS) {
      return CupertinoButton(
        onPressed: onFollowTap != null
            ? () {
                HapticFeedback.mediumImpact();
                onFollowTap!();
              }
            : null,
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 6,
        ),
        minSize: 32,
        borderRadius: BorderRadius.circular(20),
        color: isFollowing
            ? CupertinoColors.systemGrey5
            : CupertinoTheme.of(context).primaryColor,
        child: Text(
          isFollowing ? 'Following' : 'Follow',
          style: TextStyle(
            fontSize: AppleMaterialDesign.iosFootnote,
            fontWeight: AppleMaterialDesign.weightSemibold,
            color: isFollowing
                ? CupertinoColors.label
                : CupertinoColors.white,
          ),
        ),
      );
    }

    return FilledButton(
      onPressed: onFollowTap != null
          ? () {
              HapticFeedback.mediumImpact();
              onFollowTap!();
            }
          : null,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        minimumSize: const Size(0, 36),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: isFollowing
            ? Theme.of(context).colorScheme.surfaceVariant
            : Theme.of(context).colorScheme.primary,
        foregroundColor: isFollowing
            ? Theme.of(context).colorScheme.onSurfaceVariant
            : Theme.of(context).colorScheme.onPrimary,
      ),
      child: Text(
        isFollowing ? 'FOLLOWING' : 'FOLLOW',
        style: TextStyle(
          fontSize: AppleMaterialDesign.androidLabelMedium,
          fontWeight: AppleMaterialDesign.weightMedium,
        ),
      ),
    );
  }
}
