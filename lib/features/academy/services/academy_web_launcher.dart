import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens Streamer Academy website pages inside an in-app browser when possible.
class AcademyWebLauncher {
  const AcademyWebLauncher._();

  static Future<bool> openGuideUrl(String? rawUrl) async {
    final String? trimmed = rawUrl?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return false;
    }
    final Uri? uri = Uri.tryParse(trimmed);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      return false;
    }
    try {
      if (await canLaunchUrl(uri)) {
        final bool launched = await launchUrl(
          uri,
          mode: LaunchMode.inAppBrowserView,
        );
        if (launched) {
          return true;
        }
      }
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('AcademyWebLauncher: failed to open $trimmed ($e)');
      return false;
    }
  }
}
