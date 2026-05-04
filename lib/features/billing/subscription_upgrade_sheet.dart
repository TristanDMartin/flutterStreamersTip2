import 'package:flutter/material.dart';

/// Compact upgrade prompt: Starter → Pro trial + Studio discovery.
///
/// Does not start billing itself; wire [onStartProTrial] / [onViewStudio] to
/// [IapBillingFacade.buySubscription] or navigation.
Future<void> showSubscriptionUpgradeSheet(
  BuildContext context, {
  required String currentPlanLabel,
  String recommendedPlanLabel = 'Pro',
  required VoidCallback onStartProTrial,
  required VoidCallback onViewStudio,
}) {
  final ColorScheme scheme = Theme.of(context).colorScheme;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: scheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (BuildContext ctx) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          16 + MediaQuery.paddingOf(ctx).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Upgrade',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Current plan: $currentPlanLabel',
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Recommended: $recommendedPlanLabel — cross-post, scheduling, '
              'and more AI credits.',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  onStartProTrial();
                },
                child: const Text('Start 7-Day Free Trial'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  onViewStudio();
                },
                child: const Text('View Studio'),
              ),
            ),
          ],
        ),
      );
    },
  );
}
