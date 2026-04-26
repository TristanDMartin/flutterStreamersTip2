import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'billing_backend_config.dart';

/// Shows whether [kMobileBillingVerifyUrl] is set, with copyable hints for
/// local and beta builds.
class MobileBillingSetupStatusBanner extends StatelessWidget {
  const MobileBillingSetupStatusBanner({super.key});

  static const String _kExampleUrl =
      'https://us-central1-<PROJECT_ID>.cloudfunctions.net/verifyMobilePurchase';
  static const String _kDefine = 'MOBILE_BILLING_VERIFY_URL';
  static const String _kFullExample = 'flutter run --dart-define=$_kDefine='
      '$_kExampleUrl';

  @override
  Widget build(BuildContext context) {
    if (isMobileBillingVerifyUrlConfigured()) {
      return _buildOk();
    }
    return _buildNeedSetup();
  }

  Widget _buildOk() {
    return Semantics(
      label: 'Receipt verification is configured for this build.',
      child: _Shell(
        borderColor: const Color(0xFF34D399).withValues(alpha: 0.4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              Icons.verified_outlined,
              size: 18,
              color: const Color(0xFF6EE7B7).withValues(alpha: 0.95),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Server verification is enabled. After Apple or Google '
                'confirms the purchase, this build can POST the receipt to '
                'your backend to unlock entitlements.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.82),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNeedSetup() {
    return Semantics(
      label: 'Add MOBILE_BILLING_VERIFY_URL at build time.',
      child: _Shell(
        borderColor: const Color(0xFFFBBF24).withValues(alpha: 0.45),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.privacy_tip_outlined,
                  size: 18,
                  color: const Color(0xFFFCD34D).withValues(alpha: 0.95),
                ),
                const SizedBox(width: 8),
                Text(
                  'Backend URL not in this build',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Set the deployable verifyMobilePurchase URL with '
              '--dart-define, or Pro / Studio will not unlock after purchase.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            _LabelCopyRow(
              text: _kDefine,
            ),
            const SizedBox(height: 6),
            _LabelCopyRow(
              text: _kExampleUrl,
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: SelectableText(
                _kFullExample,
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'monospace',
                  height: 1.4,
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _kFullExample));
                },
                icon: const Icon(Icons.content_copy, size: 16),
                label: const Text('Copy example'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF7DD3FC),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Shell extends StatelessWidget {
  const _Shell({
    required this.borderColor,
    required this.child,
  });

  final Color borderColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }
}

class _LabelCopyRow extends StatelessWidget {
  const _LabelCopyRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: SelectableText(
            text,
            style: const TextStyle(
              color: Color(0xFF7DD3FC),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
        ),
        IconButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: text));
          },
          icon: const Icon(
            Icons.copy,
            size: 18,
            color: Color(0xFF94A3B8),
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 36, height: 36),
          tooltip: 'Copy',
        ),
      ],
    );
  }
}
