import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/design/apple_material_design_system.dart';
import '../../models/network_models.dart';

/// Adaptive tabs for Network view
/// Uses CupertinoSegmentedControl on iOS and Material TabBar on Android
class AdaptiveNetworkTabs extends StatelessWidget {
  const AdaptiveNetworkTabs({
    super.key,
    required this.selectedTab,
    required this.onTabSelected,
  });

  final NetworkTab selectedTab;
  final ValueChanged<NetworkTab> onTabSelected;

  @override
  Widget build(BuildContext context) {
    if (AppleMaterialDesign.isIOS) {
      return _buildIOSSegmentedControl(context);
    }
    return _buildAndroidTabs(context);
  }

  Widget _buildIOSSegmentedControl(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppleMaterialDesign.paddingMedium,
        vertical: AppleMaterialDesign.paddingSmall,
      ),
      child: CupertinoSlidingSegmentedControl<NetworkTab>(
        groupValue: selectedTab,
        onValueChanged: (NetworkTab? value) {
          if (value != null) {
            HapticFeedback.selectionClick();
            onTabSelected(value);
          }
        },
        children: {
          NetworkTab.connections: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppleMaterialDesign.paddingSmall,
              vertical: AppleMaterialDesign.paddingSmall,
            ),
            child: Text(
              'Connections',
              style: TextStyle(
                fontSize: AppleMaterialDesign.iosFootnote,
                fontWeight: selectedTab == NetworkTab.connections
                    ? AppleMaterialDesign.weightSemibold
                    : AppleMaterialDesign.weightRegular,
              ),
            ),
          ),
          NetworkTab.followers: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppleMaterialDesign.paddingSmall,
              vertical: AppleMaterialDesign.paddingSmall,
            ),
            child: Text(
              'Followers',
              style: TextStyle(
                fontSize: AppleMaterialDesign.iosFootnote,
                fontWeight: selectedTab == NetworkTab.followers
                    ? AppleMaterialDesign.weightSemibold
                    : AppleMaterialDesign.weightRegular,
              ),
            ),
          ),
          NetworkTab.following: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppleMaterialDesign.paddingSmall,
              vertical: AppleMaterialDesign.paddingSmall,
            ),
            child: Text(
              'Following',
              style: TextStyle(
                fontSize: AppleMaterialDesign.iosFootnote,
                fontWeight: selectedTab == NetworkTab.following
                    ? AppleMaterialDesign.weightSemibold
                    : AppleMaterialDesign.weightRegular,
              ),
            ),
          ),
        },
      ),
    );
  }

  Widget _buildAndroidTabs(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: _getTabIndex(),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        elevation: 0,
        child: TabBar(
          onTap: (index) {
            HapticFeedback.selectionClick();
            onTabSelected(_getTabFromIndex(index));
          },
          tabs: const [
            Tab(text: 'CONNECTIONS'),
            Tab(text: 'FOLLOWERS'),
            Tab(text: 'FOLLOWING'),
          ],
          labelStyle: TextStyle(
            fontSize: AppleMaterialDesign.androidLabelLarge,
            fontWeight: AppleMaterialDesign.weightMedium,
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.grey[300],
        ),
      ),
    );
  }

  int _getTabIndex() {
    switch (selectedTab) {
      case NetworkTab.connections:
        return 0;
      case NetworkTab.followers:
        return 1;
      case NetworkTab.following:
        return 2;
    }
  }

  NetworkTab _getTabFromIndex(int index) {
    switch (index) {
      case 0:
        return NetworkTab.connections;
      case 1:
        return NetworkTab.followers;
      case 2:
        return NetworkTab.following;
      default:
        return NetworkTab.connections;
    }
  }
}
