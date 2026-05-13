import 'package:flutter/material.dart';
import '../../models/feed_tab.dart';

/// Feed dropdown widget for HomeView (For You / Progression / Threads)
class FeedDropdownWidget extends StatelessWidget {
  final FeedTab activeTab;
  final FeedTab? tourHighlightTab;
  final bool isVisible;
  final ValueChanged<FeedTab> onTabSelected;
  final VoidCallback onClose;

  const FeedDropdownWidget({
    super.key,
    required this.activeTab,
    this.tourHighlightTab,
    required this.isVisible,
    required this.onTabSelected,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isLight = Theme.of(context).brightness == Brightness.light;
    final List<Color> gradColors = <Color>[
      scheme.surface,
      scheme.surfaceContainerLow,
    ];
    return Stack(
      children: [
        Material(
          elevation: 20,
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            width: 200,
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: 0.98),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: scheme.outline.withValues(
                  alpha: isLight ? 0.45 : 0.38,
                ),
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
                _buildDropdownItem(context, FeedTab.forYou),
                _buildDivider(context),
                _buildDropdownItem(context, FeedTab.following),
                _buildDivider(context),
                _buildDropdownItem(context, FeedTab.threads),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownItem(BuildContext context, FeedTab tab) {
    final bool isSelected = activeTab == tab;
    final bool isTourRow = tourHighlightTab != null && tourHighlightTab == tab;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isLight = Theme.of(context).brightness == Brightness.light;
    final Color label = scheme.onSurface;
    return GestureDetector(
      onTap: () {
        onTabSelected(tab);
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: isTourRow && !isSelected
              ? Border.all(
                  color: scheme.secondary.withValues(alpha: 0.9),
                  width: 2,
                )
              : null,
          color: isSelected
              ? scheme.primary.withValues(alpha: isLight ? 0.14 : 0.18)
              : isTourRow
                  ? scheme.secondary.withValues(alpha: isLight ? 0.12 : 0.16)
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
                  fontWeight: (isSelected || isTourRow)
                      ? FontWeight.w800
                      : FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 12),
            _dropdownTrailingIcon(
              isSelected: isSelected,
              isTourRow: isTourRow,
              scheme: scheme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _dropdownTrailingIcon({
    required bool isSelected,
    required bool isTourRow,
    required ColorScheme scheme,
  }) {
    if (isSelected) {
      return Icon(
        Icons.check,
        color: scheme.primary,
        size: 20,
      );
    }
    if (isTourRow) {
      return Icon(
        Icons.school_rounded,
        color: scheme.secondary,
        size: 20,
      );
    }
    return const SizedBox(width: 20);
  }

  Widget _buildDivider(BuildContext context) {
    final bool isLight = Theme.of(context).brightness == Brightness.light;
    final ColorScheme s = Theme.of(context).colorScheme;
    return Container(
      height: 1,
      color: s.outline.withValues(alpha: isLight ? 0.3 : 0.28),
      margin: const EdgeInsets.symmetric(horizontal: 16),
    );
  }
}
