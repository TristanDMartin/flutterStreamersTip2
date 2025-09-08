class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  static AnalyticsService get shared => _instance;
  AnalyticsService._internal();

  Future<void> setUserID(String userID) async {}
  Future<void> setUserProperty(String? value, String name) async {}
  Future<void> logScreen(String screenName, {String? screenClass}) async {}
  Future<void> logEvent(String name, {Map<String, dynamic>? parameters}) async {}
  Future<void> logLogin({required String method}) async {}
  Future<void> logSignUp({required String method}) async {}
  Future<void> logVideoView({required String videoID, String? videoTitle}) async {}
  Future<void> logVideoLike({required String videoID}) async {}
  Future<void> logVideoShare({required String videoID, required String shareMethod}) async {}
  Future<void> logProfileView({required String userID}) async {}
  Future<void> logTipSent({required double amount, required String recipientID}) async {}
  Future<void> logSearch({required String query, required int resultsCount}) async {}
  Future<void> logAppOpen() async {}
  Future<void> logError({required String error, required String context}) async {}
  Future<void> logPerformance({required String name, required Duration duration}) async {}
  Future<void> setCurrentScreen({required String screenName}) async {}
  Future<void> setAnalyticsCollectionEnabled(bool enabled) async {}
  Future<void> setSessionTimeoutDuration(Duration duration) async {}
  Future<void> logPurchase({required String productID, required double price, required String currency}) async {}
  Future<void> logAddToCart({required String productID, required double price, required String currency}) async {}
  Future<void> logTutorialBegin() async {}
  Future<void> logTutorialComplete() async {}
  Future<void> logTutorialStep({required int stepNumber, String? tutorialName}) async {}
  Future<void> setUserRole(String role) async {}
  Future<void> setUserSubscriptionType(String subscriptionType) async {}
  Future<void> setUserLocation(String location) async {}
  Future<void> setUserLanguage(String language) async {}
  Future<void> setUserDeviceType(String deviceType) async {}
  Future<void> setUserAppVersion(String appVersion) async {}
}

extension AnalyticsServiceExtension on AnalyticsService {
  Future<void> logButtonTap({required String buttonName, required String screenName, Map<String, dynamic>? additionalParams}) async {}
  Future<void> logNavigation({required String fromScreen, required String toScreen, String? navigationMethod}) async {}
  Future<void> logFeatureUsage({required String featureName, required String screenName, Map<String, dynamic>? additionalParams}) async {}
}
