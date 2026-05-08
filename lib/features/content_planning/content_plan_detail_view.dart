import 'package:flutter/material.dart';

import 'content_planning_models.dart';

/// Full-screen view of one plan and its line items (from Firestore / Tippy).
class ContentPlanDetailView extends StatelessWidget {
  const ContentPlanDetailView({
    super.key,
    required this.plan,
  });

  final ContentPlan plan;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final String? desc = plan.description?.trim();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          plan.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: <Widget>[
          if (desc != null && desc.isNotEmpty) ...<Widget>[
            Text(
              desc,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            '${plan.itemCount} ${plan.itemCount == 1 ? 'item' : 'items'}',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          if (plan.items.isEmpty)
            Text(
              'No line items were stored on this plan. Create a new plan from '
              'Tippy with a clear topic so steps can be generated.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            )
          else
            ...plan.items.map((ContentPlanItem item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  elevation: 0,
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: scheme.outline.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          item.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if ((item.caption ?? '').trim().isNotEmpty) ...<Widget>[
                          const SizedBox(height: 6),
                          Text(
                            item.caption!.trim(),
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                        if ((item.description ?? '').trim().isNotEmpty &&
                            item.description!.trim() !=
                                (item.caption ?? '').trim()) ...<Widget>[
                          const SizedBox(height: 6),
                          Text(
                            item.description!.trim(),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        if ((item.notes ?? '').trim().isNotEmpty) ...<Widget>[
                          const SizedBox(height: 6),
                          Text(
                            item.notes!.trim(),
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontStyle: FontStyle.italic,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        if (item.platformsSummary.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 8),
                          Text(
                            item.platformsSummary,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                        ],
                        if ((item.type ?? '').isNotEmpty ||
                            (item.status ?? '').isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: <Widget>[
                                if ((item.type ?? '').isNotEmpty)
                                  Chip(
                                    label: Text(item.type!),
                                    visualDensity: VisualDensity.compact,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                if ((item.status ?? '').isNotEmpty)
                                  Chip(
                                    label: Text(item.status!),
                                    visualDensity: VisualDensity.compact,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
