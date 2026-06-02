import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/support_shell_style.dart';
import '../profile_video_feed_view.dart';

/// Segmented tabs plus animated tab content (videos / favorites / tagged).
class ProfileViewTabbedSection extends StatelessWidget {
  const ProfileViewTabbedSection({
    super.key,
    required this.selectedTabIndex,
    required this.onTabSelected,
    required this.contentFade,
    required this.contentSlide,
    required this.profileUserId,
  });

  final int selectedTabIndex;
  final ValueChanged<int> onTabSelected;
  final Animation<double> contentFade;
  final Animation<Offset> contentSlide;
  final String profileUserId;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _ProfileSegmentBar(
          selectedIndex: selectedTabIndex,
          onTabSelected: onTabSelected,
        ),
        FadeTransition(
          opacity: contentFade,
          child: SlideTransition(
            position: contentSlide,
            child: AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: IndexedStack(
                index: selectedTabIndex,
                children: <Widget>[
                  ProfileVideoFeedView(
                    feedType: ProfileVideoFeedType.videos,
                    userId: profileUserId,
                    onVideoTap: () => HapticFeedback.lightImpact(),
                  ),
                  ProfileVideoFeedView(
                    feedType: ProfileVideoFeedType.favorites,
                    userId: profileUserId,
                    onVideoTap: () => HapticFeedback.lightImpact(),
                  ),
                  ProfileVideoFeedView(
                    feedType: ProfileVideoFeedType.tagged,
                    userId: profileUserId,
                    onVideoTap: () => HapticFeedback.lightImpact(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileSegmentBar extends StatelessWidget {
  const _ProfileSegmentBar({
    required this.selectedIndex,
    required this.onTabSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Container(
      height: 56,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: shell.chipUnselectedBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: shell.chipUnselectedBorder,
          width: 1,
        ),
      ),
      child: Row(
        children: <Widget>[
          _TabCell(
            label: 'Video',
            index: 0,
            selectedIndex: selectedIndex,
            onTap: onTabSelected,
            shell: shell,
          ),
          _TabCell(
            label: 'Favorites',
            index: 1,
            selectedIndex: selectedIndex,
            onTap: onTabSelected,
            shell: shell,
          ),
          _TabCell(
            label: 'Tagged',
            index: 2,
            selectedIndex: selectedIndex,
            onTap: onTabSelected,
            shell: shell,
          ),
        ],
      ),
    );
  }
}

class _TabCell extends StatelessWidget {
  const _TabCell({
    required this.label,
    required this.index,
    required this.selectedIndex,
    required this.onTap,
    required this.shell,
  });

  final String label;
  final int index;
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final StSupportShellStyle shell;

  @override
  Widget build(BuildContext context) {
    final bool isSelected = selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isSelected ? shell.chipSelectedBg : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: isSelected
                ? Border.all(
                    color: shell.chipSelectedBorder,
                    width: 1,
                  )
                : null,
          ),
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color:
                    isSelected ? shell.chipSelectedFg : shell.chipUnselectedFg,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              child: Text(label),
            ),
          ),
        ),
      ),
    );
  }
}
