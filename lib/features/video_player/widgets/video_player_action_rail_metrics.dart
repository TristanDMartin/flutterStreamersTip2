import 'package:flutter/material.dart';

import '../../../utils/responsive_layout.dart';

class VideoPlayerActionRailMetrics {
  const VideoPlayerActionRailMetrics({
    required this.leftInset,
    required this.rightInset,
    required this.metadataRightInset,
    required this.bottomNavHeight,
    required this.bottomNavMargin,
    required this.metadataPaddingAboveNav,
    required this.railPaddingAboveNav,
    required this.metadataPadding,
    required this.buttonSize,
    required this.iconSize,
    required this.shareIconSize,
    required this.labelFontSize,
    required this.shareLabelFontSize,
    required this.likeWidth,
    required this.likeHeight,
    required this.likeIconSize,
    required this.likeLabelFontSize,
    required this.labelGap,
    required this.itemGap,
    required this.avatarGap,
    required this.avatarSize,
    required this.sparkleSize,
    required this.progressSize,
    required this.progressStrokeWidth,
  });

  final double leftInset;
  final double rightInset;
  final double metadataRightInset;
  final double bottomNavHeight;
  final double bottomNavMargin;
  final double metadataPaddingAboveNav;
  final double railPaddingAboveNav;
  final double metadataPadding;
  final double buttonSize;
  final double iconSize;
  final double shareIconSize;
  final double labelFontSize;
  final double shareLabelFontSize;
  final double likeWidth;
  final double likeHeight;
  final double likeIconSize;
  final double likeLabelFontSize;
  final double labelGap;
  final double itemGap;
  final double avatarGap;
  final double avatarSize;
  final double sparkleSize;
  final double progressSize;
  final double progressStrokeWidth;

  static VideoPlayerActionRailMetrics of(BuildContext context) {
    final AppResponsive responsive = context.responsive;
    final double width = MediaQuery.sizeOf(context).width;
    final bool compact = responsive.isCompactPhone || width < 360;
    final bool small = responsive.isSmallPhone || width < 390;
    final double rightInset = compact ? 10.0 : (small ? 12.0 : 14.0);
    final double buttonSize = compact ? 40.0 : 44.0;
    final double likeWidth = compact ? 44.0 : 48.0;

    return VideoPlayerActionRailMetrics(
      leftInset: responsive.spacing(compact ? 20 : 24),
      rightInset: rightInset,
      metadataRightInset: rightInset + likeWidth + (compact ? 8.0 : 12.0),
      bottomNavHeight: 76.0,
      bottomNavMargin: 12.0,
      metadataPaddingAboveNav: 24.0,
      railPaddingAboveNav: 24.0,
      metadataPadding: 0,
      buttonSize: buttonSize,
      iconSize: compact ? 28.0 : 30.0,
      shareIconSize: compact ? 26.0 : 28.0,
      labelFontSize: compact ? 10.0 : 11.0,
      shareLabelFontSize: compact ? 9.0 : 10.0,
      likeWidth: likeWidth,
      likeHeight: compact ? 58.0 : 62.0,
      likeIconSize: compact ? 30.0 : (small ? 32.0 : 34.0),
      likeLabelFontSize: compact ? 10.5 : 11.5,
      labelGap: 2.0,
      itemGap: compact ? 2.0 : 4.0,
      avatarGap: compact ? 6.0 : 8.0,
      avatarSize: compact ? 44.0 : 48.0,
      sparkleSize: compact ? 66.0 : (small ? 72.0 : 78.0),
      progressSize: compact ? 16.0 : 18.0,
      progressStrokeWidth: compact ? 2.0 : 2.2,
    );
  }
}
