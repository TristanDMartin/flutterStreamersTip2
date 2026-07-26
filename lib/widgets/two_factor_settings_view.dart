import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../services/two_factor_auth_service.dart';
import '../utils/user_facing_error.dart';
import 'screen_feedback_state.dart';
import 'two_factor_setup_view.dart';

class TwoFactorSettingsView extends ConsumerStatefulWidget {
  const TwoFactorSettingsView({super.key});

  @override
  ConsumerState<TwoFactorSettingsView> createState() =>
      _TwoFactorSettingsViewState();
}

class _TwoFactorSettingsViewState extends ConsumerState<TwoFactorSettingsView> {
  final TwoFactorAuthService _twoFactorService = TwoFactorAuthService();
  bool _isEnabled = false;
  bool _isLoading = true;
  String? _actionError;

  bool get _isIos => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  Widget _wrapIosTextScale(BuildContext context, Widget child) {
    if (!_isIos) {
      return child;
    }
    final MediaQueryData data = MediaQuery.of(context);
    return MediaQuery(
      data: data.copyWith(
        textScaler: data.textScaler.clamp(
          minScaleFactor: 0.82,
          maxScaleFactor: 1.04,
        ),
      ),
      child: child,
    );
  }

  @override
  void initState() {
    super.initState();
    _load2FAStatus();
  }

  Future<void> _load2FAStatus() async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    final status = await _twoFactorService.get2FAStatus(user.uid);
    if (mounted) {
      setState(() {
        _isEnabled = status?['enabled'] == true;
        _isLoading = false;
      });
    }
  }

  Future<void> _enable2FA() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => const TwoFactorSetupView(),
      ),
    );

    if (result == true && mounted) {
      await _load2FAStatus();
    }
  }

  Future<void> _disable2FA() async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        final ColorScheme cs = Theme.of(ctx).colorScheme;
        final TextTheme tt = Theme.of(ctx).textTheme;
        return AlertDialog(
          backgroundColor: cs.surfaceContainerHigh,
          title: Text(
            'Disable Two-Factor Authentication',
            style: tt.titleLarge?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            'Are you sure you want to disable two-factor authentication? '
            'This will make your account less secure.',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancel', style: TextStyle(color: cs.primary)),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                'Disable',
                style: TextStyle(
                  color: cs.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        await _twoFactorService.disable2FA(user.uid);
        if (mounted) {
          final ColorScheme cs = Theme.of(context).colorScheme;
          setState(() => _actionError = null);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text(
                'Two-factor authentication disabled',
                style: TextStyle(color: cs.onInverseSurface),
              ),
              backgroundColor: cs.inverseSurface,
            ),
          );
          await _load2FAStatus();
        }
      } catch (e) {
        if (mounted) {
          setState(() => _actionError = UserFacingError.message(e));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme c = Theme.of(context).colorScheme;
    final double pad = _isIos ? 16 : 24;
    final double statusTitle = _isIos ? 16 : 20;
    final double statusBody = _isIos ? 12.5 : 14;
    final double sectionTitle = _isIos ? 16 : 18;
    if (_isLoading) {
      final Widget loading = Scaffold(
        backgroundColor: c.surface,
        appBar: AppBar(
          backgroundColor: c.surface,
          surfaceTintColor: Colors.transparent,
          foregroundColor: c.onSurface,
          title: Text(
            'Two-Factor Authentication',
            style: TextStyle(
              color: c.onSurface,
              fontWeight: FontWeight.w600,
              fontSize: _isIos ? 16 : 20,
            ),
          ),
        ),
        body: Center(child: CircularProgressIndicator(color: c.primary)),
      );
      return _wrapIosTextScale(context, loading);
    }

    final Widget scaffold = Scaffold(
      backgroundColor: c.surface,
      appBar: AppBar(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: c.onSurface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: c.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Two-Factor Authentication',
          style: TextStyle(
            color: c.onSurface,
            fontWeight: FontWeight.w600,
            fontSize: _isIos ? 16 : 20,
          ),
        ),
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[c.surface, c.surfaceContainerLow],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(pad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (_actionError != null) ...[
                  ScreenInlineErrorBanner(
                    message: _actionError!,
                    onDismiss: () {
                      if (mounted) {
                        setState(() => _actionError = null);
                      }
                    },
                  ),
                  SizedBox(height: _isIos ? 12 : 16),
                ],
                Container(
                  padding: EdgeInsets.all(_isIos ? 16 : 20),
                  decoration: BoxDecoration(
                    color: _isEnabled
                        ? c.tertiaryContainer.withValues(alpha: 0.55)
                        : c.errorContainer.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isEnabled ? c.tertiary : c.error,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        _isEnabled ? Icons.check_circle : Icons.warning,
                        color: _isEnabled ? c.tertiary : c.error,
                        size: _isIos ? 32 : 40,
                      ),
                      SizedBox(width: _isIos ? 12 : 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              _isEnabled ? '2FA Enabled' : '2FA Disabled',
                              style: TextStyle(
                                color: c.onSurface,
                                fontSize: statusTitle,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _isEnabled
                                  ? 'Your account is protected with two-factor '
                                      'authentication'
                                  : 'Enable two-factor authentication to secure '
                                      'your account',
                              style: TextStyle(
                                color: c.onSurfaceVariant,
                                fontSize: statusBody,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: _isIos ? 24 : 32),
                if (_isEnabled) ...<Widget>[
                  _buildInfoSection(sectionTitle),
                  SizedBox(height: _isIos ? 18 : 24),
                  SizedBox(
                    width: double.infinity,
                    height: _isIos ? 44 : 48,
                    child: OutlinedButton(
                      onPressed: _disable2FA,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: c.error,
                        side: BorderSide(color: c.error),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: Text(
                        'Disable 2FA',
                        style: TextStyle(
                          color: c.error,
                          fontSize: _isIos ? 14 : 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ] else ...<Widget>[
                  Text(
                    'Benefits of Two-Factor Authentication:',
                    style: TextStyle(
                      color: c.onSurface,
                      fontSize: sectionTitle,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: _isIos ? 12 : 16),
                  _buildBenefitItem(
                    Icons.security,
                    'Extra layer of security for your account',
                  ),
                  _buildBenefitItem(
                    Icons.shield,
                    'Protection against unauthorized access',
                  ),
                  _buildBenefitItem(
                    Icons.verified_user,
                    'Verified account status',
                  ),
                  SizedBox(height: _isIos ? 24 : 32),
                  SizedBox(
                    width: double.infinity,
                    height: _isIos ? 44 : 48,
                    child: FilledButton(
                      onPressed: _enable2FA,
                      style: FilledButton.styleFrom(
                        backgroundColor: c.primary,
                        foregroundColor: c.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: Text(
                        'Enable 2FA',
                        style: TextStyle(
                          fontSize: _isIos ? 14 : 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    return _wrapIosTextScale(context, scaffold);
  }

  Widget _buildInfoSection(double sectionTitle) {
    final ColorScheme c = Theme.of(context).colorScheme;
    final double body = _isIos ? 12.5 : 14;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'How It Works',
          style: TextStyle(
            color: c.onSurface,
            fontSize: sectionTitle,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: _isIos ? 12 : 16),
        Container(
          padding: EdgeInsets.all(_isIos ? 12 : 16),
          decoration: BoxDecoration(
            color: c.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.outlineVariant),
          ),
          child: Column(
            children: <Widget>[
              Text(
                'When you log in, you\'ll be asked for:',
                style: TextStyle(color: c.onSurface, fontSize: body),
              ),
              const SizedBox(height: 12),
              _buildStepItem('1', 'Your password'),
              _buildStepItem('2', 'A 6-digit code from your authenticator app'),
              const SizedBox(height: 8),
              Text(
                'Or use a backup code if you lose access',
                style: TextStyle(
                  color: c.error,
                  fontSize: _isIos ? 11 : 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepItem(String number, String text) {
    final ColorScheme c = Theme.of(context).colorScheme;
    final double t = _isIos ? 12.5 : 14;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: c.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: c.onPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: c.onSurface, fontSize: t),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(IconData icon, String text) {
    final ColorScheme c = Theme.of(context).colorScheme;
    final double t = _isIos ? 12.5 : 14;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          Icon(icon, color: c.tertiary, size: _isIos ? 20 : 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: c.onSurface, fontSize: t),
            ),
          ),
        ],
      ),
    );
  }
}
