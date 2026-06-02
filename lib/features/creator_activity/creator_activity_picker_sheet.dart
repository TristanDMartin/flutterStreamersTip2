import 'package:flutter/material.dart';

import '../../core/theme/support_shell_style.dart';
import '../../models/creator_activity.dart';
import '../../services/creator_activity_service.dart';

/// Manual creator activity picker (Edit Profile / Creator Card).
class CreatorActivityPickerSheet extends StatefulWidget {
  const CreatorActivityPickerSheet({
    super.key,
    this.initialActivity,
  });

  final CreatorActivity? initialActivity;

  @override
  State<CreatorActivityPickerSheet> createState() =>
      _CreatorActivityPickerSheetState();
}

class _CreatorActivityPickerSheetState
    extends State<CreatorActivityPickerSheet> {
  final CreatorActivityService _service = CreatorActivityService();
  String _durationChoice = '24h';
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final TextTheme tt = Theme.of(context).textTheme;
    final ColorScheme cs = Theme.of(context).colorScheme;
    final CreatorActivity? current = widget.initialActivity;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: shell.iconDim,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Creator activity',
              style: tt.titleLarge?.copyWith(
                color: shell.onChrome,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Let your network know what you are working on.',
              style: tt.bodySmall?.copyWith(color: shell.muted),
            ),
            if (current != null &&
                current.isActiveAt(DateTime.now())) ...<Widget>[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: shell.surfaceCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: shell.surfaceCardBorder),
                ),
                child: Text(
                  'Current: ${current.displayLine}',
                  style: tt.bodyMedium?.copyWith(color: shell.onChrome),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Duration',
              style: tt.labelLarge?.copyWith(color: shell.mutedStrong),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: <Widget>[
                _DurationChip(
                  label: '1 hour',
                  value: '1h',
                  groupValue: _durationChoice,
                  onSelected: (String v) => setState(() => _durationChoice = v),
                ),
                _DurationChip(
                  label: '8 hours',
                  value: '8h',
                  groupValue: _durationChoice,
                  onSelected: (String v) => setState(() => _durationChoice = v),
                ),
                _DurationChip(
                  label: 'Today',
                  value: 'today',
                  groupValue: _durationChoice,
                  onSelected: (String v) => setState(() => _durationChoice = v),
                ),
                _DurationChip(
                  label: '24 hours',
                  value: '24h',
                  groupValue: _durationChoice,
                  onSelected: (String v) => setState(() => _durationChoice = v),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...kCreatorActivityManualPresets.map(
              (CreatorActivityPreset preset) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading:
                    Text(preset.emoji, style: const TextStyle(fontSize: 22)),
                title: Text(
                  preset.label,
                  style: tt.titleSmall?.copyWith(color: shell.onChrome),
                ),
                onTap: _isSaving ? null : () => _applyPreset(context, preset),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading:
                  Icon(Icons.visibility_off_outlined, color: shell.iconDim),
              title: Text(
                'Hide activity',
                style: tt.titleSmall?.copyWith(color: shell.onChrome),
              ),
              onTap: _isSaving ? null : () => _hide(context),
            ),
            if (_isSaving)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(color: cs.primary),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _applyPreset(
    BuildContext context,
    CreatorActivityPreset preset,
  ) async {
    setState(() => _isSaving = true);
    try {
      final Duration duration =
          CreatorActivityService.manualDurationFromChoice(_durationChoice);
      await _service.setManualActivity(preset: preset, duration: duration);
      if (context.mounted) Navigator.of(context).pop(preset);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _hide(BuildContext context) async {
    setState(() => _isSaving = true);
    try {
      await _service.hideActivity();
      if (context.mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class _DurationChip extends StatelessWidget {
  const _DurationChip({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onSelected,
  });

  final String label;
  final String value;
  final String groupValue;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final bool selected = value == groupValue;
    final ColorScheme cs = Theme.of(context).colorScheme;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(value),
      selectedColor: cs.primaryContainer,
      checkmarkColor: cs.onPrimaryContainer,
    );
  }
}

Future<void> showCreatorActivityPickerSheet(
  BuildContext context, {
  CreatorActivity? initialActivity,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (BuildContext ctx) => CreatorActivityPickerSheet(
      initialActivity: initialActivity,
    ),
  );
}
