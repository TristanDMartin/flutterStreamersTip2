import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'pending_post.dart';
import 'publish_flow_tokens.dart';

class PreviewTrimSheet extends StatefulWidget {
  const PreviewTrimSheet({
    super.key,
    required this.duration,
    required this.initialStart,
    required this.initialEnd,
  });

  final Duration duration;
  final Duration initialStart;
  final Duration initialEnd;

  static Future<({Duration start, Duration end})?> show({
    required BuildContext context,
    required PendingPost pending,
  }) {
    return showModalBottomSheet<({Duration start, Duration end})?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PreviewTrimSheet(
        duration: pending.duration,
        initialStart: pending.trimStart,
        initialEnd: pending.trimEnd,
      ),
    );
  }

  @override
  State<PreviewTrimSheet> createState() => _PreviewTrimSheetState();
}

class _PreviewTrimSheetState extends State<PreviewTrimSheet> {
  late double _startSeconds;
  late double _endSeconds;
  String? _errorText;

  double get _maxSeconds => widget.duration.inMilliseconds / 1000.0;

  @override
  void initState() {
    super.initState();
    _startSeconds = widget.initialStart.inMilliseconds / 1000.0;
    _endSeconds = widget.initialEnd.inMilliseconds / 1000.0;
  }

  String _format(double seconds) {
    final int total = seconds.floor();
    final int minutes = total ~/ 60;
    final int secs = total % 60;
    final int tenths = ((seconds - total) * 10).round();
    return '$minutes:${secs.toString().padLeft(2, '0')}.$tenths';
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
            'Trim clip',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Total ${_format(_maxSeconds)} · Selected '
            '${_format(_endSeconds - _startSeconds)}',
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              _TimeLabel(label: 'Start', value: _format(_startSeconds)),
              _TimeLabel(label: 'End', value: _format(_endSeconds)),
            ],
          ),
          RangeSlider(
            values: RangeValues(
              _startSeconds.clamp(0, _maxSeconds),
              _endSeconds.clamp(0, _maxSeconds),
            ),
            min: 0,
            max: _maxSeconds > 0 ? _maxSeconds : 1,
            activeColor: PublishFlowTokens.primaryStart,
            inactiveColor: Colors.white24,
            onChanged: (values) {
              setState(() {
                _startSeconds = values.start;
                _endSeconds = values.end;
                _errorText = null;
              });
            },
          ),
          if (_errorText != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              _errorText!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: PublishFlowTokens.primaryStart,
                  ),
                  child: const Text('Save trim'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimeLabel extends StatelessWidget {
  const _TimeLabel({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
