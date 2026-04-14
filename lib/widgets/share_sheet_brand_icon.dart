import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/share_payload.dart';

/// White glyphs on colored circles (paths adapted from common icon sets).
class ShareSheetBrandIcon extends StatelessWidget {
  final ShareTarget target;
  final double size;

  const ShareSheetBrandIcon({
    super.key,
    required this.target,
    this.size = 26,
  });

  static const Color _white = Color(0xFFFFFFFF);

  @override
  Widget build(BuildContext context) {
    final String? assetPath = _assetPathFor(target);
    if (assetPath != null) {
      return SvgPicture.asset(
        assetPath,
        width: size,
        height: size,
        colorFilter: const ColorFilter.mode(_white, BlendMode.srcIn),
      );
    }
    return Icon(
      _fallbackIcon(target),
      color: _white,
      size: size,
    );
  }

  String? _assetPathFor(ShareTarget target) {
    switch (target) {
      case ShareTarget.copyLink:
        return 'assets/share_icons/link.svg';
      case ShareTarget.sms:
        return 'assets/share_icons/sms.svg';
      case ShareTarget.instagramDirect:
        return 'assets/share_icons/instagram.svg';
      case ShareTarget.whatsapp:
        return 'assets/share_icons/whatsapp.svg';
      case ShareTarget.facebook:
        return 'assets/share_icons/facebook.svg';
      case ShareTarget.more:
        return 'assets/share_icons/more.svg';
      case ShareTarget.repost:
      case ShareTarget.twitter:
      case ShareTarget.telegram:
      case ShareTarget.email:
        return null;
    }
  }

  IconData _fallbackIcon(ShareTarget target) {
    switch (target) {
      case ShareTarget.repost:
        return Icons.repeat;
      case ShareTarget.twitter:
        return Icons.flutter_dash;
      case ShareTarget.telegram:
        return Icons.send;
      case ShareTarget.email:
        return Icons.email;
      default:
        return Icons.share;
    }
  }
}
