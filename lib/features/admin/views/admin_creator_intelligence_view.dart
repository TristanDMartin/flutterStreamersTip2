import 'package:flutter/material.dart';

import '../admin_backend_service.dart';

/// Platform-wide Creator Intelligence metrics (admin only).
class AdminCreatorIntelligenceView extends StatefulWidget {
  const AdminCreatorIntelligenceView({super.key});

  @override
  State<AdminCreatorIntelligenceView> createState() =>
      _AdminCreatorIntelligenceViewState();
}

class _AdminCreatorIntelligenceViewState
    extends State<AdminCreatorIntelligenceView> {
  Future<Map<String, dynamic>>? _statsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _statsFuture = AdminBackendService.creatorIntelligenceStats();
    });
    await _statsFuture;
  }

  int _int(Map<String, dynamic> data, String key) {
    final Object? v = data[key];
    if (v is int) {
      return v;
    }
    if (v is num) {
      return v.toInt();
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _reload,
      child: FutureBuilder<Map<String, dynamic>>(
        future: _statsFuture,
        builder: (BuildContext context, AsyncSnapshot<Map<String, dynamic>> snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const <Widget>[
                SizedBox(height: 120),
                Center(child: CircularProgressIndicator()),
              ],
            );
          }
          if (snap.hasError) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText.rich(
                    TextSpan(
                      text: 'Creator intelligence stats error: ${snap.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              ],
            );
          }
          final Map<String, dynamic> data = snap.data ?? <String, dynamic>{};
          final Map<String, dynamic> features =
              (data['featureUsage'] as Map?)?.cast<String, dynamic>() ??
                  <String, dynamic>{};
          final List<dynamic> topSearches =
              data['topSearches'] as List<dynamic>? ?? <dynamic>[];
          final List<dynamic> churnUsers =
              data['churnRiskUsers'] as List<dynamic>? ?? <dynamic>[];
          final List<(String, int)> tiles = <(String, int)>[
            ('Events (7d)', _int(data, 'eventsLast7Days')),
            ('Active creators (7d)', _int(data, 'activeCreators7d')),
            ('Subscription starts (7d)', _int(data, 'subscriptionStarts7d')),
            ('Gates seen (7d)', _int(data, 'subscriptionGatesSeen7d')),
            ('Courses completed (7d)', _int(data, 'coursesCompleted7d')),
            ('Abandoned flows (7d)', _int(data, 'abandonedFlows7d')),
          ];
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              Text(
                'Creator Intelligence',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Canonical analytics_events aggregation (last 7 days).',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              ...tiles.map(
                ((String, int) row) => Card(
                  child: ListTile(
                    title: Text(row.$1),
                    trailing: Text(
                      '${row.$2}',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Most used features',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...features.entries.map(
                (MapEntry<String, dynamic> e) => ListTile(
                  dense: true,
                  title: Text(e.key),
                  trailing: Text('${e.value}'),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Top searches',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              ...topSearches.take(10).map(
                    (dynamic row) {
                      if (row is! Map) {
                        return const SizedBox.shrink();
                      }
                      return ListTile(
                        dense: true,
                        title: Text('${row['query'] ?? ''}'),
                        trailing: Text('${row['count'] ?? 0}'),
                      );
                    },
                  ),
              const SizedBox(height: 16),
              Text(
                'Churn risk creators',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              ...churnUsers.take(10).map(
                    (dynamic row) {
                      if (row is! Map) {
                        return const SizedBox.shrink();
                      }
                      return ListTile(
                        dense: true,
                        title: Text('${row['uid'] ?? ''}'),
                        subtitle: Text('Score ${row['engagementScore'] ?? 0}'),
                        trailing: Text(
                          ((row['churnRisk'] as num?) ?? 0).toStringAsFixed(2),
                        ),
                      );
                    },
                  ),
            ],
          );
        },
      ),
    );
  }
}
