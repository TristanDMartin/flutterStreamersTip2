import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/core/backend/site_api_base.dart';

void main() {
  test('avatar persist URLs hit production Hosting paths', () {
    expect(
      siteAvatarSaveUrl(base: 'https://streamerstip.com'),
      'https://streamerstip.com/api/avatar/save',
    );
    expect(
      siteAvatarSyncUrl(base: 'https://streamerstip.com'),
      'https://streamerstip.com/api/avatar/sync',
    );
    expect(
      siteTippyCreditsUrl(base: 'https://streamerstip.com'),
      'https://streamerstip.com/api/tippy/credits',
    );
    expect(
      siteTippyCreatorMemoryUrl(base: 'https://streamerstip.com'),
      'https://streamerstip.com/api/tippy/creator-memory',
    );
    expect(
      siteAuthResolveLoginUrl(base: 'https://streamerstip.com'),
      'https://streamerstip.com/api/auth/resolve-login',
    );
  });
}
