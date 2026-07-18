/// Flutter framework errors that are expected during Google OAuth /
/// MainTabView mount/teardown and must not surface as red UI or snackbars.
bool isIgnorableAuthTransitionFlutterError(Object? error) {
  if (error == null) {
    return false;
  }
  final String text = error.toString();
  return text.contains('deactivated widget') ||
      text.contains('modify a provider while the widget tree was building') ||
      text.contains('AccountClientException') ||
      text.contains('not available in the current deployment');
}
