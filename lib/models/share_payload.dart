import 'package:freezed_annotation/freezed_annotation.dart';

part 'share_payload.freezed.dart';
part 'share_payload.g.dart';

/// SharePayload - Prefetched data for instant share sheet display
///
/// Preloaded when video becomes active to ensure instant modal open
@freezed
class SharePayload with _$SharePayload {
  const factory SharePayload({
    required String videoId,
    required ShareLinks links,
    required SharePermissions permissions,
    required ShareMetadata metadata,
    String? trackingToken,
    @Default({}) Map<String, int> platformUsageRanking,
  }) = _SharePayload;

  factory SharePayload.fromJson(Map<String, dynamic> json) =>
      _$SharePayloadFromJson(json);
}

/// Share links for different platforms
@freezed
class ShareLinks with _$ShareLinks {
  const factory ShareLinks({
    required String webShareUrl,
    String? deepLink,
    String? downloadUrl,
    String? embedCode,
  }) = _ShareLinks;

  factory ShareLinks.fromJson(Map<String, dynamic> json) =>
      _$ShareLinksFromJson(json);
}

/// Share permissions for the video
@freezed
class SharePermissions with _$SharePermissions {
  const factory SharePermissions({
    @Default(true) bool canShare,
    @Default(true) bool canDownload,
    @Default(true) bool canDuet,
    @Default(true) bool canRemix,
    @Default(true) bool canRepost,
    String? restrictionReason,
  }) = _SharePermissions;

  factory SharePermissions.fromJson(Map<String, dynamic> json) =>
      _$SharePermissionsFromJson(json);
}

/// Metadata for share content
@freezed
class ShareMetadata with _$ShareMetadata {
  const factory ShareMetadata({
    required String creatorUsername,
    required String creatorDisplayName,
    String? caption,
    String? thumbnailUrl,
    @Default([]) List<String> hashtags,
    DateTime? createdAt,
  }) = _ShareMetadata;

  factory ShareMetadata.fromJson(Map<String, dynamic> json) =>
      _$ShareMetadataFromJson(json);
}

/// Share target platforms
enum ShareTarget {
  copyLink('Copy Link', 'link'),
  instagramDirect('Instagram', 'instagram'),
  sms('Messages', 'sms'),
  whatsapp('WhatsApp', 'whatsapp'),
  repost('Repost', 'repost'),
  facebook('Facebook', 'facebook'),
  twitter('Twitter', 'twitter'),
  telegram('Telegram', 'telegram'),
  email('Email', 'email'),
  more('More', 'more');

  const ShareTarget(this.displayName, this.analyticsName);

  final String displayName;
  final String analyticsName;
}

/// Contextual actions in share sheet
enum ShareAction {
  report('Report', 'report'),
  block('Block', 'block'),
  sendMessage('Send Message', 'send_message'),
  notInterested('Not Interested', 'not_interested'),
  favorite('Add to Favorites', 'favorite');

  const ShareAction(this.displayName, this.analyticsName);

  final String displayName;
  final String analyticsName;
}
