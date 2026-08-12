import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import 'user_stats_row.dart';

/// Visual tokens for the streamer card back (aligned with Creator Score).
abstract final class StreamerCardBackStyle {
  static const Color background = Color(0xFF0A0A0F);
  static const Color card = Color(0xFF14141C);
  static const Color muted = Color(0xFF8A8A95);
  static const Color softText = Color(0xFFE0E0E5);
  static const Color lavender = Color(0xFFC4B5FD);
  static const Color accent = Color(0xFF8B5CF6);
  static const Color avatarFill = Color(0xFF2A2A35);
  static const Color ringBlue = Color(0xFF4F7CFF);
  static const Color ringPurple = Color(0xFFC060E0);
  static const Set<String> roleHashtagKeys = <String>{
    'owner',
    'founder',
    'admin',
    'moderator',
    'staff',
    'official',
  };

  static BorderRadius get cardRadius => BorderRadius.circular(16);

  static BoxDecoration get cardDecoration => BoxDecoration(
        color: card,
        borderRadius: cardRadius,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      );
}

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
      backgroundColor: StreamerCardBackStyle.background,
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
              const SizedBox(height: 4),
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
              const SizedBox(height: 16),
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
  const _StreamerCardSurface({
    required this.child,
    this.backgroundColor = AppColors.profileViewBackground,
  });

  final Widget child;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        ColoredBox(
          color: backgroundColor,
          child: const SizedBox.expand(),
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
      backgroundColor: StreamerCardBackStyle.background,
      child: SafeArea(
        child: Stack(
          children: <Widget>[
            _StreamerCardDetailsHeader(onFlip: onFlip),
            Padding(
              padding: const EdgeInsets.only(top: 64),
              child: CustomScrollView(
                physics: const ClampingScrollPhysics(),
                slivers: <Widget>[
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  SliverToBoxAdapter(child: identity),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  SliverToBoxAdapter(child: tags),
                  if (creatorScoreBreakdown != null) ...<Widget>[
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),
                    SliverToBoxAdapter(child: creatorScoreBreakdown),
                  ],
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  SliverToBoxAdapter(
                    child: _StreamerCardSectionHeader(
                      title: 'Bio',
                      isExpanded: showBio,
                      onTap: onToggleBio,
                    ),
                  ),
                  if (showBio)
                    SliverToBoxAdapter(
                      child: _StreamerCardBackCard(child: bioBody),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
                  SliverToBoxAdapter(
                    child: _StreamerCardSectionHeader(
                      title: 'Platforms',
                      isExpanded: showPlatforms,
                      onTap: onTogglePlatforms,
                    ),
                  ),
                  if (showPlatforms)
                    SliverToBoxAdapter(
                      child: _StreamerCardBackCard(child: platformsBody),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
                  SliverToBoxAdapter(
                    child: _StreamerCardSectionHeader(
                      title: 'Calendar',
                      isExpanded: showCalendar,
                      onTap: onToggleCalendar,
                    ),
                  ),
                  if (showCalendar)
                    SliverToBoxAdapter(
                      child: _StreamerCardBackCard(child: calendarBody),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 28)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StreamerCardBackCard extends StatelessWidget {
  const _StreamerCardBackCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: DecoratedBox(
        decoration: StreamerCardBackStyle.cardDecoration,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: child,
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
          size: 22,
        ),
        tooltip: 'Back',
      ),
      actions: <Widget>[
        IconButton(
          onPressed: onFlip,
          icon: const Icon(
            Icons.flip,
            color: Colors.white,
            size: 22,
          ),
          tooltip: 'Flip',
        ),
        IconButton(
          onPressed: onMore,
          icon: const Icon(
            Icons.more_horiz,
            color: StreamerCardBackStyle.muted,
            size: 22,
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: UserStatsRow(
        userId: userId,
        postsCountOverride: postsCountOverride,
        spacing: 28,
        valueTextStyle: const TextStyle(
          color: Colors.white,
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
        height: 44,
        decoration: BoxDecoration(
          color: enabled && isPrimary
              ? StreamerCardBackStyle.accent.withValues(alpha: 0.22)
              : StreamerCardBackStyle.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: enabled && isPrimary
                ? StreamerCardBackStyle.accent.withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: enabled ? 0.08 : 0.05),
          ),
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      StreamerCardBackStyle.lavender,
                    ),
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
                            ? (isPrimary
                                ? StreamerCardBackStyle.lavender
                                : StreamerCardBackStyle.softText)
                            : StreamerCardBackStyle.muted,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
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
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: StreamerCardBackStyle.cardDecoration,
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
                ? StreamerCardBackStyle.accent.withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(
                    color: StreamerCardBackStyle.accent.withValues(alpha: 0.28),
                  )
                : null,
          ),
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: isSelected
                    ? StreamerCardBackStyle.lavender
                    : StreamerCardBackStyle.muted,
                fontSize: 13,
                fontWeight: FontWeight.w500,
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
          const Spacer(),
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: StreamerCardBackStyle.softText,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                isExpanded
                    ? Icons.keyboard_arrow_down
                    : Icons.keyboard_arrow_right,
                color: StreamerCardBackStyle.muted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
