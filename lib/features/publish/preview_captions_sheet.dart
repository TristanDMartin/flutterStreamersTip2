import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/feature_flags.dart';
import 'pending_post.dart';
import 'publish_flow_tokens.dart';

class PreviewCaptionsResult {
  const PreviewCaptionsResult({
    required this.captionsEnabled,
    required this.manualCaptionText,
  });

  final bool captionsEnabled;
  final String manualCaptionText;
}

class PreviewCaptionsSheet extends StatefulWidget {
  const PreviewCaptionsSheet({
    super.key,
    required this.initialEnabled,
    required this.initialText,
  });

  final bool initialEnabled;
  final String initialText;

  static Future<PreviewCaptionsResult?> show({
    required BuildContext context,
    required PendingPost pending,
  }) {
    return showModalBottomSheet<PreviewCaptionsResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: PreviewCaptionsSheet(
          initialEnabled: pending.captionsEnabled,
          initialText: pending.manualCaptionText,
        ),
      ),
    );
  }

  @override
  State<PreviewCaptionsSheet> createState() => _PreviewCaptionsSheetState();
}

class _PreviewCaptionsSheetState extends State<PreviewCaptionsSheet> {
  late bool _enabled;
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _enabled = widget.initialEnabled;
    _textController = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _save() {
    HapticFeedback.lightImpact();
    Navigator.of(context).pop(
      PreviewCaptionsResult(
        captionsEnabled: _enabled,
        manualCaptionText: _textController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
      decoration: PublishFlowTokens.glassPanel(radius: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text(
            'Captions',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Burn captions into video',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            subtitle: const Text(
              'Shown on preview and baked on publish',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            value: _enabled,
            activeThumbColor: PublishFlowTokens.primaryStart,
            onChanged: (value) => setState(() => _enabled = value),
          ),
          if (_enabled) ...<Widget>[
            const SizedBox(height: 8),
            TextField(
              controller: _textController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Caption text (bottom of frame)…',
                hintStyle:
                    TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.08),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: PublishFlowTokens.border),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Separate from Text overlays. Using both can look like double text.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 11,
              ),
            ),
          ],
          if (FeatureFlags.autoCaptions) ...<Widget>[
            const SizedBox(height: 12),
            _ComingSoonTile(
              title: 'Auto captions',
              subtitle: 'AI transcription',
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
              backgroundColor: PublishFlowTokens.primaryStart,
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('Save captions'),
          ),
        ],
      ),
    );
  }
}

class _ComingSoonTile extends StatelessWidget {
  const _ComingSoonTile({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PublishFlowTokens.border),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Soon',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
