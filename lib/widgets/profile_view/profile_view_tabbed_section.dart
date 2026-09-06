import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../profile_video_feed_view.dart';
import '../streamer_card_sections.dart';

const Duration _profilePreviewTabSizeDuration = Duration(milliseconds: 150);
const Duration _profilePreviewTabSelectDuration = Duration(milliseconds: 140);

/// Segmented tabs plus animated tab content (videos / favorites / tagged).
class ProfileViewTabbedSection extends StatelessWidget {
  const ProfileViewTabbedSection({
    super.key,
    required this.selectedTabIndex,
    required this.onTabSelected,
    required this.contentFade,
    required this.contentSlide,
    required this.profileUserId,
    this.useInitialDataOnly = false,
  });

  final int selectedTabIndex;
  final ValueChanged<int> onTabSelected;
  final Animation<double> contentFade;
  final Animation<Offset> contentSlide;
  final String profileUserId;
  final bool useInitialDataOnly;

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
              duration: _profilePreviewTabSizeDuration,
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: IndexedStack(
                index: selectedTabIndex,
                children: useInitialDataOnly
                    ? const <Widget>[
                        _ProfilePreviewEmptyGrid(label: 'No posts yet'),
                        _ProfilePreviewEmptyGrid(label: 'No favorites yet'),
                        _ProfilePreviewEmptyGrid(label: 'No tagged posts yet'),
                      ]
                    : <Widget>[
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

class _ProfilePreviewEmptyGrid extends StatelessWidget {
  const _ProfilePreviewEmptyGrid({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 156,
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      decoration: StreamerCardBackStyle.cardDecoration,
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: StreamerCardBackStyle.muted,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
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
    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: StreamerCardBackStyle.cardDecoration,
      child: Row(
        children: <Widget>[
          _TabCell(
            label: 'Video',
            index: 0,
            selectedIndex: selectedIndex,
            onTap: onTabSelected,
          ),
          _TabCell(
            label: 'Favorites',
            index: 1,
            selectedIndex: selectedIndex,
            onTap: onTabSelected,
          ),
          _TabCell(
            label: 'Tagged',
            index: 2,
            selectedIndex: selectedIndex,
            onTap: onTabSelected,
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
  });

  final String label;
  final int index;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final bool isSelected = selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        child: AnimatedContainer(
          duration: _profilePreviewTabSelectDuration,
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
              duration: _profilePreviewTabSelectDuration,
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
