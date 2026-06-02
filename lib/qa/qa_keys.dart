import 'package:flutter/material.dart';

/// Stable keys for integration/widget tests. Do not use for production logic.
abstract final class QaKeys {
  static const Key homeFeedSurface = Key('qa_home_feed_surface');
  static const Key homeFeedPageView = Key('qa_home_feed_page_view');
  static const Key feedSelectorButton = Key('qa_feed_selector_button');
  static const Key feedSelectorOverlay = Key('qa_feed_selector_overlay');
  static const Key feedSelectorBarrier = Key('qa_feed_selector_barrier');
  static const Key commandCenterTrigger = Key('qa_command_center_trigger');
  static const Key commandCenterOverlay = Key('qa_command_center_overlay');
  static const Key commandCenterDismiss = Key('qa_command_center_dismiss');
  static const Key bottomNavHome = Key('qa_bottom_nav_home');
  static const Key bottomNavNetwork = Key('qa_bottom_nav_network');

  static const Key authEmailUsernameOption =
      Key('qa_auth_email_username_option');
  static const Key authLoginEmailOrUsername =
      Key('qa_auth_login_email_or_username');
  static const Key authLoginPassword = Key('qa_auth_login_password');
  static const Key authLoginSubmit = Key('qa_auth_login_submit');

  static const Key authSignupEmail = Key('qa_auth_signup_email');
  static const Key authSignupUsername = Key('qa_auth_signup_username');
  static const Key authSignupPassword = Key('qa_auth_signup_password');
  static const Key authSignupConfirmPassword =
      Key('qa_auth_signup_confirm_password');
  static const Key authSignupSubmit = Key('qa_auth_signup_submit');

  static Key homeFeedVideoPage({
    required String tabId,
    required String videoId,
  }) =>
      ValueKey<String>('qa_home_feed_video_page_${tabId}_$videoId');
}
