import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'apple_material_design_system.dart';

/// Adaptive button that uses CupertinoButton on iOS and Material buttons on Android
class AdaptiveButton extends StatelessWidget {
  const AdaptiveButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.type = AdaptiveButtonType.filled,
    this.color,
    this.textColor,
    this.minSize,
    this.padding,
    this.borderRadius,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final AdaptiveButtonType type;
  final Color? color;
  final Color? textColor;
  final double? minSize;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    if (AppleMaterialDesign.isIOS) {
      return _buildIOSButton(context);
    }
    return _buildAndroidButton(context);
  }

  Widget _buildIOSButton(BuildContext context) {
    final defaultPadding = padding ??
        const EdgeInsets.symmetric(
          horizontal: AppleMaterialDesign.paddingMedium,
          vertical: AppleMaterialDesign.paddingSmall,
        );

    switch (type) {
      case AdaptiveButtonType.filled:
        return CupertinoButton.filled(
          onPressed: onPressed,
          padding: defaultPadding,
          borderRadius: BorderRadius.circular(
            borderRadius ?? AppleMaterialDesign.buttonRadiusIOS,
          ),
          minSize: minSize ?? AppleMaterialDesign.touchTargetIOS,
          child: child,
        );

      case AdaptiveButtonType.tinted:
        final theme = CupertinoTheme.of(context);
        return CupertinoButton(
          onPressed: onPressed,
          padding: defaultPadding,
          borderRadius: BorderRadius.circular(
            borderRadius ?? AppleMaterialDesign.buttonRadiusIOS,
          ),
          minSize: minSize ?? AppleMaterialDesign.touchTargetIOS,
          color: color ??
              theme.primaryColor.withOpacity(0.15),
          child: DefaultTextStyle(
            style: TextStyle(
              color: textColor ?? theme.primaryColor,
              fontWeight: AppleMaterialDesign.weightSemibold,
            ),
            child: child,
          ),
        );

      case AdaptiveButtonType.gray:
        return CupertinoButton(
          onPressed: onPressed,
          padding: defaultPadding,
          borderRadius: BorderRadius.circular(
            borderRadius ?? AppleMaterialDesign.buttonRadiusIOS,
          ),
          minSize: minSize ?? AppleMaterialDesign.touchTargetIOS,
          color: CupertinoColors.systemGrey5,
          child: DefaultTextStyle(
            style: const TextStyle(
              color: CupertinoColors.label,
              fontWeight: AppleMaterialDesign.weightSemibold,
            ),
            child: child,
          ),
        );

      case AdaptiveButtonType.text:
        return CupertinoButton(
          onPressed: onPressed,
          padding: defaultPadding,
          minSize: minSize ?? AppleMaterialDesign.touchTargetIOS,
          child: DefaultTextStyle(
            style: TextStyle(
              color: textColor ?? CupertinoTheme.of(context).primaryColor,
              fontWeight: AppleMaterialDesign.weightSemibold,
            ),
            child: child,
          ),
        );

      case AdaptiveButtonType.destructive:
        return CupertinoButton.filled(
          onPressed: onPressed,
          padding: defaultPadding,
          borderRadius: BorderRadius.circular(
            borderRadius ?? AppleMaterialDesign.buttonRadiusIOS,
          ),
          minSize: minSize ?? AppleMaterialDesign.touchTargetIOS,
          child: DefaultTextStyle(
            style: const TextStyle(
              color: CupertinoColors.white,
              fontWeight: AppleMaterialDesign.weightSemibold,
            ),
            child: child,
          ),
        );
    }
  }

  Widget _buildAndroidButton(BuildContext context) {
    final theme = Theme.of(context);
    final defaultPadding = padding ??
        const EdgeInsets.symmetric(
          horizontal: AppleMaterialDesign.paddingMedium,
          vertical: AppleMaterialDesign.paddingMedium,
        );

    switch (type) {
      case AdaptiveButtonType.filled:
        return FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            padding: defaultPadding,
            minimumSize: Size(
              0,
              minSize ?? AppleMaterialDesign.touchTargetAndroid,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                borderRadius ?? AppleMaterialDesign.buttonRadiusAndroid,
              ),
            ),
            backgroundColor: color,
            foregroundColor: textColor,
          ),
          child: child,
        );

      case AdaptiveButtonType.tinted:
        return FilledButton.tonal(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            padding: defaultPadding,
            minimumSize: Size(
              0,
              minSize ?? AppleMaterialDesign.touchTargetAndroid,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                borderRadius ?? AppleMaterialDesign.buttonRadiusAndroid,
              ),
            ),
            backgroundColor: color,
            foregroundColor: textColor,
          ),
          child: child,
        );

      case AdaptiveButtonType.gray:
        return ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            padding: defaultPadding,
            minimumSize: Size(
              0,
              minSize ?? AppleMaterialDesign.touchTargetAndroid,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                borderRadius ?? AppleMaterialDesign.buttonRadiusAndroid,
              ),
            ),
            backgroundColor: color ?? theme.colorScheme.surfaceVariant,
            foregroundColor: textColor ?? theme.colorScheme.onSurfaceVariant,
            elevation: 0,
          ),
          child: child,
        );

      case AdaptiveButtonType.text:
        return TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            padding: defaultPadding,
            minimumSize: Size(
              0,
              minSize ?? AppleMaterialDesign.touchTargetAndroid,
            ),
            foregroundColor: textColor,
          ),
          child: child,
        );

      case AdaptiveButtonType.destructive:
        return FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            padding: defaultPadding,
            minimumSize: Size(
              0,
              minSize ?? AppleMaterialDesign.touchTargetAndroid,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                borderRadius ?? AppleMaterialDesign.buttonRadiusAndroid,
              ),
            ),
            backgroundColor: color ?? theme.colorScheme.error,
            foregroundColor: textColor ?? theme.colorScheme.onError,
          ),
          child: child,
        );
    }
  }
}

enum AdaptiveButtonType {
  filled,
  tinted,
  gray,
  text,
  destructive,
}

/// Adaptive activity indicator
class AdaptiveActivityIndicator extends StatelessWidget {
  const AdaptiveActivityIndicator({
    super.key,
    this.radius = 10.0,
    this.color,
  });

  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (AppleMaterialDesign.isIOS) {
      return CupertinoActivityIndicator(
        radius: radius,
        color: color,
      );
    }
    return CircularProgressIndicator(
      strokeWidth: 2.0,
      valueColor: color != null ? AlwaysStoppedAnimation(color) : null,
    );
  }
}

/// Adaptive card container
class AdaptiveCard extends StatelessWidget {
  const AdaptiveCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.color,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final defaultPadding = padding ??
        const EdgeInsets.all(AppleMaterialDesign.paddingMedium);

    if (AppleMaterialDesign.isIOS) {
      return Container(
        margin: margin,
        decoration: BoxDecoration(
          color: color ??
              CupertinoTheme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(
            AppleMaterialDesign.cardRadiusIOS,
          ),
          boxShadow: AppleMaterialDesign.iosShadowSmall,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(
              AppleMaterialDesign.cardRadiusIOS,
            ),
            child: Padding(
              padding: defaultPadding,
              child: child,
            ),
          ),
        ),
      );
    }

    return Card(
      margin: margin,
      elevation: AppleMaterialDesign.materialElevationMedium,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          AppleMaterialDesign.cardRadiusAndroid,
        ),
      ),
      color: color,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(
          AppleMaterialDesign.cardRadiusAndroid,
        ),
        child: Padding(
          padding: defaultPadding,
          child: child,
        ),
      ),
    );
  }
}

/// Adaptive list tile for iOS grouped lists or Material list items
class AdaptiveListTile extends StatelessWidget {
  const AdaptiveListTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.showChevron = false,
  });

  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final trailingWidget = trailing ??
        (showChevron
            ? Icon(
                AppleMaterialDesign.isIOS
                    ? CupertinoIcons.chevron_forward
                    : Icons.chevron_right,
                size: 20,
                color: AppleMaterialDesign.isIOS
                    ? CupertinoColors.systemGrey
                    : Colors.grey[600],
              )
            : null);

    if (AppleMaterialDesign.isIOS) {
      return CupertinoListTile(
        leading: leading,
        title: title,
        subtitle: subtitle,
        trailing: trailingWidget,
        onTap: onTap != null
            ? () {
                HapticFeedback.selectionClick();
                onTap!();
              }
            : null,
      );
    }

    return ListTile(
      leading: leading,
      title: title,
      subtitle: subtitle,
      trailing: trailingWidget,
      onTap: onTap != null
          ? () {
              HapticFeedback.selectionClick();
              onTap!();
            }
          : null,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppleMaterialDesign.paddingMedium,
        vertical: AppleMaterialDesign.paddingSmall,
      ),
    );
  }
}

/// Adaptive divider
class AdaptiveDivider extends StatelessWidget {
  const AdaptiveDivider({
    super.key,
    this.color,
    this.indent = 0,
    this.endIndent = 0,
  });

  final Color? color;
  final double indent;
  final double endIndent;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: AppleMaterialDesign.dividerThickness,
      thickness: AppleMaterialDesign.dividerThickness,
      color: color ??
          (AppleMaterialDesign.isIOS
              ? CupertinoColors.separator
              : Colors.grey[300]),
      indent: indent,
      endIndent: endIndent,
    );
  }
}

/// Adaptive search bar
class AdaptiveSearchBar extends StatelessWidget {
  const AdaptiveSearchBar({
    super.key,
    required this.controller,
    this.placeholder = 'Search',
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String placeholder;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    if (AppleMaterialDesign.isIOS) {
      return CupertinoSearchTextField(
        controller: controller,
        placeholder: placeholder,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        borderRadius: BorderRadius.circular(
          AppleMaterialDesign.radiusMedium,
        ),
      );
    }

    return TextField(
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: placeholder,
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            AppleMaterialDesign.radiusSmall,
          ),
        ),
        filled: true,
        fillColor: Colors.grey[100],
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppleMaterialDesign.paddingMedium,
          vertical: AppleMaterialDesign.paddingMedium,
        ),
      ),
    );
  }
}
