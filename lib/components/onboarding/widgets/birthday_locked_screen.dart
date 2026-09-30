import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../../../services/unified_avatar_service.dart' as nav;

const int _kMaxNavigatorWaitFrames = 30;

/// Under-13: sign out immediately, then show the notice on the root navigator
/// (the onboarding gate unmounts on sign-out). Mirrors web `/onboarding/birthday`.
Future<void> signOutWithBirthdayLockedNotice() async {
  await fa.FirebaseAuth.instance.signOut();
  _pushLockedNoticeWhenReady(0);
}

void _pushLockedNoticeWhenReady(int attempt) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final NavigatorState? navigator =
        nav.NavigationService.navigatorKey.currentState;
    if (navigator == null) {
      if (attempt < _kMaxNavigatorWaitFrames) {
        _pushLockedNoticeWhenReady(attempt + 1);
      }
      return;
    }
    navigator.push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (BuildContext context) => const BirthdayLockedScreen(),
      ),
    );
  });
  WidgetsBinding.instance.scheduleFrame();
}

class BirthdayLockedScreen extends StatelessWidget {
  const BirthdayLockedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.tippyBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text(
                "You can't sign up right now",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Sorry, you're not eligible to use StreamersTip.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 28),
              OutlinedButton(
                onPressed: () => Navigator.of(context).maybePop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF475569)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Back to home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
