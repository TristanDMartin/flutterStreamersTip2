import 'package:flutter/material.dart';
import '../../models/feed_tab.dart';
import '../../constants/app_colors.dart';

/// Feed dropdown widget for HomeView (For You / Progression / Threads)
class FeedDropdownWidget extends StatelessWidget {
  final FeedTab activeTab;
  final bool isVisible;
  final ValueChanged<FeedTab> onTabSelected;
  final VoidCallback onClose;

  const FeedDropdownWidget({
    super.key,
    required this.activeTab,
    required this.isVisible,
    required this.onTabSelected,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isLight = Theme.of(context).brightness == Brightness.light;
    final List<Color> gradColors = isLight
        ? <Color>[
            scheme.surface,
            scheme.surfaceContainerLow,
          ]
        : AppColors.supportSurfaceGradient;
    return Stack(
      children: [
        Material(
          elevation: 20,
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            width: 200,
            decoration: BoxDecoration(
              color: isLight
                  ? scheme.surface.withValues(alpha: 0.98)
                  : AppColors.supportBackground.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isLight
                    ? scheme.outline.withValues(alpha: 0.45)
                    : Colors.white.withValues(alpha: 0.12),
                width: 1.2,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: isLight ? 0.12 : 0.24),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradColors,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _buildDropdownItem(
                  context,
                  FeedTab.forYou,
                ),
                _buildDivider(context),
                _buildDropdownItem(
                  context,
                  FeedTab.following,
                ),
                _buildDivider(context),
                _buildDropdownItem(
                  context,
                  FeedTab.threads,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownItem(BuildContext context, FeedTab tab) {
    final bool isSelected = activeTab == tab;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isLight = Theme.of(context).brightness == Brightness.light;
    final Color label = isLight ? scheme.onSurface : Colors.white;
    return GestureDetector(
      onTap: () {
        onTabSelected(tab);
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: isSelected
              ? (isLight
                  ? scheme.primary.withValues(alpha: 0.14)
                  : AppColors.supportAccent.withValues(alpha: 0.16))
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                tab.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: label,
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 12),
            if (isSelected)
              Icon(
                Icons.check,
                color: isLight ? scheme.primary : Colors.white,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    final bool isLight = Theme.of(context).brightness == Brightness.light;
    final ColorScheme s = Theme.of(context).colorScheme;
    return Container(
      height: 1,
      color: isLight
          ? s.outline.withValues(alpha: 0.3)
          : Colors.white.withValues(alpha: 0.1),
      margin: const EdgeInsets.symmetric(horizontal: 16),
    );
  }
}
