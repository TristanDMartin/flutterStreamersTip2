import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:streamers_tip/utils/secure_log.dart';

class VideoPlayerCreatorAvatar extends StatelessWidget {
  const VideoPlayerCreatorAvatar({
    super.key,
    required this.avatarUrl,
    required this.username,
    this.size = 42,
    this.showBorder = false,
  });

  final String? avatarUrl;
  final String username;
  final double size;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    if (avatarUrl == null || avatarUrl!.isEmpty) {
      return _VideoPlayerCreatorAvatarPlaceholder(
        size: size,
        iconSize: showBorder ? size * 0.5 : 20,
      );
    }

    return CachedNetworkImage(
      imageUrl: avatarUrl!,
      width: size,
      height: size,
      imageBuilder: (BuildContext context, ImageProvider<Object> imageProvider) {
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: showBorder
                ? Border.all(
                    color: Colors.white.withValues(alpha: 0.65),
                    width: 1.6,
                  )
                : null,
            image: DecorationImage(
              image: imageProvider,
              fit: BoxFit.cover,
            ),
          ),
        );
      },
      placeholder: (BuildContext context, String url) {
        return _VideoPlayerCreatorAvatarPlaceholder(
          size: size,
          iconSize: showBorder ? size * 0.5 : 20,
        );
      },
      errorWidget: (BuildContext context, String url, Object error) {
        secureLog('❌ Avatar load error for $username: $error');
        return _VideoPlayerCreatorAvatarPlaceholder(
          size: size,
          iconSize: showBorder ? size * 0.5 : 20,
        );
      },
    );
  }
}

class _VideoPlayerCreatorAvatarPlaceholder extends StatelessWidget {
  const _VideoPlayerCreatorAvatarPlaceholder({
    required this.size,
    required this.iconSize,
  });

  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          colors: <Color>[
            Color(0xFFFF6CAB),
            Color(0xFF8E54E9),
            Color(0xFF3D99F7),
            Color(0xFFFF6CAB),
          ],
        ),
      ),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey,
        ),
        child: Icon(
          Icons.person,
          color: Colors.white,
          size: iconSize,
        ),
      ),
    );
  }
}
