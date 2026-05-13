import 'package:flutter/material.dart';

/// Stable keys for integration/widget tests. Do not use for production logic.
abstract final class QaKeys {
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
}
