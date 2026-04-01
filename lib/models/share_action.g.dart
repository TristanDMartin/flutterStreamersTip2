// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'share_action.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ShareAction _$ShareActionFromJson(Map<String, dynamic> json) => _ShareAction(
      id: json['id'] as String,
      name: json['name'] as String,
      iconName: json['iconName'] as String,
      iconColor:
          const ColorConverter().fromJson((json['iconColor'] as num).toInt()),
      backgroundColor: const ColorConverter()
          .fromJson((json['backgroundColor'] as num).toInt()),
    );

Map<String, dynamic> _$ShareActionToJson(_ShareAction instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'iconName': instance.iconName,
      'iconColor': const ColorConverter().toJson(instance.iconColor),
      'backgroundColor':
          const ColorConverter().toJson(instance.backgroundColor),
    };
