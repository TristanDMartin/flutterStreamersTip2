/// Official StreamersTip system account — keep in sync with
/// `streamerstipReact/utils/systemConstants.ts`.
library;

const String kStreamersTipSystemUserId = 'STREAMERTIP_SYSTEM';
const String kStreamersTipSystemUsername = 'StreamersTip';
const String kStreamersTipSystemDisplayName = 'StreamersTip';

bool isSystemAccount(String? userId) {
  final String id = (userId ?? '').trim();
  return id == kStreamersTipSystemUserId;
}
