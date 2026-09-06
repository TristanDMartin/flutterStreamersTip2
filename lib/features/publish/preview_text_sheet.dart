import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/video_filmstrip_cache.dart';
import 'pending_post.dart';
import 'publish_flow_tokens.dart';
import 'video_draft.dart';

/// StreamersTip text font tokens (licensed / system stacks).
const List<String> kStreamersTipTextFonts = <String>[
  'Classic',
  'Modern',
  'Bold',
  'Serif',
  'Rounded',
  'Mono',
];

class PreviewTextEditResult {
  const PreviewTextEditResult({
    required this.layer,
    this.delete = false,
  });

  final PendingTextLayer layer;
  final bool delete;
}

/// Text overlay editor: fonts, size, color, alignment, timing.
class PreviewTextSheet extends StatefulWidget {
  const PreviewTextSheet({
    super.key,
    required this.initial,
    required this.trimStart,
    required this.trimEnd,
  });

  final PendingTextLayer initial;
  final Duration trimStart;
  final Duration trimEnd;

  static Future<PreviewTextEditResult?> show({
    required BuildContext context,
    required PendingTextLayer initial,
    required Duration trimStart,
    required Duration trimEnd,
  }) {
    return showModalBottomSheet<PreviewTextEditResult?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return PreviewTextSheet(
          initial: initial,
          trimStart: trimStart,
          trimEnd: trimEnd,
        );
      },
    );
  }

  @override
  State<PreviewTextSheet> createState() => _PreviewTextSheetState();
}

class _PreviewTextSheetState extends State<PreviewTextSheet> {
  late final TextEditingController _controller;
  late String _fontFamily;
  late double _fontSize;
  late int _colorValue;
  late TextAlign _alignment;
  late double _startSeconds;
  late double _endSeconds;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial.text);
    _fontFamily = widget.initial.fontFamily;
    _fontSize = widget.initial.fontSize;
    _colorValue = widget.initial.colorValue;
    _alignment = widget.initial.alignment;
    _startSeconds = (widget.initial.start ?? widget.trimStart)
            .inMilliseconds /
        1000.0;
    _endSeconds =
        (widget.initial.end ?? widget.trimEnd).inMilliseconds / 1000.0;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    HapticFeedback.lightImpact();
    final String text = _controller.text.trim();
    if (text.isEmpty) {
      Navigator.of(context).pop(
        PreviewTextEditResult(layer: widget.initial, delete: true),
      );
      return;
    }
    Navigator.of(context).pop(
      PreviewTextEditResult(
        layer: widget.initial.copyWith(
          text: text,
          fontFamily: _fontFamily,
          fontSize: _fontSize,
          colorValue: _colorValue,
          alignment: _alignment,
          start: Duration(milliseconds: (_startSeconds * 1000).round()),
          end: Duration(milliseconds: (_endSeconds * 1000).round()),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double bottom = MediaQuery.paddingOf(context).bottom;
    final double keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final double minSec = widget.trimStart.inMilliseconds / 1000.0;
    final double maxSec = widget.trimEnd.inMilliseconds / 1000.0;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
        decoration: PublishFlowTokens.glassPanel(radius: 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text(
                'Text',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                autofocus: true,
                maxLines: 3,
                maxLength: 120,
                style: TextStyle(
                  color: Color(_colorValue),
                  fontSize: 18,
                  fontWeight: _fontFamily == 'Bold'
                      ? FontWeight.w800
                      : FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: 'Type something...',
                  hintStyle:
                      TextStyle(color: Colors.white.withValues(alpha: 0.35)),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: PublishFlowTokens.border),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: <Widget>[
                    for (final String font in kStreamersTipTextFonts)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(font),
                          selected: _fontFamily == font,
                          onSelected: (_) {
                            setState(() => _fontFamily = font);
                          },
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  const Text('Size', style: TextStyle(color: Colors.white70)),
                  Expanded(
                    child: Slider(
                      value: _fontSize.clamp(16, 64),
                      min: 16,
                      max: 64,
                      onChanged: (double value) {
                        setState(() => _fontSize = value);
                      },
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                children: <Widget>[
                  for (final int color in <int>[
                    0xFFFFFFFF,
                    0xFFFFEB3B,
                    0xFFFF5252,
                    0xFF69F0AE,
                    0xFF40C4FF,
                    0xFFFF4081,
                  ])
                    GestureDetector(
                      onTap: () => setState(() => _colorValue = color),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Color(color),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _colorValue == color
                                ? PublishFlowTokens.primaryStart
                                : Colors.white24,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  _AlignButton(
                    icon: Icons.format_align_left,
                    selected: _alignment == TextAlign.left,
                    onTap: () => setState(() => _alignment = TextAlign.left),
                  ),
                  _AlignButton(
                    icon: Icons.format_align_center,
                    selected: _alignment == TextAlign.center,
                    onTap: () => setState(() => _alignment = TextAlign.center),
                  ),
                  _AlignButton(
                    icon: Icons.format_align_right,
                    selected: _alignment == TextAlign.right,
                    onTap: () => setState(() => _alignment = TextAlign.right),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Duration on video',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              RangeSlider(
                values: RangeValues(
                  _startSeconds.clamp(minSec, maxSec),
                  _endSeconds.clamp(minSec, maxSec),
                ),
                min: minSec,
                max: maxSec <= minSec ? minSec + 1 : maxSec,
                onChanged: (RangeValues values) {
                  setState(() {
                    _startSeconds = values.start;
                    _endSeconds = values.end;
                  });
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pop(
                          PreviewTextEditResult(
                            layer: widget.initial,
                            delete: true,
                          ),
                        );
                      },
                      child: const Text(
                        'Delete',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  ),
                  Expanded(
                    child: FilledButton(
                      onPressed: _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: PublishFlowTokens.primaryStart,
                      ),
                      child: const Text('Done'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlignButton extends StatelessWidget {
  const _AlignButton({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(
        icon,
        color: selected ? PublishFlowTokens.primaryStart : Colors.white54,
      ),
    );
  }
}

/// Cover frame picker with filmstrip thumbnails.
class PreviewCoverSheet extends StatefulWidget {
  const PreviewCoverSheet({
    super.key,
    required this.videoPath,
    required this.duration,
    required this.initialFrame,
    required this.trimStart,
    required this.trimEnd,
    this.onSeek,
  });

  final String videoPath;
  final Duration duration;
  final Duration initialFrame;
  final Duration trimStart;
  final Duration trimEnd;
  final ValueChanged<Duration>? onSeek;

  static Future<Duration?> show({
    required BuildContext context,
    required VideoDraft draft,
    ValueChanged<Duration>? onSeek,
  }) {
    return showModalBottomSheet<Duration?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return PreviewCoverSheet(
          videoPath: draft.sourceFilePath,
          duration: draft.duration,
          initialFrame: draft.coverFrameTime,
          trimStart: draft.trimStart,
          trimEnd: draft.trimEnd,
          onSeek: onSeek,
        );
      },
    );
  }

  @override
  State<PreviewCoverSheet> createState() => _PreviewCoverSheetState();
}

class _PreviewCoverSheetState extends State<PreviewCoverSheet> {
  static const int _thumbCount = 10;
  late double _frameSeconds;
  late List<Uint8List?> _thumbs;

  double get _min => widget.trimStart.inMilliseconds / 1000.0;
  double get _max {
    final double end = widget.trimEnd.inMilliseconds / 1000.0;
    return end > _min ? end : _min + 1;
  }

  @override
  void initState() {
    super.initState();
    final double initial = widget.initialFrame.inMilliseconds / 1000.0;
    _frameSeconds = initial.clamp(_min, _max);
    _thumbs = List<Uint8List?>.generate(_thumbCount, (int i) {
      final double t = _min + ((_max - _min) * i / (_thumbCount - 1));
      return VideoFilmstripCache.instance.peek(
        widget.videoPath,
        (t * 1000).round(),
      );
    });
    unawaited(_loadThumbs());
  }

  Future<void> _loadThumbs() async {
    await VideoFilmstripCache.instance.loadStrip(
      path: widget.videoPath,
      startSeconds: _min,
      endSeconds: _max,
      count: _thumbCount,
      onFrame: (int index, Uint8List? bytes) {
        if (!mounted || index < 0 || index >= _thumbs.length) {
          return;
        }
        setState(() => _thumbs[index] = bytes);
      },
    );
  }

  void _select(double seconds) {
    setState(() => _frameSeconds = seconds.clamp(_min, _max));
    widget.onSeek?.call(
      Duration(milliseconds: (_frameSeconds * 1000).round()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      decoration: PublishFlowTokens.glassPanel(radius: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text(
            'Choose cover',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 78,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _thumbs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (BuildContext context, int index) {
                final double t =
                    _min + ((_max - _min) * index / (_thumbCount - 1));
                final bool selected = (_frameSeconds - t).abs() < 0.2;
                final Uint8List? bytes = _thumbs[index];
                return GestureDetector(
                  onTap: () => _select(t),
                  child: Container(
                    width: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selected
                            ? PublishFlowTokens.primaryStart
                            : Colors.white24,
                        width: selected ? 2.5 : 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: bytes == null
                        ? const ColoredBox(color: Colors.white10)
                        : Image.memory(
                            bytes,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                          ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Slider(
            value: _frameSeconds.clamp(_min, _max),
            min: _min,
            max: _max,
            onChanged: _select,
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop(
                      Duration(milliseconds: (_frameSeconds * 1000).round()),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: PublishFlowTokens.primaryStart,
                  ),
                  child: const Text('Use frame'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
