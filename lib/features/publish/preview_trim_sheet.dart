import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/video_filmstrip_cache.dart';
import 'publish_flow_tokens.dart';
import 'video_draft.dart';

/// Production trim editor: filmstrip + start/end handles + playhead seek.
class PreviewTrimSheet extends StatefulWidget {
  const PreviewTrimSheet({
    super.key,
    required this.videoPath,
    required this.duration,
    required this.initialStart,
    required this.initialEnd,
    this.onSeek,
  });

  final String videoPath;
  final Duration duration;
  final Duration initialStart;
  final Duration initialEnd;
  final ValueChanged<Duration>? onSeek;

  static Future<({Duration start, Duration end})?> show({
    required BuildContext context,
    required VideoDraft draft,
    ValueChanged<Duration>? onSeek,
  }) {
    return showModalBottomSheet<({Duration start, Duration end})?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => PreviewTrimSheet(
        videoPath: draft.sourceFilePath,
        duration: draft.duration,
        initialStart: draft.trimStart,
        initialEnd: draft.trimEnd,
        onSeek: onSeek,
      ),
    );
  }

  @override
  State<PreviewTrimSheet> createState() => _PreviewTrimSheetState();
}

class _PreviewTrimSheetState extends State<PreviewTrimSheet> {
  static const int _thumbCount = 12;

  late double _startSeconds;
  late double _endSeconds;
  late double _playheadSeconds;
  String? _errorText;
  late List<Uint8List?> _thumbs;
  bool _isDraggingHandle = false;

  double get _maxSeconds => widget.duration.inMilliseconds / 1000.0;

  @override
  void initState() {
    super.initState();
    final double max = _maxSeconds <= 0 ? 1 : _maxSeconds;
    _startSeconds =
        (widget.initialStart.inMilliseconds / 1000.0).clamp(0.0, max);
    _endSeconds = (widget.initialEnd.inMilliseconds / 1000.0).clamp(0.0, max);
    if (_endSeconds <= _startSeconds) {
      _endSeconds = max;
      _startSeconds = 0;
    }
    _playheadSeconds = _startSeconds;
    _thumbs = List<Uint8List?>.generate(_thumbCount, (int i) {
      final int timeMs = ((_maxSeconds <= 0 ? 0 : _maxSeconds) *
              i /
              (_thumbCount - 1) *
              1000)
          .round();
      return VideoFilmstripCache.instance.peek(widget.videoPath, timeMs);
    });
    unawaited(_loadThumbs());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _emitSeek(_startSeconds);
    });
  }

  Future<void> _loadThumbs() async {
    final double max = _maxSeconds <= 0 ? 1 : _maxSeconds;
    await VideoFilmstripCache.instance.loadStrip(
      path: widget.videoPath,
      startSeconds: 0,
      endSeconds: max,
      count: _thumbCount,
      onFrame: (int index, Uint8List? bytes) {
        if (!mounted || index < 0 || index >= _thumbs.length) {
          return;
        }
        setState(() => _thumbs[index] = bytes);
      },
    );
  }

  String _format(double seconds) {
    final int total = seconds.floor().clamp(0, 99999);
    final int minutes = total ~/ 60;
    final int secs = total % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  void _emitSeek(double seconds) {
    widget.onSeek?.call(
      Duration(milliseconds: (seconds * 1000).round()),
    );
  }

  bool _validate() {
    if (_endSeconds <= _startSeconds) {
      setState(() => _errorText = 'End must be after start.');
      return false;
    }
    if (_endSeconds - _startSeconds < 1) {
      setState(() => _errorText = 'Clip must be at least 1 second.');
      return false;
    }
    setState(() => _errorText = null);
    return true;
  }

  void _save() {
    if (!_validate()) {
      HapticFeedback.mediumImpact();
      return;
    }
    HapticFeedback.lightImpact();
    Navigator.of(context).pop((
      start: Duration(milliseconds: (_startSeconds * 1000).round()),
      end: Duration(milliseconds: (_endSeconds * 1000).round()),
    ));
  }

  void _scrubPlayhead(double localDx, double width, double max) {
    if (_isDraggingHandle) {
      return;
    }
    final double ratio = (localDx / width).clamp(0.0, 1.0);
    final double seconds = (ratio * max).clamp(_startSeconds, _endSeconds);
    setState(() => _playheadSeconds = seconds);
    _emitSeek(seconds);
  }

  @override
  Widget build(BuildContext context) {
    final double bottom = MediaQuery.paddingOf(context).bottom;
    final double max = _maxSeconds > 0 ? _maxSeconds : 1;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      decoration: PublishFlowTokens.glassPanel(radius: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text(
            'Trim',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_format(_startSeconds)}  →  ${_format(_endSeconds)}   ·   '
            '${_format(_endSeconds - _startSeconds)} selected',
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 72,
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double width = constraints.maxWidth;
                return Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onHorizontalDragUpdate: (DragUpdateDetails details) {
                          _scrubPlayhead(
                            details.localPosition.dx,
                            width,
                            max,
                          );
                        },
                        onTapDown: (TapDownDetails details) {
                          _scrubPlayhead(
                            details.localPosition.dx,
                            width,
                            max,
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Row(
                            children: <Widget>[
                              for (final Uint8List? bytes in _thumbs)
                                Expanded(
                                  child: bytes == null
                                      ? const ColoredBox(
                                          color: Colors.white10,
                                        )
                                      : Image.memory(
                                          bytes,
                                          fit: BoxFit.cover,
                                          height: 72,
                                          gaplessPlayback: true,
                                        ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      width: (_startSeconds / max) * width,
                      top: 0,
                      bottom: 0,
                      child: const IgnorePointer(
                        child: ColoredBox(color: Color(0x99000000)),
                      ),
                    ),
                    Positioned(
                      left: (_endSeconds / max) * width,
                      right: 0,
                      top: 0,
                      bottom: 0,
                      child: const IgnorePointer(
                        child: ColoredBox(color: Color(0x99000000)),
                      ),
                    ),
                    Positioned(
                      left: (_startSeconds / max) * width,
                      width: ((_endSeconds - _startSeconds) / max) * width,
                      top: 0,
                      bottom: 0,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: PublishFlowTokens.primaryStart,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: (_playheadSeconds / max) * width - 1,
                      top: 0,
                      bottom: 0,
                      child: const IgnorePointer(
                        child: ColoredBox(
                          color: Colors.white,
                          child: SizedBox(width: 2),
                        ),
                      ),
                    ),
                    _Handle(
                      x: (_startSeconds / max) * width,
                      label: 'Start',
                      onDragStart: () {
                        setState(() => _isDraggingHandle = true);
                      },
                      onDragEnd: () {
                        setState(() => _isDraggingHandle = false);
                      },
                      onDrag: (double dx) {
                        final double next =
                            _startSeconds + (dx / width) * max;
                        setState(() {
                          _startSeconds =
                              next.clamp(0.0, _endSeconds - 1.0);
                          _playheadSeconds = _startSeconds;
                          _errorText = null;
                        });
                        _emitSeek(_startSeconds);
                      },
                    ),
                    _Handle(
                      x: (_endSeconds / max) * width,
                      label: 'End',
                      onDragStart: () {
                        setState(() => _isDraggingHandle = true);
                      },
                      onDragEnd: () {
                        setState(() => _isDraggingHandle = false);
                      },
                      onDrag: (double dx) {
                        final double next =
                            _endSeconds + (dx / width) * max;
                        setState(() {
                          _endSeconds =
                              next.clamp(_startSeconds + 1.0, max);
                          _playheadSeconds = _endSeconds;
                          _errorText = null;
                        });
                        _emitSeek(_endSeconds);
                      },
                    ),
                  ],
                );
              },
            ),
          ),
          if (_errorText != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              _errorText!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ],
          const SizedBox(height: 14),
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
              const SizedBox(width: 10),
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
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle({
    required this.x,
    required this.label,
    required this.onDrag,
    required this.onDragStart,
    required this.onDragEnd,
  });

  final double x;
  final String label;
  final ValueChanged<double> onDrag;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: x - 18,
      top: -4,
      bottom: -4,
      width: 36,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) => onDragStart(),
        onHorizontalDragEnd: (_) => onDragEnd(),
        onHorizontalDragCancel: onDragEnd,
        onHorizontalDragUpdate: (DragUpdateDetails details) {
          onDrag(details.delta.dx);
        },
        child: Center(
          child: Semantics(
            label: label,
            child: Container(
              width: 16,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
