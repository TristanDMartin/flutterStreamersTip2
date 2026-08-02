import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';

import 'threads_contract.dart';
import 'threads_models.dart';
import 'threads_repository.dart';

/// Guided typed composer — fields driven by Threads v2 contract.
class TypedCreateThreadScreen extends StatefulWidget {
  const TypedCreateThreadScreen({
    super.key,
    required this.repository,
    this.initialPreset,
    this.initialType,
  });

  final ThreadsRepository repository;
  final TippyStarterPreset? initialPreset;
  final String? initialType;

  @override
  State<TypedCreateThreadScreen> createState() =>
      _TypedCreateThreadScreenState();
}

class _TypedCreateThreadScreenState extends State<TypedCreateThreadScreen> {
  late String _type;
  late String _categoryId;
  String? _tippyStarterId;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final TippyStarterPreset? preset = widget.initialPreset;
    _type = normalizeThreadType(preset?.threadType ?? widget.initialType);
    _categoryId = normalizeCategoryId(
      preset?.defaultCategoryId ?? 'growth',
    );
    _tippyStarterId = preset?.id;
    if (preset != null) {
      _titleController.text = '';
      _bodyController.text = preset.structure.map((String s) => '• $s\n').join();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final String title = _titleController.text.trim();
    final String body = _bodyController.text.trim();
    final String? uid =
        firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _errorMessage = 'Please sign in to start a thread.');
      return;
    }
    if (title.isEmpty || body.isEmpty) {
      setState(() => _errorMessage = 'Title and body are required.');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      final String id = await widget.repository.createThread(
        CreateThreadRequest(
          type: _type,
          title: title,
          body: body,
          categoryId: _categoryId,
          authorId: uid,
          tippyStarterId: _tippyStarterId,
          payload: <String, dynamic>{
            'prompt': widget.initialPreset?.prompt,
          },
        ),
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(id);
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = e.toString();
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TippyStarterPreset? preset = widget.initialPreset;
    return Scaffold(
      backgroundColor: const Color(0xFF071120),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          threadTypeLabel(_type),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: <Widget>[
          if (preset != null) ...<Widget>[
            Text(
              preset.prompt,
              style: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.72),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            'Thread type',
            style: TextStyle(
              color: scheme.onSurface.withValues(alpha: 0.7),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kThreadTypes.map((String type) {
              final bool selected = _type == type;
              return ChoiceChip(
                label: Text(threadTypeLabel(type)),
                selected: selected,
                onSelected: (_) => setState(() => _type = type),
              );
            }).toList(growable: false),
          ),
          const SizedBox(height: 16),
          Text(
            'Category',
            style: TextStyle(
              color: scheme.onSurface.withValues(alpha: 0.7),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: kCanonicalCategoryIds.contains(_categoryId)
                ? _categoryId
                : 'growth',
            items: kCanonicalCategoryIds
                .map(
                  (String id) => DropdownMenuItem<String>(
                    value: id,
                    child: Text(categoryLabel(id)),
                  ),
                )
                .toList(growable: false),
            onChanged: (String? value) {
              if (value != null) {
                setState(() => _categoryId = value);
              }
            },
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Title',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bodyController,
            minLines: 8,
            maxLines: 16,
            decoration: const InputDecoration(
              labelText: 'Body',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          if (_errorMessage != null) ...<Widget>[
            const SizedBox(height: 12),
            SelectableText.rich(
              TextSpan(
                text: _errorMessage,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            child: Text(_isSubmitting ? 'Posting…' : 'Start thread'),
          ),
        ],
      ),
    );
  }
}
