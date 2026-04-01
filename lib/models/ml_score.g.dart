// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ml_score.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MLScore _$MLScoreFromJson(Map<String, dynamic> json) => _MLScore(
      value: (json['value'] as num).toDouble(),
      type: json['type'] as String,
    );

Map<String, dynamic> _$MLScoreToJson(_MLScore instance) => <String, dynamic>{
      'value': instance.value,
      'type': instance.type,
    };
