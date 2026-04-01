import 'package:freezed_annotation/freezed_annotation.dart';

part 'social_link.freezed.dart';

@freezed
sealed class SocialLink with _$SocialLink {
  const factory SocialLink({
    required String id,
    required SocialLinkType type,
    required String url,
  }) = _SocialLink;
}

enum SocialLinkType {
  website,
  email,
  linkedin,
  github,
  patreon,
  koFi,
  discord;

  String get icon {
    switch (this) {
      case SocialLinkType.website:
        return "globe";
      case SocialLinkType.email:
        return "envelope";
      case SocialLinkType.linkedin:
        return "person.2.fill";
      case SocialLinkType.github:
        return "chevron.left.forwardslash.chevron.right";
      case SocialLinkType.patreon:
        return "heart.fill";
      case SocialLinkType.koFi:
        return "cup.and.saucer.fill";
      case SocialLinkType.discord:
        return "message.fill";
    }
  }
}
