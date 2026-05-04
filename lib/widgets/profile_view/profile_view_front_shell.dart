import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../views/menu_view.dart';
import 'profile_view_header_section.dart';
import 'profile_view_tabbed_section.dart';

/// Single scroll surface: [SliverAppBar] + header + tabbed feeds (no nested
/// [Scaffold]; the parent [ProfileViewOptimized] owns the scaffold).
class ProfileViewFrontShell extends StatelessWidget {
  const ProfileViewFrontShell({
    super.key,
    required this.userData,
    required this.profileUserId,
    required this.isCurrentUser,
    required this.selectedTabIndex,
    required this.onTabSelected,
    required this.contentFade,
    required this.contentSlide,
    required this.onBack,
    required this.onFlip,
    required this.onStreamerCard,
  });

  final Map<String, dynamic> userData;
  final String profileUserId;
  final bool isCurrentUser;
  final int selectedTabIndex;
  final ValueChanged<int> onTabSelected;
  final Animation<double> contentFade;
  final Animation<Offset> contentSlide;
  final VoidCallback onBack;
  final VoidCallback onFlip;
  final VoidCallback onStreamerCard;

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.paddingOf(context).bottom;
    final Color onSurface = Theme.of(context).colorScheme.onSurface;
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: <Widget>[
          SliverAppBar(
            pinned: true,
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: onSurface),
              onPressed: onBack,
            ),
            actions: <Widget>[
              IconButton(
                icon: Icon(
                  Icons.flip,
                  color: onSurface,
                  size: 24,
                ),
                onPressed: onFlip,
              ),
              IconButton(
                icon: Icon(
                  Icons.card_membership,
                  color: onSurface,
                  size: 24,
                ),
                onPressed: onStreamerCard,
              ),
              IconButton(
                icon: Icon(
                  Icons.more_horiz,
                  color: onSurface.withValues(alpha: 0.7),
                  size: 24,
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) => const MenuView(),
                    ),
                  );
                },
              ),
            ],
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          SliverToBoxAdapter(
            child: ProfileViewHeaderSection(
              userData: userData,
              profileUserId: profileUserId,
              isCurrentUser: isCurrentUser,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          SliverToBoxAdapter(
            child: ProfileViewTabbedSection(
              selectedTabIndex: selectedTabIndex,
              onTabSelected: onTabSelected,
              contentFade: contentFade,
              contentSlide: contentSlide,
              profileUserId: profileUserId,
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: 24 + bottomInset)),
        ],
      ),
    );
  }
}
