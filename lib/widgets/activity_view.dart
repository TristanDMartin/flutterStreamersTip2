import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/activity_provider.dart';
import '../services/auth_service.dart';
import '../widgets/activity_row_view.dart';
import '../models/activity_notification.dart';

class ActivityView extends ConsumerWidget {
  const ActivityView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authServiceProvider);
    final state = ref.watch(activityProvider);
    final notifier = ref.read(activityProvider.notifier);

    if (auth.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final userId = auth.currentUser?.id;
    if (userId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Activity'),
        ),
        body: const Center(
          child: Text('Sign in to view your activity.'),
        ),
      );
    }

    ref.listen(activityProvider, (prev, next) {},);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifier.startProcessingListener(userId);
      notifier.init(userId);
    });

    final titles = _orderedSectionTitles(state.grouped.keys.toList());

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Activity'),
            if (state.isProcessing) ...[
              const SizedBox(width: 8),
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF9248D2),
              Color(0xFF1670DE),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              if (state.isProcessing)
                _ProcessingIndicator(count: state.processingCount),
              Expanded(
                child: state.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _ActivityList(
                        titles: titles,
                        grouped: state.grouped,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<String> _orderedSectionTitles(List<String> titles) {
    final set = titles.toSet();
    final List<String> ordered = [];
    if (set.remove('Today')) ordered.add('Today');
    if (set.remove('Yesterday')) ordered.add('Yesterday');
    final rest = set.toList();
    rest.sort((a, b) => _parseDate(b).compareTo(_parseDate(a)));
    ordered.addAll(rest);
    return ordered;
  }

  DateTime _parseDate(String key) {
    if (key == 'Today') return DateTime.now();
    if (key == 'Yesterday') return DateTime.now().subtract(const Duration(days: 1));
    final parts = key.split('/');
    if (parts.length == 3) {
      final month = int.tryParse(parts[0]) ?? 1;
      final day = int.tryParse(parts[1]) ?? 1;
      final year = int.tryParse(parts[2]) ?? DateTime.now().year;
      return DateTime(year, month, day);
    }
    return DateTime(2000);
  }
}

class _ActivityList extends ConsumerWidget {
  final List<String> titles;
  final Map<String, List<ActivityNotification>> grouped;

  const _ActivityList({
    required this.titles,
    required this.grouped,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: titles.length,
      itemBuilder: (context, index) {
        final title = titles[index];
        final items = grouped[title] ?? const <ActivityNotification>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(title: title),
            for (final n in items)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ActivityRowView(
                  notification: n,
                  onProfileTap: (user) {},
                  onPostTap: (notification) {},
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 16, top: 8, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
      ),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ProcessingIndicator extends StatelessWidget {
  final int count;
  const _ProcessingIndicator({required this.count});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Text(
            'Processing $count notifications...'
                .trim(),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// Removed duplicate declarations appended at EOF that caused directive order errors.
