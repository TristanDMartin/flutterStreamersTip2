import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/design/st_radius.dart';
import '../core/design/st_spacing.dart';
import '../core/theme/support_shell_style.dart';
import '../services/hashtag_lock_service.dart';
import '../services/rate_limiting_service.dart';
import '../widgets/content_validation_field.dart';
import '../utils/playback_route_suppression.dart';

class EditFieldView extends ConsumerStatefulWidget {
  final String title;
  final String text;
  final Function(String) onTextChanged;
  final String? helperText;
  final int maxLength;
  final VoidCallback? onSave;
  final VoidCallback? onCancel;

  const EditFieldView({
    super.key,
    required this.title,
    required this.text,
    required this.onTextChanged,
    this.helperText,
    required this.maxLength,
    this.onSave,
    this.onCancel,
  });

  @override
  ConsumerState<EditFieldView> createState() => _EditFieldViewState();
}

class _EditFieldViewState extends ConsumerState<EditFieldView> {
  late TextEditingController _textController;
  late TextEditingController _hashtagController;
  late List<String> _selectedHashtags;

  static const int maxHashtags = 4;
  bool _isContentValid = true;
  bool _isRateLimited = false;
  String _currentText = '';

  bool get _isHashtagMode => widget.title == 'Hashtags';

  bool get _isValid {
    if (_isHashtagMode) {
      return _selectedHashtags.isNotEmpty &&
          _selectedHashtags.length <= maxHashtags &&
          _selectedHashtags.every(
            (String hashtag) =>
                RegExp(r'^[A-Za-z0-9_]{1,20}$').hasMatch(hashtag),
          );
    }
    final String trimmedText = _currentText.trim();
    return trimmedText.isNotEmpty &&
        _currentText.length <= widget.maxLength &&
        _isContentValid &&
        !_isRateLimited;
  }

  @override
  void initState() {
    super.initState();
    PlaybackRouteSuppression.suppress(reason: 'edit_field');
    _textController = TextEditingController(text: widget.text);
    _hashtagController = TextEditingController();
    _hashtagController.addListener(() => setState(() {}));
    _currentText = widget.text;

    if (_isHashtagMode) {
      final List<String> initial = widget.text
          .split(',')
          .map((String e) => e.trim())
          .where((String e) => e.isNotEmpty)
          .toList();
      _selectedHashtags = initial;
    } else {
      _selectedHashtags = <String>[];
    }

    _checkRateLimit();
  }

  @override
  void dispose() {
    _textController.dispose();
    _hashtagController.dispose();
    super.dispose();
  }

  Future<void> _addHashtag(String hashtag) async {
    final String cleaned = hashtag.trim().replaceAll('#', '');
    if (cleaned.isEmpty ||
        _selectedHashtags.contains(cleaned) ||
        _selectedHashtags.length >= maxHashtags ||
        !RegExp(r'^[A-Za-z0-9_]{1,20}$').hasMatch(cleaned)) {
      return;
    }

    final User? currentUser = FirebaseAuth.instance.currentUser;
    final HashtagLockService hashtagService = HashtagLockService();
    final HashtagValidationResult validation =
        await hashtagService.validateHashtag(cleaned, currentUser?.uid);

    if (!validation.isValid) {
      if (mounted) {
        final ColorScheme cs = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(validation.errorMessage ?? 'Invalid hashtag'),
            backgroundColor: cs.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    setState(() {
      _selectedHashtags.add(cleaned);
      _hashtagController.clear();
    });
  }

  void _removeHashtag(String hashtag) {
    setState(() {
      _selectedHashtags.remove(hashtag);
    });
  }

  Future<void> _checkRateLimit() async {
    final bool isLimited = await RateLimitingService().isRateLimited();
    if (mounted) {
      setState(() {
        _isRateLimited = isLimited;
      });
    }
  }

  Future<void> _handleSave() async {
    if (_isHashtagMode) {
      final String hashtagText = _selectedHashtags.join(', ');
      widget.onTextChanged(hashtagText);
    } else {
      if (!_isContentValid) {
        _showContentError();
        return;
      }
      if (_isRateLimited) {
        await _showRateLimitError();
        return;
      }
      widget.onTextChanged(_currentText);
    }

    widget.onSave?.call();
  }

  void _showContentError() {
    final ColorScheme cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Content violates community guidelines. Please review and edit.',
        ),
        backgroundColor: cs.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _showRateLimitError() async {
    final Duration? remainingTime =
        await RateLimitingService().getRemainingCooldown();
    final int minutes = remainingTime?.inMinutes ?? 0;

    if (mounted) {
      final ColorScheme cs = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Too many violations. Please wait $minutes minutes before trying again.',
          ),
          backgroundColor: cs.tertiary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: shell.scaffold,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _EditFieldHeader(
              title: widget.title,
              canSave: _isValid,
              onCancel: widget.onCancel ?? () => Navigator.pop(context),
              onSave: _handleSave,
              shell: shell,
              colorScheme: cs,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  STSpacing.lg,
                  STSpacing.md,
                  STSpacing.lg,
                  STSpacing.xxl,
                ),
                child: _isHashtagMode
                    ? _HashtagsEditorCard(
                        shell: shell,
                        colorScheme: cs,
                        hashtagController: _hashtagController,
                        selectedHashtags: _selectedHashtags,
                        maxHashtags: maxHashtags,
                        onAddHashtag: _addHashtag,
                        onRemoveHashtag: _removeHashtag,
                      )
                    : _TextEditorCard(
                        shell: shell,
                        colorScheme: cs,
                        title: widget.title,
                        helperText: widget.helperText,
                        maxLength: widget.maxLength,
                        currentText: _currentText,
                        textController: _textController,
                        isRateLimited: _isRateLimited,
                        onTextChanged: (String value) {
                          setState(() => _currentText = value);
                          widget.onTextChanged(value);
                        },
                        onValidationChanged: (bool isValid) {
                          setState(() => _isContentValid = isValid);
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditFieldHeader extends StatelessWidget {
  const _EditFieldHeader({
    required this.title,
    required this.canSave,
    required this.onCancel,
    required this.onSave,
    required this.shell,
    required this.colorScheme,
  });

  final String title;
  final bool canSave;
  final VoidCallback onCancel;
  final VoidCallback onSave;
  final StSupportShellStyle shell;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        STSpacing.lg,
        STSpacing.md,
        STSpacing.lg,
        STSpacing.sm,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: STSpacing.md,
          vertical: STSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: shell.surfaceCard,
          borderRadius: BorderRadius.circular(STRadius.xxl),
          border: Border.all(color: shell.surfaceCardBorder),
        ),
        child: Row(
          children: <Widget>[
            TextButton(
              onPressed: onCancel,
              style: TextButton.styleFrom(
                foregroundColor: shell.onChrome,
                padding: const EdgeInsets.symmetric(horizontal: STSpacing.sm),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: shell.onChrome,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: canSave ? onSave : null,
              style: TextButton.styleFrom(
                foregroundColor:
                    canSave ? colorScheme.primary : shell.mutedStrong,
                padding: const EdgeInsets.symmetric(horizontal: STSpacing.sm),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Save',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HashtagsEditorCard extends StatelessWidget {
  const _HashtagsEditorCard({
    required this.shell,
    required this.colorScheme,
    required this.hashtagController,
    required this.selectedHashtags,
    required this.maxHashtags,
    required this.onAddHashtag,
    required this.onRemoveHashtag,
  });

  final StSupportShellStyle shell;
  final ColorScheme colorScheme;
  final TextEditingController hashtagController;
  final List<String> selectedHashtags;
  final int maxHashtags;
  final Future<void> Function(String) onAddHashtag;
  final void Function(String) onRemoveHashtag;

  @override
  Widget build(BuildContext context) {
    final bool atLimit = selectedHashtags.length >= maxHashtags;
    final InputDecoration inputDecoration = InputDecoration(
      hintText: 'Add hashtag',
      hintStyle: TextStyle(color: shell.muted),
      filled: true,
      fillColor: shell.chipUnselectedBg,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: STSpacing.lg,
        vertical: STSpacing.md,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(STRadius.md),
        borderSide: BorderSide(color: shell.chipUnselectedBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(STRadius.md),
        borderSide: BorderSide(color: shell.chipUnselectedBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(STRadius.md),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
      suffixIcon: hashtagController.text.isNotEmpty
          ? IconButton(
              onPressed: hashtagController.clear,
              icon: Icon(Icons.close_rounded, color: shell.muted, size: 20),
            )
          : null,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 0, 6, STSpacing.md),
          child: Text(
            'Add up to $maxHashtags hashtags so people can find you.',
            style: TextStyle(
              color: shell.muted,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(STSpacing.lg),
          decoration: BoxDecoration(
            color: shell.surfaceCard,
            borderRadius: BorderRadius.circular(STRadius.xxl),
            border: Border.all(color: shell.surfaceCardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextField(
                controller: hashtagController,
                decoration: inputDecoration,
                style: TextStyle(color: shell.onChrome),
                textCapitalization: TextCapitalization.none,
                autocorrect: false,
                enabled: !atLimit,
                textInputAction: TextInputAction.done,
                onSubmitted: onAddHashtag,
              ),
              if (selectedHashtags.isNotEmpty) ...<Widget>[
                const SizedBox(height: STSpacing.lg),
                Wrap(
                  spacing: STSpacing.sm,
                  runSpacing: STSpacing.sm,
                  children: selectedHashtags
                      .map(
                        (String tag) => _HashtagChip(
                          tag: tag,
                          shell: shell,
                          onRemove: () => onRemoveHashtag(tag),
                        ),
                      )
                      .toList(),
                ),
              ] else ...<Widget>[
                const SizedBox(height: STSpacing.lg),
                Text(
                  'No hashtags yet — type one above and press return.',
                  style: TextStyle(
                    color: shell.mutedStrong,
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: STSpacing.lg),
              Row(
                children: <Widget>[
                  Text(
                    '${selectedHashtags.length}/$maxHashtags',
                    style: TextStyle(
                      color: atLimit ? colorScheme.primary : shell.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (atLimit)
                    Text(
                      'Maximum reached',
                      style: TextStyle(
                        color: shell.mutedStrong,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HashtagChip extends StatelessWidget {
  const _HashtagChip({
    required this.tag,
    required this.shell,
    required this.onRemove,
  });

  final String tag;
  final StSupportShellStyle shell;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: shell.chipSelectedBg,
      borderRadius: BorderRadius.circular(STRadius.pill),
      child: InkWell(
        onTap: onRemove,
        borderRadius: BorderRadius.circular(STRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: STSpacing.md,
            vertical: STSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(STRadius.pill),
            border: Border.all(color: shell.chipSelectedBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '#$tag',
                style: TextStyle(
                  color: shell.chipSelectedFg,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: STSpacing.xs),
              Icon(
                Icons.close_rounded,
                size: 16,
                color: shell.chipSelectedFg.withValues(alpha: 0.75),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TextEditorCard extends StatelessWidget {
  const _TextEditorCard({
    required this.shell,
    required this.colorScheme,
    required this.title,
    required this.helperText,
    required this.maxLength,
    required this.currentText,
    required this.textController,
    required this.isRateLimited,
    required this.onTextChanged,
    required this.onValidationChanged,
  });

  final StSupportShellStyle shell;
  final ColorScheme colorScheme;
  final String title;
  final String? helperText;
  final int maxLength;
  final String currentText;
  final TextEditingController textController;
  final bool isRateLimited;
  final ValueChanged<String> onTextChanged;
  final ValueChanged<bool> onValidationChanged;

  @override
  Widget build(BuildContext context) {
    final InputDecoration inputDecoration = InputDecoration(
      hintText: title,
      hintStyle: TextStyle(color: shell.muted),
      filled: true,
      fillColor: shell.chipUnselectedBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(STRadius.md),
        borderSide: BorderSide(color: shell.chipUnselectedBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(STRadius.md),
        borderSide: BorderSide(color: shell.chipUnselectedBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(STRadius.md),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(STSpacing.lg),
      decoration: BoxDecoration(
        color: shell.surfaceCard,
        borderRadius: BorderRadius.circular(STRadius.xxl),
        border: Border.all(color: shell.surfaceCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (title == 'Name' || title == 'Bio') ...<Widget>[
            ContentValidationField(
              initialValue: currentText,
              hintText: title,
              maxLines: title == 'Bio' ? 6 : 1,
              maxLength: maxLength,
              onChanged: onTextChanged,
              onValidationChanged: onValidationChanged,
            ),
          ] else ...<Widget>[
            TextField(
              controller: textController,
              decoration: inputDecoration,
              style: TextStyle(color: shell.onChrome),
              maxLines: 6,
              minLines: 3,
              onChanged: onTextChanged,
            ),
          ],
          if (helperText != null) ...<Widget>[
            const SizedBox(height: STSpacing.md),
            Text(
              helperText!,
              style: TextStyle(color: shell.muted, fontSize: 12),
            ),
          ],
          const SizedBox(height: STSpacing.md),
          Row(
            children: <Widget>[
              Text(
                '${currentText.length}/$maxLength',
                style: TextStyle(color: shell.muted, fontSize: 12),
              ),
              const Spacer(),
              if (isRateLimited) ...<Widget>[
                Icon(Icons.timer_outlined,
                    color: colorScheme.tertiary, size: 16),
                const SizedBox(width: STSpacing.xs),
                Text(
                  'Rate limited',
                  style: TextStyle(color: colorScheme.tertiary, fontSize: 12),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
