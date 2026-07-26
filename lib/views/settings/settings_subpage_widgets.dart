import 'package:flutter/material.dart';

import '../../core/theme/support_shell_style.dart';
import '../../widgets/screen_feedback_state.dart';

/// Theme-aware shell and form rows for Settings sub-pages.
abstract final class SettingsSubpageWidgets {
  static Widget shell({
    required BuildContext context,
    required String title,
    required Widget body,
    bool isLoading = false,
    bool isSaving = false,
    String? loadError,
    VoidCallback? onRetryLoad,
    String? actionError,
    VoidCallback? onDismissActionError,
    VoidCallback? onRetryAction,
  }) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: shell.pageGradient,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: shell.onChrome),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            title,
            style: TextStyle(
              color: shell.onChrome,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
        ),
        body: isLoading
            ? Center(
                child: CircularProgressIndicator(color: cs.primary),
              )
            : loadError != null
                ? ScreenErrorState(
                    title: 'Couldn’t load settings',
                    message: loadError,
                    onRetry: onRetryLoad,
                  )
                : Column(
                    children: <Widget>[
                      if (isSaving)
                        LinearProgressIndicator(
                          backgroundColor: cs.surfaceContainerLow,
                          color: cs.primary,
                        ),
                      if (actionError != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: ScreenInlineErrorBanner(
                            message: actionError,
                            onDismiss: onDismissActionError,
                            onRetry: onRetryAction,
                          ),
                        ),
                      Expanded(child: body),
                    ],
                  ),
      ),
    );
  }

  static Widget section({
    required BuildContext context,
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: TextStyle(
            color: shell.onChrome,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (subtitle != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: shell.muted,
              fontSize: 14,
            ),
          ),
        ],
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: shell.surfaceCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: shell.surfaceCardBorder),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: shell.shadowSoft,
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  static Widget switchRow({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool showDivider = true,
  }) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                bottom: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.45),
                ),
              )
            : null,
      ),
      child: Row(
        children: <Widget>[
          _iconBadge(context, icon),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(
                    color: shell.onChrome,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: shell.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  static Widget dropdownRow({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
    String Function(String option)? labelForOption,
    bool showDivider = true,
  }) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final String Function(String option) format =
        labelForOption ?? _formatOption;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                bottom: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.45),
                ),
              )
            : null,
      ),
      child: Row(
        children: <Widget>[
          _iconBadge(context, icon),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(
                    color: shell.onChrome,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: shell.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: shell.chipUnselectedBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: shell.chipUnselectedBorder),
            ),
            child: DropdownButton<String>(
              value: value,
              dropdownColor: cs.surfaceContainerHigh,
              style: TextStyle(color: shell.onChrome, fontSize: 14),
              underline: const SizedBox.shrink(),
              items: options.map((String option) {
                return DropdownMenuItem<String>(
                  value: option,
                  child: Text(
                    format(option),
                    style: TextStyle(color: shell.onChrome),
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  static Widget infoCard({
    required BuildContext context,
    required String title,
    required String body,
    IconData icon = Icons.info_outline_rounded,
  }) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: cs.primary, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(
                    color: shell.onChrome,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  body,
                  style: TextStyle(
                    color: shell.muted,
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static void showUpdatedSnackBar(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: cs.inverseSurface,
        content: Text(
          'Settings updated',
          style: TextStyle(color: cs.onInverseSurface),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  static Widget _iconBadge(BuildContext context, IconData icon) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: shell.chipUnselectedBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: shell.chipUnselectedBorder),
      ),
      child: Icon(icon, color: shell.onChrome, size: 20),
    );
  }

  static String _formatOption(String option) {
    if (option.isEmpty) {
      return option;
    }
    return option[0].toUpperCase() + option.substring(1);
  }
}
