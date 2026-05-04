import 'package:flutter/material.dart';

Future<String?> showAdminTextConfirmSheet(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  required String reasonHint,
}) async {
  final TextEditingController reason = TextEditingController();
  try {
  final String? result = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    barrierColor: Colors.black54,
    builder: (ctx) {
      final inset = MediaQuery.viewInsetsOf(ctx).bottom;
      return Padding(
        padding: EdgeInsets.only(bottom: inset),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(body, style: Theme.of(ctx).textTheme.bodyMedium),
                const SizedBox(height: 16),
                TextField(
                  controller: reason,
                  decoration: InputDecoration(
                    labelText: reasonHint,
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () =>
                            Navigator.pop(ctx, reason.text.trim()),
                        child: Text(confirmLabel),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  return result;
  } finally {
    reason.dispose();
  }
}

Future<String?> showAdminRemoveVideoSheet(BuildContext context) async {
  const opts = <String>[
    'policy_violation',
    'harassment',
    'spam',
    'copyright',
    'other',
  ];
  String selected = opts.first;
  final String? result = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    barrierColor: Colors.black54,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: StatefulBuilder(
            builder: (ctx2, setSt) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Remove this video?',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This hides it from For You, Discover, profile pages, '
                    'comments, and public playback.',
                    style: Theme.of(ctx).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Reason',
                      border: OutlineInputBorder(),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selected,
                        isExpanded: true,
                        items: opts
                            .map(
                              (e) =>
                                  DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(),
                        onChanged: (String? v) =>
                            setSt(() => selected = v ?? opts.first),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.pop(ctx, selected),
                          child: const Text('Remove video'),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      );
    },
  );
  return result;
}
