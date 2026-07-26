import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/unified_avatar_service.dart';
import 'network_view_controller.dart';

enum NetworkListKind {
  connections,
  followers,
  following,
}

class NetworkViewHeader extends StatelessWidget {
  const NetworkViewHeader({
    super.key,
    required this.onRefresh,
    required this.isRefreshing,
  });

  final VoidCallback onRefresh;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A1333),
            const Color(0xFF090312),
          ],
        ),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Network',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Manage the people you follow, the ones following you, and your mutual connections.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton.filledTonal(
            onPressed: isRefreshing ? null : onRefresh,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              foregroundColor: Colors.white,
            ),
            icon: isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }
}

class NetworkViewTabBarCard extends StatelessWidget {
  const NetworkViewTabBarCard({
    super.key,
    required this.controller,
  });

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFF151024),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: TabBar(
        controller: controller,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            colors: [Color(0xFF955CFF), Color(0xFF3D99F7)],
          ),
        ),
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white60,
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        tabs: const [
          Tab(text: 'Connections'),
          Tab(text: 'Followers'),
          Tab(text: 'Following'),
        ],
      ),
    );
  }
}

class NetworkViewLoadingState extends StatelessWidget {
  const NetworkViewLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF955CFF)),
          ),
          SizedBox(height: 16),
          Text(
            'Loading your network...',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class NetworkViewErrorState extends StatelessWidget {
  const NetworkViewErrorState({
    super.key,
    required this.error,
    required this.onRetry,
  });

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 72,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 18),
            const Text(
              'Couldn’t load your network',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            SelectableText.rich(
              TextSpan(
                text: error,
                style: TextStyle(
                  color: Colors.red.shade300,
                  height: 1.35,
                  fontSize: 14,
                ),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF955CFF),
              ),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class NetworkUserList extends StatelessWidget {
  const NetworkUserList({
    super.key,
    required this.listKind,
    required this.users,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.emptyIcon,
    required this.pendingActionUserId,
    required this.pendingActionType,
    required this.onUserTap,
    required this.onFollow,
    required this.onUnfollow,
    required this.onRemove,
  });

  final NetworkListKind listKind;
  final List<User> users;
  final String emptyTitle;
  final String emptySubtitle;
  final IconData emptyIcon;
  final String? pendingActionUserId;
  final NetworkActionType? pendingActionType;
  final ValueChanged<User> onUserTap;
  final ValueChanged<User> onFollow;
  final ValueChanged<User> onUnfollow;
  final ValueChanged<User> onRemove;

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              emptyIcon,
              size: 72,
              color: Colors.white24,
            ),
            const SizedBox(height: 16),
            Text(
              emptyTitle,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Text(
                emptySubtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      itemCount: users.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final user = users[index];
        return NetworkUserTile(
          listKind: listKind,
          user: user,
          isBusy: pendingActionUserId == user.id,
          pendingActionType: pendingActionType,
          onTap: () => onUserTap(user),
          onFollow: () => onFollow(user),
          onUnfollow: () => onUnfollow(user),
          onRemove: () => onRemove(user),
        );
      },
    );
  }
}

class NetworkUserTile extends StatelessWidget {
  const NetworkUserTile({
    super.key,
    required this.listKind,
    required this.user,
    required this.isBusy,
    required this.pendingActionType,
    required this.onTap,
    required this.onFollow,
    required this.onUnfollow,
    required this.onRemove,
  });

  final NetworkListKind listKind;
  final User user;
  final bool isBusy;
  final NetworkActionType? pendingActionType;
  final VoidCallback onTap;
  final VoidCallback onFollow;
  final VoidCallback onUnfollow;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0xFF120C20),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.07),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UnifiedAvatarService().getAvatar(
                  imageUrl: user.avatarURL ?? '',
                  radius: 28,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@${user.username}',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                        ),
                      ),
                      if ((user.bio ?? '').isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          user.bio!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                NetworkUserActions(
                  listKind: listKind,
                  isBusy: isBusy,
                  pendingActionType: pendingActionType,
                  onFollow: onFollow,
                  onUnfollow: onUnfollow,
                  onRemove: onRemove,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class NetworkUserActions extends StatelessWidget {
  const NetworkUserActions({
    super.key,
    required this.listKind,
    required this.isBusy,
    required this.pendingActionType,
    required this.onFollow,
    required this.onUnfollow,
    required this.onRemove,
  });

  final NetworkListKind listKind;
  final bool isBusy;
  final NetworkActionType? pendingActionType;
  final VoidCallback onFollow;
  final VoidCallback onUnfollow;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final actions = switch (listKind) {
      NetworkListKind.connections => <Widget>[
          _ActionPillButton(
            label: 'Unfollow',
            icon: Icons.person_remove_alt_1_rounded,
            color: const Color(0xFFF59E0B),
            isBusy: isBusy && pendingActionType == NetworkActionType.unfollow,
            onPressed: isBusy ? null : onUnfollow,
          ),
          _ActionPillButton(
            label: 'Remove',
            icon: Icons.block_rounded,
            color: const Color(0xFFFF6B6B),
            isBusy: isBusy && pendingActionType == NetworkActionType.remove,
            onPressed: isBusy ? null : onRemove,
          ),
        ],
      NetworkListKind.followers => <Widget>[
          _ActionPillButton(
            label: 'Follow back',
            icon: Icons.person_add_alt_1_rounded,
            color: const Color(0xFF6EE7B7),
            isBusy: isBusy && pendingActionType == NetworkActionType.follow,
            onPressed: isBusy ? null : onFollow,
          ),
          _ActionPillButton(
            label: 'Remove',
            icon: Icons.block_rounded,
            color: const Color(0xFFFF6B6B),
            isBusy: isBusy && pendingActionType == NetworkActionType.remove,
            onPressed: isBusy ? null : onRemove,
          ),
        ],
      NetworkListKind.following => <Widget>[
          _ActionPillButton(
            label: 'Unfollow',
            icon: Icons.person_remove_alt_1_rounded,
            color: const Color(0xFFF59E0B),
            isBusy: isBusy && pendingActionType == NetworkActionType.unfollow,
            onPressed: isBusy ? null : onUnfollow,
          ),
        ],
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          actions[i],
          if (i != actions.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _ActionPillButton extends StatelessWidget {
  const _ActionPillButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.isBusy,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool isBusy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: color.withValues(alpha: 0.22),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isBusy)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                )
              else
                Icon(
                  icon,
                  color: color,
                  size: 15,
                ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
