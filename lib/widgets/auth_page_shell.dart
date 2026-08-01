import 'package:flutter/material.dart';

import 'auth/auth_cinematic_shell.dart';

class AuthPageShell extends StatelessWidget {
  const AuthPageShell({
    super.key,
    required this.content,
    required this.contentPadding,
    required this.minHeightBottomPadding,
    this.showLoading = false,
    this.loadingText = 'Loading...',
    this.showAlert = false,
    this.alertMessage = '',
    this.onDismissAlert,
    this.header,
  });

  final Widget content;
  final EdgeInsets contentPadding;
  final double minHeightBottomPadding;
  final bool showLoading;
  final String loadingText;
  final bool showAlert;
  final String alertMessage;
  final VoidCallback? onDismissAlert;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    return AuthCinematicShell(
      content: content,
      contentPadding: contentPadding,
      minHeightBottomPadding: minHeightBottomPadding,
      showLoading: showLoading,
      loadingText: loadingText,
      showAlert: showAlert,
      alertMessage: alertMessage,
      onDismissAlert: onDismissAlert,
      header: header,
    );
  }
}
