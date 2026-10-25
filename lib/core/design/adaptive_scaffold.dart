import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'apple_material_design_system.dart';

/// Adaptive scaffold that uses appropriate platform conventions
class AdaptiveScaffold extends StatelessWidget {
  const AdaptiveScaffold({
    super.key,
    this.title,
    this.body,
    this.leading,
    this.trailing,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.backgroundColor,
    this.useLargeTitle = false,
    this.showBackButton = false,
  });

  final String? title;
  final Widget? body;
  final Widget? leading;
  final Widget? trailing;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final Color? backgroundColor;
  final bool useLargeTitle;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    if (AppleMaterialDesign.isIOS) {
      return _buildIOSScaffold(context);
    }
    return _buildAndroidScaffold(context);
  }

  Widget _buildIOSScaffold(BuildContext context) {
    if (useLargeTitle && title != null) {
      return CupertinoPageScaffold(
        backgroundColor: backgroundColor ?? CupertinoColors.systemBackground,
        navigationBar: CupertinoNavigationBar(
          backgroundColor: CupertinoColors.systemBackground.resolveFrom(context),
          leading: leading ??
              (showBackButton
                  ? CupertinoNavigationBarBackButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                    )
                  : null),
          trailing: trailing,
          middle: Text(title!),
          border: Border(
            bottom: BorderSide(
              color: CupertinoColors.separator.resolveFrom(context),
              width: 0.5,
            ),
          ),
        ),
        child: SafeArea(
          child: body ?? const SizedBox(),
        ),
      );
    }

    return CupertinoPageScaffold(
      backgroundColor: backgroundColor ?? CupertinoColors.systemBackground,
      navigationBar: title != null
          ? CupertinoNavigationBar(
              backgroundColor:
                  CupertinoColors.systemBackground.resolveFrom(context),
              leading: leading ??
                  (showBackButton
                      ? CupertinoNavigationBarBackButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                        )
                      : null),
              trailing: trailing,
              middle: Text(title!),
              border: Border(
                bottom: BorderSide(
                  color: CupertinoColors.separator.resolveFrom(context),
                  width: 0.5,
                ),
              ),
            )
          : null,
      child: SafeArea(
        child: Column(
          children: [
            Expanded(child: body ?? const SizedBox()),
            if (bottomNavigationBar != null) bottomNavigationBar!,
          ],
        ),
      ),
    );
  }

  Widget _buildAndroidScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: title != null
          ? AppBar(
              title: Text(title!),
              leading: leading ??
                  (showBackButton
                      ? IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.of(context).maybePop(),
                        )
                      : null),
              actions: trailing != null ? [trailing!] : null,
              elevation: 0,
              scrolledUnderElevation: 1,
            )
          : null,
      body: body,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
    );
  }
}

/// Adaptive page with large title (iOS) or regular app bar (Android)
class AdaptivePage extends StatelessWidget {
  const AdaptivePage({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.backgroundColor,
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    if (AppleMaterialDesign.isIOS) {
      return CupertinoPageScaffold(
        backgroundColor: backgroundColor ??
            CupertinoColors.systemGroupedBackground.resolveFrom(context),
        child: CustomScrollView(
          slivers: [
            CupertinoSliverNavigationBar(
              backgroundColor:
                  CupertinoColors.systemBackground.resolveFrom(context),
              largeTitle: Text(title),
              trailing: trailing,
              border: Border(
                bottom: BorderSide(
                  color: CupertinoColors.separator.resolveFrom(context),
                  width: 0.5,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: child,
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: Text(title),
            actions: trailing != null ? [trailing!] : null,
            floating: true,
            snap: true,
            elevation: 0,
          ),
          SliverToBoxAdapter(
            child: child,
          ),
        ],
      ),
    );
  }
}

/// Adaptive sliver app bar for scrollable lists
class AdaptiveSliverAppBar extends StatelessWidget {
  const AdaptiveSliverAppBar({
    super.key,
    required this.title,
    this.trailing,
    this.backgroundColor,
  });

  final String title;
  final Widget? trailing;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    if (AppleMaterialDesign.isIOS) {
      return CupertinoSliverNavigationBar(
        backgroundColor: backgroundColor ??
            CupertinoColors.systemBackground.resolveFrom(context),
        largeTitle: Text(title),
        trailing: trailing,
        border: Border(
          bottom: BorderSide(
            color: CupertinoColors.separator.resolveFrom(context),
            width: 0.5,
          ),
        ),
      );
    }

    return SliverAppBar(
      backgroundColor: backgroundColor,
      title: Text(title),
      actions: trailing != null ? [trailing!] : null,
      floating: true,
      snap: true,
      elevation: 0,
      scrolledUnderElevation: 1,
    );
  }
}
