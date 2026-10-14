import 'package:flutter/material.dart';

/// Represents a text overlay on a video
class VideoTextOverlay {
  VideoTextOverlay({
    required this.id,
    required this.text,
    this.position = const Offset(0.5, 0.5),
    this.fontSize = 24.0,
    this.color = Colors.white,
    this.backgroundColor,
    this.fontWeight = FontWeight.bold,
    this.alignment = TextAlign.center,
    this.rotation = 0.0,
    this.scale = 1.0,
    this.startTime = Duration.zero,
    this.endTime,
  });

  final String id;
  final String text;
  final Offset position; // Normalized 0.0-1.0
  final double fontSize;
  final Color color;
  final Color? backgroundColor;
  final FontWeight fontWeight;
  final TextAlign alignment;
  final double rotation; // radians
  final double scale;
  final Duration startTime;
  final Duration? endTime;

  VideoTextOverlay copyWith({
    String? text,
    Offset? position,
    double? fontSize,
    Color? color,
    Color? backgroundColor,
    FontWeight? fontWeight,
    TextAlign? alignment,
    double? rotation,
    double? scale,
    Duration? startTime,
    Duration? endTime,
  }) {
    return VideoTextOverlay(
      id: id,
      text: text ?? this.text,
      position: position ?? this.position,
      fontSize: fontSize ?? this.fontSize,
      color: color ?? this.color,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      fontWeight: fontWeight ?? this.fontWeight,
      alignment: alignment ?? this.alignment,
      rotation: rotation ?? this.rotation,
      scale: scale ?? this.scale,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'positionX': position.dx,
        'positionY': position.dy,
        'fontSize': fontSize,
        'color': color.toARGB32(),
        'backgroundColor': backgroundColor?.toARGB32(),
        'fontWeight': fontWeight.value,
        'alignment': alignment.index,
        'rotation': rotation,
        'scale': scale,
        'startTimeMs': startTime.inMilliseconds,
        'endTimeMs': endTime?.inMilliseconds,
      };

  factory VideoTextOverlay.fromJson(Map<String, dynamic> json) {
    return VideoTextOverlay(
      id: json['id'] as String,
      text: json['text'] as String,
      position: Offset(
        (json['positionX'] as num).toDouble(),
        (json['positionY'] as num).toDouble(),
      ),
      fontSize: (json['fontSize'] as num).toDouble(),
      color: Color(json['color'] as int),
      backgroundColor: json['backgroundColor'] != null
          ? Color(json['backgroundColor'] as int)
          : null,
      fontWeight: FontWeight.values[json['fontWeight'] as int],
      alignment: TextAlign.values[json['alignment'] as int],
      rotation: (json['rotation'] as num).toDouble(),
      scale: (json['scale'] as num).toDouble(),
      startTime: Duration(milliseconds: json['startTimeMs'] as int),
      endTime: json['endTimeMs'] != null
          ? Duration(milliseconds: json['endTimeMs'] as int)
          : null,
    );
  }
}
