import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/design/apple_material_design_system.dart';
import '../../core/design/adaptive_widgets.dart';

/// Adaptive empty state widget for lists and screens
class AdaptiveEmptyState extends StatelessWidget {
  const AdaptiveEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onActionTap,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppleMaterialDesign.paddingLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 80,
              color: AppleMaterialDesign.isIOS
                  ? CupertinoColors.systemGrey
                  : Colors.grey[400],
            ),
            const SizedBox(height: AppleMaterialDesign.space24),
            Text(
              title,
              style: AppleMaterialDesign.title2Style(context).copyWith(
                color: AppleMaterialDesign.isIOS
                    ? CupertinoColors.label
                    : Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: AppleMaterialDesign.space12),
              Text(
                message!,
                style: AppleMaterialDesign.bodyStyle(context).copyWith(
                  color: AppleMaterialDesign.isIOS
                      ? CupertinoColors.secondaryLabel
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onActionTap != null) ...[
              const SizedBox(height: AppleMaterialDesign.space24),
              AdaptiveButton(
                onPressed: onActionTap,
                type: AdaptiveButtonType.filled,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Adaptive loading indicator with optional message
class AdaptiveLoadingIndicator extends StatelessWidget {
  const AdaptiveLoadingIndicator({
    super.key,
    this.message,
    this.size = 20.0,
  });

  final String? message;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          AdaptiveActivityIndicator(radius: size / 2),
          if (message != null) ...[
            const SizedBox(height: AppleMaterialDesign.space16),
            Text(
              message!,
              style: AppleMaterialDesign.subheadlineStyle(context).copyWith(
                color: AppleMaterialDesign.isIOS
                    ? CupertinoColors.secondaryLabel
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// Adaptive error state widget
class AdaptiveErrorState extends StatelessWidget {
  const AdaptiveErrorState({
    super.key,
    required this.error,
    this.onRetry,
  });

  final String error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppleMaterialDesign.paddingLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              AppleMaterialDesign.isIOS
                  ? CupertinoIcons.exclamationmark_triangle
                  : Icons.error_outline,
              size: 64,
              color: AppleMaterialDesign.isIOS
                  ? CupertinoColors.systemRed
                  : Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: AppleMaterialDesign.space24),
            Text(
              'Something went wrong',
              style: AppleMaterialDesign.title2Style(context).copyWith(
                color: AppleMaterialDesign.isIOS
                    ? CupertinoColors.label
                    : Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppleMaterialDesign.space12),
            Text(
              error,
              style: AppleMaterialDesign.bodyStyle(context).copyWith(
                color: AppleMaterialDesign.isIOS
                    ? CupertinoColors.secondaryLabel
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppleMaterialDesign.space24),
              AdaptiveButton(
                onPressed: onRetry,
                type: AdaptiveButtonType.filled,
                child: const Text('Try Again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Adaptive pull-to-refresh wrapper
class AdaptiveRefreshIndicator extends StatelessWidget {
  const AdaptiveRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
  });

  final Widget child;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (AppleMaterialDesign.isIOS) {
      return CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          CupertinoSliverRefreshControl(
            onRefresh: onRefresh,
          ),
          SliverToBoxAdapter(
            child: child,
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: child,
    );
  }
}
