import 'package:flutter/material.dart';

import '../models/creator_goal_model.dart';

Future<CreatorGoalModel?> showTippyGoalSheet(
  BuildContext context, {
  CreatorGoalModel? initialGoal,
}) {
  return showModalBottomSheet<CreatorGoalModel>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF111827),
    showDragHandle: true,
    builder: (BuildContext context) {
      return _TippyGoalSheet(initialGoal: initialGoal);
    },
  );
}

class _TippyGoalSheet extends StatefulWidget {
  const _TippyGoalSheet({this.initialGoal});

  final CreatorGoalModel? initialGoal;

  @override
  State<_TippyGoalSheet> createState() => _TippyGoalSheetState();
}

class _TippyGoalSheetState extends State<_TippyGoalSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _targetController;
  String _type = 'followers';
  String _platform = 'tiktok';

  @override
  void initState() {
    super.initState();
    final CreatorGoalModel? initial = widget.initialGoal;
    _titleController = TextEditingController(text: initial?.title ?? '');
    _targetController = TextEditingController(
      text: initial?.targetValue?.toString() ?? '',
    );
    _type = initial?.type ?? 'followers';
    _platform = initial?.platform ?? 'tiktok';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final EdgeInsets padding = MediaQuery.paddingOf(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, padding.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Creator goal',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey<String>(_type),
            initialValue: _type,
            dropdownColor: const Color(0xFF1F2937),
            decoration: _fieldDecoration('Goal type'),
            items: const <DropdownMenuItem<String>>[
              DropdownMenuItem<String>(value: 'followers', child: Text('Followers')),
              DropdownMenuItem<String>(value: 'retention', child: Text('Retention')),
              DropdownMenuItem<String>(value: 'posting_cadence', child: Text('Posting cadence')),
              DropdownMenuItem<String>(value: 'monetization', child: Text('Monetization')),
              DropdownMenuItem<String>(value: 'custom', child: Text('Custom')),
            ],
            onChanged: (String? value) {
              if (value == null) {
                return;
              }
              setState(() => _type = value);
            },
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            key: ValueKey<String>(_platform),
            initialValue: _platform,
            dropdownColor: const Color(0xFF1F2937),
            decoration: _fieldDecoration('Platform'),
            items: const <DropdownMenuItem<String>>[
              DropdownMenuItem<String>(value: 'tiktok', child: Text('TikTok')),
              DropdownMenuItem<String>(value: 'youtube', child: Text('YouTube')),
              DropdownMenuItem<String>(value: 'twitch', child: Text('Twitch')),
              DropdownMenuItem<String>(value: 'instagram', child: Text('Instagram')),
            ],
            onChanged: (String? value) {
              if (value == null) {
                return;
              }
              setState(() => _platform = value);
            },
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _titleController,
            style: const TextStyle(color: Colors.white),
            decoration: _fieldDecoration('Title'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _targetController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: _fieldDecoration('Target value'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _save,
              child: const Text('Save goal'),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  void _save() {
    final int? target = int.tryParse(_targetController.text.trim());
    final String title = _titleController.text.trim().isEmpty
        ? 'Reach my next milestone'
        : _titleController.text.trim();
    Navigator.of(context).pop(
      CreatorGoalModel(
        id: widget.initialGoal?.id ?? '',
        uid: widget.initialGoal?.uid ?? '',
        type: _type,
        title: title,
        platform: _platform,
        targetValue: target,
        currentValue: widget.initialGoal?.currentValue ?? 0,
      ),
    );
  }
}
