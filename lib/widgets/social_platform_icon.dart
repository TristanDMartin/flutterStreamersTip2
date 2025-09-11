import 'package:flutter/material.dart';
import '../constants/social_icons.dart';

/// A widget that displays social platform icons with proper asset management
class SocialPlatformIcon extends StatelessWidget {
  final PlatformType platform;
  final double size;
  final Color? backgroundColor;
  final Color? iconColor;
  final VoidCallback? onTap;
  final bool showBackground;
  final BorderRadius? borderRadius;
  final BoxBorder? border;
  final EdgeInsets? padding;

  const SocialPlatformIcon({
    super.key,
    required this.platform,
    this.size = 32.0,
    this.backgroundColor,
    this.iconColor,
    this.onTap,
    this.showBackground = true,
    this.borderRadius,
    this.border,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final iconWidget = _buildIconWidget();
    
    if (onTap == null) {
      return iconWidget;
    }

    return GestureDetector(
      onTap: onTap,
      child: iconWidget,
    );
  }

  Widget _buildIconWidget() {
    if (showBackground) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor ?? platform.brandColor.withValues(alpha:0.1),
          borderRadius: borderRadius ?? BorderRadius.circular(size * 0.2),
          border: border ?? Border.all(
            color: platform.brandColor.withValues(alpha:0.3),
            width: 1.0,
          ),
        ),
        padding: padding ?? EdgeInsets.all(size * 0.15),
        child: _buildIcon(),
      );
    } else {
      return SizedBox(
        width: size,
        height: size,
        child: _buildIcon(),
      );
    }
  }

  Widget _buildIcon() {
    return Image.asset(
      platform.iconPath,
      width: size * 0.7,
      height: size * 0.7,
      color: iconColor,
      errorBuilder: (context, error, stackTrace) {
        // Fallback to a colored circle with platform initial
        return Container(
          width: size * 0.7,
          height: size * 0.7,
          decoration: BoxDecoration(
            color: platform.brandColor,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              platform.displayName[0].toUpperCase(),
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.3,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A widget that displays multiple social platform icons in a row
class SocialPlatformIconsRow extends StatelessWidget {
  final List<PlatformType> platforms;
  final double iconSize;
  final double spacing;
  final bool showBackground;
  final VoidCallback? Function(PlatformType)? onPlatformTap;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;

  const SocialPlatformIconsRow({
    super.key,
    required this.platforms,
    this.iconSize = 32.0,
    this.spacing = 8.0,
    this.showBackground = true,
    this.onPlatformTap,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      children: platforms.asMap().entries.map((entry) {
        final index = entry.key;
        final platform = entry.value;
        
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SocialPlatformIcon(
              platform: platform,
              size: iconSize,
              showBackground: showBackground,
              onTap: onPlatformTap?.call(platform),
            ),
            if (index < platforms.length - 1) 
              SizedBox(width: spacing),
          ],
        );
      }).toList(),
    );
  }
}

/// A widget that displays social platform icons in a grid layout
class SocialPlatformIconsGrid extends StatelessWidget {
  final List<PlatformType> platforms;
  final double iconSize;
  final double spacing;
  final int crossAxisCount;
  final bool showBackground;
  final VoidCallback? Function(PlatformType)? onPlatformTap;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;

  const SocialPlatformIconsGrid({
    super.key,
    required this.platforms,
    this.iconSize = 32.0,
    this.spacing = 8.0,
    this.crossAxisCount = 4,
    this.showBackground = true,
    this.onPlatformTap,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
        childAspectRatio: 1.0,
      ),
      itemCount: platforms.length,
      itemBuilder: (context, index) {
        final platform = platforms[index];
        return SocialPlatformIcon(
          platform: platform,
          size: iconSize,
          showBackground: showBackground,
          onTap: onPlatformTap?.call(platform),
        );
      },
    );
  }
}

/// A widget that displays a social platform icon with a label
class SocialPlatformIconWithLabel extends StatelessWidget {
  final PlatformType platform;
  final double iconSize;
  final TextStyle? labelStyle;
  final bool showBackground;
  final VoidCallback? onTap;
  final MainAxisAlignment mainAxisAlignment;
  final double spacing;

  const SocialPlatformIconWithLabel({
    super.key,
    required this.platform,
    this.iconSize = 32.0,
    this.labelStyle,
    this.showBackground = true,
    this.onTap,
    this.mainAxisAlignment = MainAxisAlignment.center,
    this.spacing = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: mainAxisAlignment,
        children: [
          SocialPlatformIcon(
            platform: platform,
            size: iconSize,
            showBackground: showBackground,
          ),
          SizedBox(height: spacing),
          Text(
            platform.displayName,
            style: labelStyle ?? const TextStyle(
              fontSize: 12.0,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// A widget that displays social platform icons as chips
class SocialPlatformChip extends StatelessWidget {
  final PlatformType platform;
  final double height;
  final bool showIcon;
  final bool showLabel;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final Color? backgroundColor;
  final Color? textColor;
  final BorderRadius? borderRadius;

  const SocialPlatformChip({
    super.key,
    required this.platform,
    this.height = 32.0,
    this.showIcon = true,
    this.showLabel = true,
    this.onTap,
    this.onDelete,
    this.backgroundColor,
    this.textColor,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        padding: EdgeInsets.symmetric(
          horizontal: height * 0.4,
          vertical: height * 0.2,
        ),
        decoration: BoxDecoration(
          color: backgroundColor ?? platform.brandColor.withValues(alpha:0.1),
          borderRadius: borderRadius ?? BorderRadius.circular(height * 0.5),
          border: Border.all(
            color: platform.brandColor.withValues(alpha:0.3),
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showIcon) ...[
              SocialPlatformIcon(
                platform: platform,
                size: height * 0.6,
                showBackground: false,
              ),
              SizedBox(width: height * 0.2),
            ],
            if (showLabel)
              Text(
                platform.displayName,
                style: TextStyle(
                  color: textColor ?? platform.brandColor,
                  fontSize: height * 0.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
            if (onDelete != null) ...[
              SizedBox(width: height * 0.2),
              GestureDetector(
                onTap: onDelete,
                child: Icon(
                  Icons.close,
                  size: height * 0.4,
                  color: textColor ?? platform.brandColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
