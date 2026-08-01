import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/robust_auth_service.dart';
import 'auth/auth_brand_header.dart';
import 'auth/auth_glass_panel.dart';
import 'auth_page_shell.dart';

class ForgotPasswordView extends ConsumerStatefulWidget {
  const ForgotPasswordView({super.key});

  @override
  ConsumerState<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends ConsumerState<ForgotPasswordView> {
  final TextEditingController _emailController = TextEditingController();
  bool _showAlert = false;
  String _alertMessage = '';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_handleInputChanged);
    _setSystemUIOverlayStyle();
  }

  void _handleInputChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _setSystemUIOverlayStyle() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }

  @override
  void dispose() {
    _emailController.removeListener(_handleInputChanged);
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthPageShell(
      contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      minHeightBottomPadding: 24,
      showLoading: _isSubmitting,
      loadingText: 'Sending reset email...',
      showAlert: _showAlert,
      alertMessage: _alertMessage,
      onDismissAlert: () => setState(() => _showAlert = false),
      content: Column(
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
            ),
          ),
          const SizedBox(height: 8),
          AuthGlassPanel(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
            child: Column(
              children: <Widget>[
                const AuthBrandHeader(logoSize: 80, compact: true),
                const SizedBox(height: 18),
                const Text(
                  'Find your account',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter your email or username to continue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 24),
                _buildTextField(),
                const SizedBox(height: 12),
                Text(
                  'You may receive email notifications from us for security '
                  'and login purposes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 24),
                _buildContinueButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
        ),
      ),
      child: TextField(
        controller: _emailController,
        enabled: !_isSubmitting,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _handleContinue(),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Email or username',
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
          ),
          prefixIcon: Icon(
            Icons.person_outline_rounded,
            color: Colors.white.withValues(alpha: 0.7),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildContinueButton() {
    final bool isEnabled =
        _emailController.text.trim().isNotEmpty && !_isSubmitting;
    return Opacity(
      opacity: isEnabled ? 1.0 : 0.5,
      child: GestureDetector(
        onTap: isEnabled ? _handleContinue : null,
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: <Color>[Color(0xFF955CFF), Color(0xFF3D99F7)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x553D99F7),
                blurRadius: 22,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              'Continue',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleContinue() async {
    if (_isSubmitting) {
      return;
    }
    final String identifier = _emailController.text.trim();
    if (identifier.isEmpty) {
      setState(() {
        _alertMessage = 'Please enter your email or username';
        _showAlert = true;
      });
      return;
    }
    setState(() {
      _isSubmitting = true;
    });
    try {
      final PasswordResetRequestResult result = await ref
          .read(robustAuthServiceProvider)
          .sendPasswordResetForIdentifier(identifier);
      if (!mounted) {
        return;
      }
      if (result.success) {
        await _showSuccessDialog(
          result.message ??
              'Password reset email sent if an account exists for that address.',
        );
        if (mounted) {
          Navigator.of(context).pop();
        }
      } else {
        setState(() {
          _alertMessage = result.error ?? 'Something went wrong.';
          _showAlert = true;
        });
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _alertMessage = 'Unable to send reset email. Please try again.';
        _showAlert = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _showSuccessDialog(String message) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Check your email',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            message,
            style: const TextStyle(
              color: Colors.white70,
              height: 1.3,
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
}
