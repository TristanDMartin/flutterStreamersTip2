// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'share_action.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ShareActionImpl _$$ShareActionImplFromJson(Map<String, dynamic> json) =>
    _$ShareActionImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      iconName: json['iconName'] as String,
      iconColor:
          const ColorConverter().fromJson((json['iconColor'] as num).toInt()),
      backgroundColor: const ColorConverter()
          .fromJson((json['backgroundColor'] as num).toInt()),
    );

Map<String, dynamic> _$$ShareActionImplToJson(_$ShareActionImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'iconName': instance.iconName,
      'iconColor': const ColorConverter().toJson(instance.iconColor),
      'backgroundColor':
          const ColorConverter().toJson(instance.backgroundColor),
    };
