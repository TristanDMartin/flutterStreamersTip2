import '../components/onboarding/onboarding_models.dart';
import '../models/user.dart' as app_user;

/// In-memory stale-while-revalidate cache for instant tab navigation.
class AppSessionCache {
  AppSessionCache._();
  static final AppSessionCache instance = AppSessionCache._();

  static const Duration profileTtl = Duration(minutes: 30);
  static const Duration countsTtl = Duration(minutes: 10);
  static const Duration onboardingTtl = Duration(hours: 12);
  static const Duration settingsTtl = Duration(minutes: 30);

  final Map<String, _CacheEntry<app_user.User>> _profiles =
      <String, _CacheEntry<app_user.User>>{};
  final Map<String, _CacheEntry<Map<String, dynamic>>> _settings =
      <String, _CacheEntry<Map<String, dynamic>>>{};
  final Map<String, _CacheEntry<OnboardingState>> _onboarding =
      <String, _CacheEntry<OnboardingState>>{};
  final Map<String, _CacheEntry<Map<String, int>>> _followCounts =
      <String, _CacheEntry<Map<String, int>>>{};

  T? _peekEntry<T>(Map<String, _CacheEntry<T>> store, String key) {
    final String normalized = key.trim();
    if (normalized.isEmpty) {
      return null;
    }
    return store[normalized]?.value;
  }

  bool _isFreshEntry<T>(
    Map<String, _CacheEntry<T>> store,
    String key, {
    required Duration ttl,
  }) {
    final String normalized = key.trim();
    final _CacheEntry<T>? entry = store[normalized];
    if (entry == null) {
      return false;
    }
    return DateTime.now().difference(entry.cachedAt) <= ttl;
  }

  void putProfile(String userId, app_user.User user) {
    _profiles[userId.trim()] = _CacheEntry<app_user.User>(
      value: user,
      cachedAt: DateTime.now(),
    );
  }

  app_user.User? peekProfile(String userId) {
    return _peekEntry(_profiles, userId);
  }

  bool hasFreshProfile(String userId) {
    return _isFreshEntry(_profiles, userId, ttl: profileTtl);
  }

  void putSettings(String userId, Map<String, dynamic> settings) {
    _settings[userId.trim()] = _CacheEntry<Map<String, dynamic>>(
      value: Map<String, dynamic>.from(settings),
      cachedAt: DateTime.now(),
    );
  }

  Map<String, dynamic>? peekSettings(String userId) {
    return _peekEntry(_settings, userId);
  }

  void putOnboarding(String userId, OnboardingState state) {
    _onboarding[userId.trim()] = _CacheEntry<OnboardingState>(
      value: state,
      cachedAt: DateTime.now(),
    );
  }

  OnboardingState? peekOnboarding(String userId) {
    return _peekEntry(_onboarding, userId);
  }

  void putFollowCounts(
    String userId, {
    required int followerCount,
    required int followingCount,
  }) {
    _followCounts[userId.trim()] = _CacheEntry<Map<String, int>>(
      value: <String, int>{
        'followerCount': followerCount,
        'followingCount': followingCount,
      },
      cachedAt: DateTime.now(),
    );
  }

  Map<String, int>? peekFollowCounts(String userId) {
    return _peekEntry(_followCounts, userId);
  }

  void clearUser(String userId) {
    final String key = userId.trim();
    _profiles.remove(key);
    _settings.remove(key);
    _onboarding.remove(key);
    _followCounts.remove(key);
  }

  void clearAll() {
    _profiles.clear();
    _settings.clear();
    _onboarding.clear();
    _followCounts.clear();
  }
}

class _CacheEntry<T> {
  const _CacheEntry({
    required this.value,
    required this.cachedAt,
  });

  final T value;
  final DateTime cachedAt;
}
