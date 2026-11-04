import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import '../core/design/apple_material_design_system.dart';
import '../providers/current_user_provider.dart';
import '../providers/unread_messages_provider.dart';
import '../qa/qa_keys.dart';
import '../utils/avatar_url_resolver.dart';

/// Adaptive bottom navigation that uses CupertinoTabBar on iOS
/// and Material 3 NavigationBar on Android
class AdaptiveBottomNavigation extends ConsumerStatefulWidget {
  const AdaptiveBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  ConsumerState<AdaptiveBottomNavigation> createState() =>
      _AdaptiveBottomNavigationState();
}

class _AdaptiveBottomNavigationState
    extends ConsumerState<AdaptiveBottomNavigation> {
  void _handleTap(int index) {
    if (index != widget.currentIndex) {
      HapticFeedback.selectionClick();
    } else {
      HapticFeedback.lightImpact();
    }
    widget.onTap(index);
  }

  @override
  Widget build(BuildContext context) {
    if (AppleMaterialDesign.isIOS) {
      return _buildIOSTabBar();
    }
    return _buildAndroidNavigationBar();
  }

  Widget _buildIOSTabBar() {
    return CupertinoTabBar(
      currentIndex: widget.currentIndex == 2 ? 0 : widget.currentIndex,
      onTap: _handleTap,
      backgroundColor: CupertinoColors.systemBackground.resolveFrom(context),
      border: Border(
        top: BorderSide(
          color: CupertinoColors.separator.resolveFrom(context),
          width: 0.5,
        ),
      ),
      items: [
        _buildIOSTabItem(
          icon: CupertinoIcons.house_fill,
          label: 'Home',
          index: 0,
        ),
        _buildIOSTabItem(
          icon: CupertinoIcons.person_2_fill,
          label: 'Network',
          index: 1,
        ),
        _buildIOSCreateTabItem(),
        _buildIOSInboxTabItem(),
        _buildIOSProfileTabItem(),
      ],
    );
  }

  BottomNavigationBarItem _buildIOSTabItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    // Skip the create button (index 2)
    final isSelected = widget.currentIndex == index;

    return BottomNavigationBarItem(
      icon: Icon(icon, size: 28),
      label: label,
      activeIcon: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 28),
          const SizedBox(height: 2),
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: CupertinoTheme.of(context).primaryColor,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  BottomNavigationBarItem _buildIOSCreateTabItem() {
    return BottomNavigationBarItem(
      icon: Container(
        width: 56,
        height: 56,
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: CupertinoTheme.of(context).primaryColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: CupertinoTheme.of(context).primaryColor.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          CupertinoIcons.add,
          color: CupertinoColors.white,
          size: 32,
        ),
      ),
      label: '',
    );
  }

  BottomNavigationBarItem _buildIOSInboxTabItem() {
    final messageUnreadCount = ref.watch(unreadMessagesProvider).maybeWhen(
          data: (int count) => count,
          orElse: () => 0,
        );

    return BottomNavigationBarItem(
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(CupertinoIcons.envelope, size: 28),
          if (messageUnreadCount > 0)
            Positioned(
              right: -6,
              top: -6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: CupertinoColors.systemRed,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                child: Text(
                  messageUnreadCount > 99 ? '99+' : '$messageUnreadCount',
                  style: const TextStyle(
                    color: CupertinoColors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      label: 'Inbox',
    );
  }

  BottomNavigationBarItem _buildIOSProfileTabItem() {
    final Map<String, dynamic>? userData =
        ref.watch(currentUserStreamProvider).valueOrNull;
    final String? resolvedAvatarUrl = resolveAvatarUrl(userData) ??
        normalizeAvatarPhotoUrl(
          firebase_auth.FirebaseAuth.instance.currentUser?.photoURL,
        );

    return BottomNavigationBarItem(
      icon: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: CupertinoColors.systemGrey5,
          border: Border.all(
            color: widget.currentIndex == 4
                ? CupertinoTheme.of(context).primaryColor
                : CupertinoColors.systemGrey4,
            width: widget.currentIndex == 4 ? 2 : 1,
          ),
          image: resolvedAvatarUrl != null && resolvedAvatarUrl.isNotEmpty
              ? DecorationImage(
                  image: NetworkImage(resolvedAvatarUrl),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: resolvedAvatarUrl == null || resolvedAvatarUrl.isEmpty
            ? const Icon(
                CupertinoIcons.person_fill,
                size: 18,
                color: CupertinoColors.systemGrey,
              )
            : null,
      ),
      label: 'Profile',
    );
  }

  Widget _buildAndroidNavigationBar() {
    return NavigationBar(
      selectedIndex: widget.currentIndex == 2 ? 0 : widget.currentIndex,
      onDestinationSelected: _handleTap,
      height: 80,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
      destinations: [
        _buildAndroidDestination(
          icon: Icons.home_outlined,
          selectedIcon: Icons.home,
          label: 'Home',
          index: 0,
        ),
        _buildAndroidDestination(
          icon: Icons.people_outline,
          selectedIcon: Icons.people,
          label: 'Network',
          index: 1,
        ),
        _buildAndroidCreateDestination(),
        _buildAndroidInboxDestination(),
        _buildAndroidProfileDestination(),
      ],
    );
  }

  NavigationDestination _buildAndroidDestination({
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required int index,
  }) {
    return NavigationDestination(
      icon: Icon(icon, size: 28),
      selectedIcon: Icon(selectedIcon, size: 28),
      label: label,
    );
  }

  Widget _buildAndroidCreateDestination() {
    return NavigationDestination(
      icon: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primary.withBlue(255),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          Icons.add,
          color: Theme.of(context).colorScheme.onPrimary,
          size: 32,
        ),
      ),
      label: 'Create',
    );
  }

  Widget _buildAndroidInboxDestination() {
    final messageUnreadCount = ref.watch(unreadMessagesProvider).maybeWhen(
          data: (int count) => count,
          orElse: () => 0,
        );

    return NavigationDestination(
      icon: Badge(
        isLabelVisible: messageUnreadCount > 0,
        label: Text(
          messageUnreadCount > 99 ? '99+' : '$messageUnreadCount',
        ),
        child: const Icon(Icons.mail_outline, size: 28),
      ),
      selectedIcon: Badge(
        isLabelVisible: messageUnreadCount > 0,
        label: Text(
          messageUnreadCount > 99 ? '99+' : '$messageUnreadCount',
        ),
        child: const Icon(Icons.mail, size: 28),
      ),
      label: 'Inbox',
    );
  }

  Widget _buildAndroidProfileDestination() {
    final Map<String, dynamic>? userData =
        ref.watch(currentUserStreamProvider).valueOrNull;
    final String? resolvedAvatarUrl = resolveAvatarUrl(userData) ??
        normalizeAvatarPhotoUrl(
          firebase_auth.FirebaseAuth.instance.currentUser?.photoURL,
        );

    final avatar = Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).colorScheme.surfaceVariant,
        border: Border.all(
          color: widget.currentIndex == 4
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          width: 2,
        ),
        image: resolvedAvatarUrl != null && resolvedAvatarUrl.isNotEmpty
            ? DecorationImage(
                image: NetworkImage(resolvedAvatarUrl),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: resolvedAvatarUrl == null || resolvedAvatarUrl.isEmpty
          ? Icon(
              Icons.person,
              size: 20,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            )
          : null,
    );

    return NavigationDestination(
      icon: avatar,
      selectedIcon: avatar,
      label: 'Profile',
    );
  }
}
