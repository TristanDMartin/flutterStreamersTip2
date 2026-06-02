import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../core/theme/support_shell_style.dart';
import '../utils/responsive_layout.dart';
import 'instant_response_button.dart';
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
            children: [
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
              const SizedBox(height: 24),
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
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Stack(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: shell.pageGradient,
            ),
          ),
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
      child: SafeArea(
        child: Stack(
          children: [
            _StreamerCardDetailsHeader(onFlip: onFlip),
            Padding(
              padding: const EdgeInsets.only(top: 80),
              child: CustomScrollView(
                physics: const ClampingScrollPhysics(),
                slivers: [
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  SliverToBoxAdapter(child: identity),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  SliverToBoxAdapter(child: tags),
                  if (creatorScoreBreakdown != null) ...[
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
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: shell.surfaceCard,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: shell.surfaceCardBorder,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            InstantResponseButton(
              onPressed: onDismiss,
              hapticType: HapticFeedbackType.lightImpact,
              child: Icon(
                Icons.arrow_back,
                color: shell.onChrome,
                size: 22,
              ),
            ),
            Text(
              'Streamer Profile',
              style: TextStyle(
                color: shell.onChrome.withValues(alpha: 0.92),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            Row(
              children: [
                InstantResponseButton(
                  onPressed: onFlip,
                  hapticType: HapticFeedbackType.lightImpact,
                  child: Icon(
                    Icons.flip,
                    color: shell.onChrome,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                InstantResponseButton(
                  onPressed: onMore,
                  hapticType: HapticFeedbackType.lightImpact,
                  child: Icon(
                    Icons.more_horiz,
                    color: shell.onChrome,
                    size: 22,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final AppResponsive responsive = context.responsive;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: shell.surfaceCard,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: shell.surfaceCardBorder,
            width: 1,
          ),
        ),
        child: UserStatsRow(
          userId: userId,
          postsCountOverride: postsCountOverride,
          valueTextStyle: TextStyle(
            color: shell.onChrome,
            fontSize: responsive.font(21),
            fontWeight: FontWeight.w900,
            height: 1.0,
          ),
          labelTextStyle: TextStyle(
            color: shell.muted,
            fontSize: responsive.font(12.5),
            fontWeight: FontWeight.w600,
            height: 1.0,
          ),
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
        builder: (context, constraints) {
          final double gap = constraints.maxWidth < 340 ? 10 : 14;
          return Row(
            children: [
              Expanded(
                child: _StreamerCardActionButton(
                  text: followButtonText,
                  onPressed: followButtonOnPressed,
                  isLoading: followButtonLoading,
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
  });

  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool enabled = onPressed != null;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          gradient: enabled
              ? const LinearGradient(
                  colors: AppColors.supportAccentGradient,
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          color:
              enabled ? null : shell.chipUnselectedBg.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: enabled
                ? scheme.onPrimary.withValues(alpha: 0.35)
                : shell.surfaceCardBorder,
            width: 1,
          ),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppColors.supportAccent.withValues(alpha: 0.16),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      scheme.onPrimary,
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
                        color: enabled ? scheme.onPrimary : shell.muted,
                        fontSize: 16,
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
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: shell.surfaceCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: shell.surfaceCardBorder,
          width: 1,
        ),
      ),
      child: Row(
        children: tabs
            .map(
              (tab) => _StreamerCardTab(
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
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: AppColors.supportAccentGradient,
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
            color: isSelected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.onPrimary.withValues(
                        alpha: 0.22,
                      )
                  : Colors.transparent,
              width: 1,
            ),
          ),
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimary
                    : shell.chipUnselectedFg,
                fontSize: 16,
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
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: shell.surfaceCard,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: shell.surfaceCardBorder,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Text(
              'Streamer Details',
              style: TextStyle(
                color: shell.onChrome.withValues(alpha: 0.92),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            InstantResponseButton(
              onPressed: onFlip,
              hapticType: HapticFeedbackType.lightImpact,
              child: Icon(
                Icons.flip,
                color: shell.onChrome,
                size: 22,
              ),
            ),
          ],
        ),
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
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: shell.surfaceCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: shell.surfaceCardBorder,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: shell.onChrome,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Icon(
                isExpanded
                    ? Icons.keyboard_arrow_down
                    : Icons.keyboard_arrow_right,
                color: shell.muted,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
