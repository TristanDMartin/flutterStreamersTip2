import 'package:flutter/material.dart';

import '../../publish/publish_flow_tokens.dart';
import '../tippy_publish_caption_helpers.dart';

/// Result for applying Tippy hashtag suggestions on New Post.
class TippySuggestHashtagsResult {
  const TippySuggestHashtagsResult({
    required this.mode,
    required this.selectedHashtags,
    required this.allHashtags,
  });

  final TippyHashtagApplyMode mode;
  final List<String> selectedHashtags;
  final List<String> allHashtags;
}

/// Multi-select hashtag sheet with Add All / Add Selected / Replace.
class TippySuggestHashtagsSheet extends StatefulWidget {
  const TippySuggestHashtagsSheet({
    super.key,
    required this.hashtags,
    this.creditsRemaining,
  });

  final List<String> hashtags;
  final int? creditsRemaining;

  static Future<TippySuggestHashtagsResult?> show(
    BuildContext context, {
    required List<String> hashtags,
    int? creditsRemaining,
  }) {
    return showModalBottomSheet<TippySuggestHashtagsResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111827),
      showDragHandle: true,
      builder: (BuildContext context) {
        return TippySuggestHashtagsSheet(
          hashtags: hashtags,
          creditsRemaining: creditsRemaining,
        );
      },
    );
  }

  @override
  State<TippySuggestHashtagsSheet> createState() =>
      _TippySuggestHashtagsSheetState();
}

class _TippySuggestHashtagsSheetState extends State<TippySuggestHashtagsSheet> {
  late final List<String> _allHashtags;
  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _allHashtags = normalizeTippyHashtags(widget.hashtags);
    _selected = _allHashtags.toSet();
  }

  void _toggleHashtag(String tag) {
    setState(() {
      if (_selected.contains(tag)) {
        _selected.remove(tag);
      } else {
        _selected.add(tag);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selected
        ..clear()
        ..addAll(_allHashtags);
    });
  }

  void _popResult(TippyHashtagApplyMode mode) {
    final List<String> selectedOrdered = _allHashtags
        .where((String tag) => _selected.contains(tag))
        .toList(growable: false);
    Navigator.of(context).pop(
      TippySuggestHashtagsResult(
        mode: mode,
        selectedHashtags: selectedOrdered,
        allHashtags: _allHashtags,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        16 + media.viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Suggested hashtags',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _allHashtags.isEmpty
                ? 'Tippy did not return hashtags for this draft.'
                : 'Tap to select tags, then choose how to apply them.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              height: 1.35,
            ),
          ),
          if (widget.creditsRemaining != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              '${widget.creditsRemaining} Tippy credits left',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (_allHashtags.isEmpty)
            Text(
              'Close and try Suggest hashtags again.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _allHashtags.map((String tag) {
                final bool isSelected = _selected.contains(tag);
                return FilterChip(
                  selected: isSelected,
                  label: Text(tag),
                  onSelected: (_) => _toggleHashtag(tag),
                  selectedColor:
                      PublishFlowTokens.primaryStart.withValues(alpha: 0.35),
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(
                    color: Colors.white.withValues(
                      alpha: isSelected ? 1 : 0.78,
                    ),
                    fontWeight: FontWeight.w700,
                  ),
                  side: BorderSide(
                    color: isSelected
                        ? PublishFlowTokens.primaryStart
                        : PublishFlowTokens.border,
                  ),
                  backgroundColor: PublishFlowTokens.surface,
                );
              }).toList(growable: false),
            ),
          if (_allHashtags.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            TextButton(
              onPressed: _selectAll,
              child: const Text('Select all'),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: _allHashtags.isEmpty
                      ? null
                      : () => _popResult(TippyHashtagApplyMode.addAll),
                  child: const Text('Add All'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _selected.isEmpty
                      ? null
                      : () => _popResult(TippyHashtagApplyMode.addSelected),
                  child: Text('Add Selected (${_selected.length})'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _allHashtags.isEmpty
                  ? null
                  : () => _popResult(TippyHashtagApplyMode.replace),
              child: const Text('Replace hashtags'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
  }
}
