import 'package:flutter/material.dart';

import 'auth_cinematic_background.dart';

/// Shared cinematic shell for the StreamersTip authentication journey.
class AuthCinematicShell extends StatelessWidget {
  const AuthCinematicShell({
    super.key,
    required this.content,
    this.contentPadding = const EdgeInsets.fromLTRB(24, 16, 24, 24),
    this.minHeightBottomPadding = 24,
    this.showLoading = false,
    this.loadingText = 'Loading...',
    this.showAlert = false,
    this.alertMessage = '',
    this.onDismissAlert,
    this.header,
    this.maxContentWidth = 520,
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
  final double maxContentWidth;

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    final double width = media.size.width;
    final double horizontalInset = width >= 900
        ? 48
        : width >= 600
            ? 36
            : contentPadding.left;
    final double topInset = width >= 600 ? contentPadding.top + 8 : contentPadding.top;
    final double bottomInset =
        width >= 600 ? contentPadding.bottom + 8 : contentPadding.bottom;

    return Material(
      color: Colors.transparent,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            const AuthCinematicBackground(),
            GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    horizontalInset,
                    topInset,
                    horizontalInset,
                    bottomInset + media.viewInsets.bottom,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: media.size.height -
                          media.padding.top -
                          media.viewInsets.bottom -
                          minHeightBottomPadding,
                    ),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxContentWidth),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            if (header != null) ...<Widget>[
                              header!,
                              const SizedBox(height: 8),
                            ],
                            content,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (showLoading)
              ColoredBox(
                color: Colors.black.withValues(alpha: 0.45),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF9F80FF),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        loadingText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (showAlert) ...<Widget>[
              Positioned.fill(
                child: GestureDetector(
                  onTap: onDismissAlert,
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.5),
                  ),
                ),
              ),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: AlertDialog(
                    backgroundColor: const Color(0xFF1A1F33),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: const Text(
                      'Notice',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    content: Text(
                      alertMessage.isEmpty
                          ? 'Something went wrong.'
                          : alertMessage,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        height: 1.3,
                      ),
                    ),
                    actions: <Widget>[
                      TextButton(
                        onPressed: onDismissAlert,
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
