import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../routing/app_routes.dart';
import '../../views/menu_view.dart';
import '../streamer_card_sections.dart';
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
    required this.showStreamerCardButton,
    this.useInitialDataOnly = false,
    this.showMenuButton = true,
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
  final bool showStreamerCardButton;
  final bool useInitialDataOnly;
  final bool showMenuButton;

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.paddingOf(context).bottom;
    return ColoredBox(
      color: StreamerCardBackStyle.background,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: <Widget>[
          SliverAppBar(
            pinned: true,
            automaticallyImplyLeading: false,
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: StreamerCardBackStyle.background,
            surfaceTintColor: Colors.transparent,
            actions: <Widget>[
              IconButton(
                icon: const Icon(
                  Icons.flip,
                  color: Colors.white,
                  size: 22,
                ),
                onPressed: onFlip,
              ),
              if (showStreamerCardButton)
                IconButton(
                  icon: const Icon(
                    Icons.card_membership,
                    color: StreamerCardBackStyle.muted,
                    size: 22,
                  ),
                  onPressed: onStreamerCard,
                ),
              if (showMenuButton)
                IconButton(
                  icon: const Icon(
                    Icons.more_horiz,
                    color: StreamerCardBackStyle.muted,
                    size: 22,
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        settings: const RouteSettings(name: AppRoutes.menu),
                        builder: (BuildContext context) => const MenuView(),
                      ),
                    );
                  },
                ),
            ],
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          SliverToBoxAdapter(
            child: ProfileViewHeaderSection(
              userData: userData,
              profileUserId: profileUserId,
              isCurrentUser: isCurrentUser,
              useInitialDataOnly: useInitialDataOnly,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
          SliverToBoxAdapter(
            child: ProfileViewTabbedSection(
              selectedTabIndex: selectedTabIndex,
              onTabSelected: onTabSelected,
              contentFade: contentFade,
              contentSlide: contentSlide,
              profileUserId: profileUserId,
              useInitialDataOnly: useInitialDataOnly,
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: 24 + bottomInset)),
        ],
      ),
    );
  }
}
