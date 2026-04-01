import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/material.dart';
import 'json_converters.dart';

part 'share_action.freezed.dart';
part 'share_action.g.dart';

@freezed
sealed class ShareAction with _$ShareAction {
  const factory ShareAction({
    required String id,
    required String name,
    required String iconName,
    @ColorConverter() required Color iconColor,
    @ColorConverter() required Color backgroundColor,
  }) = _ShareAction;

  factory ShareAction.fromJson(Map<String, dynamic> json) => _$ShareActionFromJson(json);
}

// Extension for sample data
extension ShareActionExtension on ShareAction {
  static List<ShareAction> get samples => [
    const ShareAction(
      id: '1',
      name: 'Add to story',
      iconName: 'plus',
      iconColor: Colors.white,
      backgroundColor: Color(0x80000000), // gray.opacity(0.5)
    ),
    const ShareAction(
      id: '2',
      name: 'Copy link',
      iconName: 'link',
      iconColor: Colors.white,
      backgroundColor: Color(0x80000000), // gray.opacity(0.5)
    ),
    const ShareAction(
      id: '3',
      name: 'WhatsApp',
      iconName: 'bubble_left_fill',
      iconColor: Colors.white,
      backgroundColor: Colors.green,
    ),
    const ShareAction(
      id: '4',
      name: 'Messages',
      iconName: 'message_fill',
      iconColor: Colors.white,
      backgroundColor: Colors.blue,
    ),
    const ShareAction(
      id: '5',
      name: 'Share to...',
      iconName: 'share',
      iconColor: Colors.white,
      backgroundColor: Color(0x80000000), // gray.opacity(0.5)
    ),
  ];
}
