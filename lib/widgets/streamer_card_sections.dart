import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../utils/responsive_layout.dart';
import 'user_stats_row.dart';

class StreamerCardTabItem {
  const StreamerCardTabItem({
    required this.label,
    required this.index,
  });

  final String label;
  final int index;
}

class StreamerCardFrontSection extends StatelessWidget {
  const StreamerCardFrontSection({
    super.key,
    required this.onDismiss,
    required this.onFlip,
    required this.onMore,
    required this.profileSection,
    required this.userId,
    this.postsCountOverride,
    required this.followButtonText,
    required this.followButtonOnPressed,
    required this.followButtonLoading,
    required this.messageButtonOnPressed,
    required this.shareButtonOnPressed,
    required this.tabs,
    required this.selectedTabIndex,
    required this.onTabSelected,
    required this.content,
  });

  final VoidCallback? onDismiss;
  final VoidCallback onFlip;
  final VoidCallback onMore;
  final Widget profileSection;
  final String userId;
  final int? postsCountOverride;
  final String followButtonText;
  final VoidCallback? followButtonOnPressed;
  final bool followButtonLoading;
  final VoidCallback? messageButtonOnPressed;
  final VoidCallback? shareButtonOnPressed;
  final List<StreamerCardTabItem> tabs;
  final int selectedTabIndex;
  final ValueChanged<int> onTabSelected;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    return _StreamerCardSurface(
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            children: <Widget>[
              _StreamerCardTopBar(
                onDismiss: onDismiss,
                onFlip: onFlip,
                onMore: onMore,
              ),
              const SizedBox(height: 8),
              profileSection,
              _StreamerCardStatsSection(
                userId: userId,
                postsCountOverride: postsCountOverride,
              ),
              _StreamerCardActionRow(
                followButtonText: followButtonText,
                followButtonOnPressed: followButtonOnPressed,
                followButtonLoading: followButtonLoading,
                messageButtonOnPressed: messageButtonOnPressed,
                shareButtonOnPressed: shareButtonOnPressed,
              ),
              const SizedBox(height: 20),
              _StreamerCardTabBar(
                tabs: tabs,
                selectedTabIndex: selectedTabIndex,
                onTabSelected: onTabSelected,
              ),
              content,
            ],
          ),
        ),
      ),
    );
  }
}

class _StreamerCardSurface extends StatelessWidget {
  const _StreamerCardSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        const ColoredBox(
          color: AppColors.profileViewBackground,
          child: SizedBox.expand(),
        ),
        child,
      ],
    );
  }
}

class StreamerCardDetailsSection extends StatelessWidget {
  const StreamerCardDetailsSection({
    super.key,
    required this.onFlip,
    required this.identity,
    required this.tags,
    this.creatorScoreBreakdown,
    required this.showBio,
    required this.onToggleBio,
    required this.bioBody,
    required this.showPlatforms,
    required this.onTogglePlatforms,
    required this.platformsBody,
    required this.showCalendar,
    required this.onToggleCalendar,
    required this.calendarBody,
  });

  final VoidCallback onFlip;
  final Widget identity;
  final Widget tags;
  final Widget? creatorScoreBreakdown;
  final bool showBio;
  final VoidCallback onToggleBio;
  final Widget bioBody;
  final bool showPlatforms;
  final VoidCallback onTogglePlatforms;
  final Widget platformsBody;
  final bool showCalendar;
  final VoidCallback onToggleCalendar;
  final Widget calendarBody;

  @override
  Widget build(BuildContext context) {
    return _StreamerCardSurface(
      child: SafeArea(
        child: Stack(
          children: <Widget>[
            _StreamerCardDetailsHeader(onFlip: onFlip),
            Padding(
              padding: const EdgeInsets.only(top: 64),
              child: CustomScrollView(
                physics: const ClampingScrollPhysics(),
                slivers: <Widget>[
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  SliverToBoxAdapter(child: identity),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  SliverToBoxAdapter(child: tags),
                  if (creatorScoreBreakdown != null) ...<Widget>[
                    const SliverToBoxAdapter(child: SizedBox(height: 20)),
                    SliverToBoxAdapter(child: creatorScoreBreakdown),
                  ],
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
                  SliverToBoxAdapter(
                    child: _StreamerCardSectionHeader(
                      title: 'Bio',
                      isExpanded: showBio,
                      onTap: onToggleBio,
                    ),
                  ),
                  if (showBio) SliverToBoxAdapter(child: bioBody),
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
                  SliverToBoxAdapter(
                    child: _StreamerCardSectionHeader(
                      title: 'Platforms',
                      isExpanded: showPlatforms,
                      onTap: onTogglePlatforms,
                    ),
                  ),
                  if (showPlatforms) SliverToBoxAdapter(child: platformsBody),
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
                  SliverToBoxAdapter(
                    child: _StreamerCardSectionHeader(
                      title: 'Calendar',
                      isExpanded: showCalendar,
                      onTap: onToggleCalendar,
                    ),
                  ),
                  if (showCalendar) SliverToBoxAdapter(child: calendarBody),
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StreamerCardTopBar extends StatelessWidget {
  const _StreamerCardTopBar({
    required this.onDismiss,
    required this.onFlip,
    required this.onMore,
  });

  final VoidCallback? onDismiss;
  final VoidCallback onFlip;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    // Match ProfileViewFrontShell SliverAppBar actions (flip, then more).
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      leading: IconButton(
        onPressed: onDismiss,
        icon: const Icon(
          Icons.arrow_back,
          color: Colors.white,
          size: 24,
        ),
        tooltip: 'Back',
      ),
      title: const Text(
        'Streamer Profile',
        style: TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w800,
        ),
      ),
      centerTitle: true,
      actions: <Widget>[
        IconButton(
          onPressed: onFlip,
          icon: const Icon(
            Icons.flip,
            color: Colors.white,
            size: 24,
          ),
          tooltip: 'Flip',
        ),
        IconButton(
          onPressed: onMore,
          icon: Icon(
            Icons.more_horiz,
            color: Colors.white.withValues(alpha: 0.72),
            size: 24,
          ),
          tooltip: 'More',
        ),
      ],
    );
  }
}

class _StreamerCardStatsSection extends StatelessWidget {
  const _StreamerCardStatsSection({
    required this.userId,
    this.postsCountOverride,
  });

  final String userId;
  final int? postsCountOverride;

  @override
  Widget build(BuildContext context) {
    final AppResponsive responsive = context.responsive;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: UserStatsRow(
        userId: userId,
        postsCountOverride: postsCountOverride,
        valueTextStyle: TextStyle(
          color: Colors.white,
          fontSize: responsive.font(20),
          fontWeight: FontWeight.w800,
          height: 1.0,
        ),
        labelTextStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.55),
          fontSize: responsive.font(12),
          fontWeight: FontWeight.w600,
          height: 1.0,
        ),
      ),
    );
  }
}

class _StreamerCardActionRow extends StatelessWidget {
  const _StreamerCardActionRow({
    required this.followButtonText,
    required this.followButtonOnPressed,
    required this.followButtonLoading,
    required this.messageButtonOnPressed,
    required this.shareButtonOnPressed,
  });

  final String followButtonText;
  final VoidCallback? followButtonOnPressed;
  final bool followButtonLoading;
  final VoidCallback? messageButtonOnPressed;
  final VoidCallback? shareButtonOnPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double gap = constraints.maxWidth < 340 ? 10 : 12;
          return Row(
            children: <Widget>[
              Expanded(
                child: _StreamerCardActionButton(
                  text: followButtonText,
                  onPressed: followButtonOnPressed,
                  isLoading: followButtonLoading,
                  isPrimary: true,
                ),
              ),
              SizedBox(width: gap),
              Expanded(
                child: _StreamerCardActionButton(
                  text: 'Message',
                  onPressed: messageButtonOnPressed,
                ),
              ),
              SizedBox(width: gap),
              Expanded(
                child: _StreamerCardActionButton(
                  text: 'Share',
                  onPressed: shareButtonOnPressed,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StreamerCardActionButton extends StatelessWidget {
  const _StreamerCardActionButton({
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.isPrimary = false,
  });

  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          gradient: enabled && isPrimary
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
          color: enabled && isPrimary
              ? null
              : Colors.white.withValues(alpha: enabled ? 0.08 : 0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withValues(alpha: enabled ? 0.14 : 0.08),
          ),
          boxShadow: enabled && isPrimary
              ? <BoxShadow>[
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.28),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: enabled
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.42),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _StreamerCardTabBar extends StatelessWidget {
  const _StreamerCardTabBar({
    required this.tabs,
    required this.selectedTabIndex,
    required this.onTabSelected,
  });

  final List<StreamerCardTabItem> tabs;
  final int selectedTabIndex;
  final ValueChanged<int> onTabSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
        ),
      ),
      child: Row(
        children: tabs
            .map(
              (StreamerCardTabItem tab) => _StreamerCardTab(
                label: tab.label,
                isSelected: selectedTabIndex == tab.index,
                onTap: () => onTabSelected(tab.index),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _StreamerCardTab extends StatelessWidget {
  const _StreamerCardTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.white.withValues(alpha: 0.16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: isSelected
                ? Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  )
                : null,
          ),
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.55),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
              child: Text(label),
            ),
          ),
        ),
      ),
    );
  }
}

class _StreamerCardDetailsHeader extends StatelessWidget {
  const _StreamerCardDetailsHeader({required this.onFlip});

  final VoidCallback onFlip;

  @override
  Widget build(BuildContext context) {
    // Match ProfileBackView header: flip left, title center, 48px balance.
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: onFlip,
            icon: const Icon(
              Icons.flip,
              color: Colors.white,
              size: 22,
            ),
            tooltip: 'Flip',
          ),
          const Expanded(
            child: Text(
              'Streamer Details',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _StreamerCardSectionHeader extends StatelessWidget {
  const _StreamerCardSectionHeader({
    required this.title,
    required this.isExpanded,
    required this.onTap,
  });

  final String title;
  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.10),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Icon(
                isExpanded
                    ? Icons.keyboard_arrow_down
                    : Icons.keyboard_arrow_right,
                color: Colors.white.withValues(alpha: 0.55),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
