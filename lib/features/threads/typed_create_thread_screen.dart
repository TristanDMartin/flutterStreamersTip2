import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'threads_contract.dart';
import 'threads_models.dart';
import 'threads_repository.dart';
import 'thread_visibility.dart';
import '../../widgets/threads/thread_visibility_picker.dart';

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
  String _visibility = kThreadVisibilityPublic;
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
    final firebase_auth.User? user =
        firebase_auth.FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      setState(() => _errorMessage = 'Please sign in to start a thread.');
      return;
    }

    // Verify email is verified
    await user.reload();
    final firebase_auth.User? refreshedUser =
        firebase_auth.FirebaseAuth.instance.currentUser;
    if (refreshedUser != null && !refreshedUser.emailVerified) {
      setState(() => _errorMessage =
          'Please verify your email before creating threads. Check your inbox for a verification link.');
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
      debugPrint('📝 Creating typed thread: title="$title", type=$_type, category=$_categoryId');
      
      final String id = await widget.repository.createThread(
        CreateThreadRequest(
          type: _type,
          title: title,
          body: body,
          categoryId: _categoryId,
          authorId: user.uid,
          visibility: _visibility,
          tippyStarterId: _tippyStarterId,
          payload: <String, dynamic>{
            'prompt': widget.initialPreset?.prompt,
          },
        ),
      );

      debugPrint('✅ Typed thread created successfully: $id');

      if (!mounted) {
        return;
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thread created successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      
      Navigator.of(context).pop(id);
    } on firebase_auth.FirebaseAuthException catch (e) {
      debugPrint('❌ Auth error creating thread: ${e.code} - ${e.message}');
      if (!mounted) return;
      setState(() {
        _errorMessage = switch (e.code) {
          'requires-recent-login' => 'Please sign in again to create threads.',
          'user-disabled' => 'Your account has been disabled.',
          'user-not-found' => 'Your account was not found. Please sign in again.',
          _ => 'Authentication error: ${e.message ?? e.code}',
        };
        _isSubmitting = false;
      });
    } on FirebaseException catch (e) {
      debugPrint('❌ Firestore error creating thread: ${e.code} - ${e.message}');
      if (!mounted) return;
      setState(() {
        _errorMessage = switch (e.code) {
          'permission-denied' => 'You don\'t have permission to create threads. Please complete your account setup or verify your email.',
          'unavailable' => 'Server is temporarily unavailable. Please try again in a moment.',
          'deadline-exceeded' => 'Request timed out. Check your connection and try again.',
          _ => 'Error creating thread: ${e.message ?? e.code}',
        };
        _isSubmitting = false;
      });
    } catch (e) {
      debugPrint('❌ Unexpected error creating thread: $e');
      if (!mounted) return;
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
          const SizedBox(height: 16),
          ThreadVisibilityPicker(
            value: _visibility,
            enabled: !_isSubmitting,
            onChanged: (String next) {
              setState(() => _visibility = next);
            },
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
