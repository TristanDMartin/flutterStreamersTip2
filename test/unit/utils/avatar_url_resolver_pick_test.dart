import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/utils/avatar_url_resolver.dart';

void main() {
  test('pickBestAvatarUrl prefers https over relative storage path', () {
    final String? actual = pickBestAvatarUrl(
      'avatars/user/photo.jpg',
      'https://cdn.example.com/a.jpg',
    );
    expect(actual, 'https://cdn.example.com/a.jpg');
  });

  test('pickBestAvatarUrl keeps preferred https when valid', () {
    final String? actual = pickBestAvatarUrl(
      'https://cdn.example.com/live.jpg',
      'https://cdn.example.com/fallback.jpg',
    );
    expect(actual, 'https://cdn.example.com/live.jpg');
  });

  test('isNetworkAvatarUrl rejects bare storage paths', () {
    expect(isNetworkAvatarUrl('avatars/user/photo.jpg'), isFalse);
    expect(isNetworkAvatarUrl('https://cdn.example.com/a.jpg'), isTrue);
  });
}
