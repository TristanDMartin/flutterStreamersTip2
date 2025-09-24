import 'package:flutter/material.dart';
import 'dart:io';
import '../services/logging_service.dart';

class VideoTimeline extends StatefulWidget {
  final Duration duration;
  final Duration position;
  final Duration startTime;
  final Duration endTime;
  final Function(Duration startTime, Duration endTime)? onTrimChanged;
  final Function(Duration position)? onSeekTo;
  final bool isDragging;
  final Function(bool isDragging)? onDraggingChanged;

  const VideoTimeline({
    super.key,
    required this.duration,
    required this.position,
    required this.startTime,
    required this.endTime,
    this.onTrimChanged,
    this.onSeekTo,
    this.isDragging = false,
    this.onDraggingChanged,
  });

  @override
  State<VideoTimeline> createState() => _VideoTimelineState();
}

class _VideoTimelineState extends State<VideoTimeline> {
  late Duration _startTime;
  late Duration _endTime;
  bool _isDraggingStart = false;
  bool _isDraggingEnd = false;
  bool _isDraggingPosition = false;

  @override
  void initState() {
    super.initState();
    _startTime = widget.startTime;
    _endTime = widget.endTime;
  }

  @override
  void didUpdateWidget(VideoTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startTime != widget.startTime || oldWidget.endTime != widget.endTime) {
      _startTime = widget.startTime;
      _endTime = widget.endTime;
    }
  }

  double _getPositionFromDuration(Duration duration) {
    if (widget.duration.inMilliseconds == 0) return 0.0;
    return duration.inMilliseconds / widget.duration.inMilliseconds;
  }

  Duration _getDurationFromPosition(double position) {
    final milliseconds = (position * widget.duration.inMilliseconds).round();
    return Duration(milliseconds: milliseconds);
  }

  void _onPanStart(DragStartDetails details, String handleType) {
    setState(() {
      switch (handleType) {
        case 'start':
          _isDraggingStart = true;
          break;
        case 'end':
          _isDraggingEnd = true;
          break;
        case 'position':
          _isDraggingPosition = true;
          break;
      }
    });
    widget.onDraggingChanged?.call(true);
  }

  void _onPanUpdate(DragUpdateDetails details, String handleType) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final localPosition = renderBox.globalToLocal(details.globalPosition);
    final width = renderBox.size.width;
    final position = (localPosition.dx / width).clamp(0.0, 1.0);
    final newDuration = _getDurationFromPosition(position);

    setState(() {
      switch (handleType) {
        case 'start':
          _startTime = newDuration;
          if (_startTime >= _endTime) {
            _startTime = Duration(milliseconds: _endTime.inMilliseconds - 1000);
          }
          break;
        case 'end':
          _endTime = newDuration;
          if (_endTime <= _startTime) {
            _endTime = Duration(milliseconds: _startTime.inMilliseconds + 1000);
          }
          break;
        case 'position':
          widget.onSeekTo?.call(newDuration);
          break;
      }
    });

    widget.onTrimChanged?.call(_startTime, _endTime);
  }

  void _onPanEnd(DragEndDetails details, String handleType) {
    setState(() {
      _isDraggingStart = false;
      _isDraggingEnd = false;
      _isDraggingPosition = false;
    });
    widget.onDraggingChanged?.call(false);
  }

  @override
  Widget build(BuildContext context) {
    final startPosition = _getPositionFromDuration(_startTime);
    final endPosition = _getPositionFromDuration(_endTime);
    final currentPosition = _getPositionFromDuration(widget.position);

    return Container(
      height: 60,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          // Background track
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            height: 20,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          
          // Trimmed area highlight
          Positioned(
            left: 20 + (startPosition * (MediaQuery.of(context).size.width - 80)),
            right: 20 + ((1 - endPosition) * (MediaQuery.of(context).size.width - 80)),
            top: 20,
            child: Container(
              height: 20,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          
          // Current position indicator
          Positioned(
            left: 20 + (currentPosition * (MediaQuery.of(context).size.width - 80)) - 1,
            top: 18,
            child: Container(
              width: 2,
              height: 24,
              decoration: BoxDecoration(
                color: const Color(0xFF9248D2),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
          
          // Start trim handle
          Positioned(
            left: 20 + (startPosition * (MediaQuery.of(context).size.width - 80)) - 10,
            top: 15,
            child: GestureDetector(
              onPanStart: (details) => _onPanStart(details, 'start'),
              onPanUpdate: (details) => _onPanUpdate(details, 'start'),
              onPanEnd: (details) => _onPanEnd(details, 'start'),
              child: Container(
                width: 20,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFF9248D2),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.drag_handle,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
          
          // End trim handle
          Positioned(
            left: 20 + (endPosition * (MediaQuery.of(context).size.width - 80)) - 10,
            top: 15,
            child: GestureDetector(
              onPanStart: (details) => _onPanStart(details, 'end'),
              onPanUpdate: (details) => _onPanUpdate(details, 'end'),
              onPanEnd: (details) => _onPanEnd(details, 'end'),
              child: Container(
                width: 20,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFF9248D2),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.drag_handle,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
          
          // Timeline tap area for seeking
          Positioned.fill(
            child: GestureDetector(
              onTapDown: (details) {
                final RenderBox renderBox = context.findRenderObject() as RenderBox;
                final localPosition = renderBox.globalToLocal(details.globalPosition);
                final width = renderBox.size.width;
                final position = (localPosition.dx / width).clamp(0.0, 1.0);
                final newDuration = _getDurationFromPosition(position);
                widget.onSeekTo?.call(newDuration);
              },
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class VideoTimelineThumbnail extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final File? videoFile;

  const VideoTimelineThumbnail({
    super.key,
    required this.position,
    required this.duration,
    this.videoFile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: videoFile != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: const Icon(
                Icons.videocam,
                color: Colors.white,
                size: 24,
              ),
            )
          : const Icon(
              Icons.video_library,
              color: Colors.white,
              size: 24,
            ),
    );
  }
}
