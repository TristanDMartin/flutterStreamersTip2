import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/st_theme_tokens.dart';

/// 58px avatar with purple→blue ring, optional live dot, initials fallback.
class CreatorAvatarRing extends StatelessWidget {
  const CreatorAvatarRing({
    super.key,
    required this.avatarUrl,
    required this.username,
    required this.isLive,
    this.size = 58,
    this.ringWidth = 3,
  });

  final String? avatarUrl;
  final String username;
  final bool isLive;
  final double size;
  final double ringWidth;

  @override
  Widget build(BuildContext context) {
    final String initial =
        username.isNotEmpty ? username.trim()[0].toUpperCase() : '?';
    final Widget inner = ClipOval(
      child: SizedBox(
        width: size - ringWidth * 2,
        height: size - ringWidth * 2,
        child: _buildAvatarFill(initial),
      ),
    );
    return SizedBox(
      width: size + (isLive ? 6 : 0),
      height: size + (isLive ? 6 : 0),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: <Widget>[
          Container(
            width: size,
            height: size,
            padding: EdgeInsets.all(ringWidth),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: StThemeColors.gradient,
            ),
            child: inner,
          ),
          if (isLive)
            Positioned(
              right: 0,
              bottom: 2,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: StThemeColors.success,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatarFill(String initial) {
    final String? url = avatarUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        errorWidget: (BuildContext c, String u, Object e) =>
            _InitialsAvatar(initial: initial),
        placeholder: (BuildContext c, String u) => ColoredBox(
          color: StThemeColors.darkSurface.withValues(alpha: 0.9),
          child: Center(
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      );
    }
    return _InitialsAvatar(initial: initial);
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: StThemeColors.darkCard.withValues(alpha: 0.95),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
