import 'package:flutter/material.dart';

import '../core/theme/st_theme_tokens.dart';

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
  });

  final Widget content;
  final EdgeInsets contentPadding;
  final double minHeightBottomPadding;
  final bool showLoading;
  final String loadingText;
  final bool showAlert;
  final String alertMessage;
  final VoidCallback? onDismissAlert;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? <Color>[
                      StThemeColors.darkBackground,
                      scheme.surfaceContainerLow,
                      scheme.surface,
                    ]
                  : <Color>[
                      scheme.primary.withValues(alpha: 0.45),
                      scheme.surfaceContainerLow,
                      scheme.surface,
                    ],
            ),
          ),
          child: Stack(
            children: <Widget>[
              GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: SafeArea(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      contentPadding.left,
                      contentPadding.top,
                      contentPadding.right,
                      contentPadding.bottom +
                          MediaQuery.viewInsetsOf(context).bottom,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: MediaQuery.sizeOf(context).height -
                            MediaQuery.paddingOf(context).top -
                            MediaQuery.viewInsetsOf(context).bottom -
                            minHeightBottomPadding,
                      ),
                      child: content,
                    ),
                  ),
                ),
              ),
              if (showLoading)
                Container(
                  color: scheme.scrim.withValues(alpha: 0.35),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            scheme.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          loadingText,
                          style: TextStyle(
                            color: scheme.onSurface,
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
                    child: Container(
                      color: scheme.scrim.withValues(alpha: 0.45),
                    ),
                  ),
                ),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: AlertDialog(
                      backgroundColor: scheme.surfaceContainerHigh,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      title: Text(
                        'Error',
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      content: Text(
                        alertMessage.isEmpty
                            ? 'Something went wrong.'
                            : alertMessage,
                        style: TextStyle(
                          color: scheme.onSurface.withValues(alpha: 0.75),
                          height: 1.3,
                        ),
                      ),
                      actions: <Widget>[
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: scheme.primary,
                          ),
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
      ),
    );
  }
}
