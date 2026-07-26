import 'package:flutter/foundation.dart';
import 'package:streamers_tip/config/giphy_config.dart';
import 'package:streamers_tip/features/billing/billing_backend_config.dart';

/// Compile-time / release dart-define readiness for launch ops.
class ReleaseConfigHealth {
  const ReleaseConfigHealth({
    required this.isGiphyConfigured,
    required this.isBillingVerifyConfigured,
    required this.missingKeys,
    required this.warnings,
  });

  final bool isGiphyConfigured;
  final bool isBillingVerifyConfigured;
  final List<String> missingKeys;
  final List<String> warnings;

  bool get isLaunchReady => missingKeys.isEmpty;

  static ReleaseConfigHealth evaluate() {
    final bool isGiphyConfigured = GiphyConfig.apiKey.trim().isNotEmpty;
    final String billingUrl = kMobileBillingVerifyUrl.trim();
    final bool isBillingVerifyConfigured = billingUrl.isNotEmpty &&
        !billingUrl.contains('<PROJECT_ID>') &&
        !billingUrl.contains('YOUR_');
    final List<String> missing = <String>[];
    final List<String> warnings = <String>[];
    if (!isGiphyConfigured) {
      missing.add('GIPHY_API_KEY');
      if (kReleaseMode) {
        warnings.add(
          'GIPHY_API_KEY empty in release — GIF picker will fail.',
        );
      }
    }
    if (!isBillingVerifyConfigured) {
      missing.add('MOBILE_BILLING_VERIFY_URL');
    }
    return ReleaseConfigHealth(
      isGiphyConfigured: isGiphyConfigured,
      isBillingVerifyConfigured: isBillingVerifyConfigured,
      missingKeys: missing,
      warnings: warnings,
    );
  }
}
