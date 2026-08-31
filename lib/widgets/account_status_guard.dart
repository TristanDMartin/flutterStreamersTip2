import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/onboarding/account_enforcement.dart';
import '../services/robust_auth_service.dart';
import '../views/account_unavailable_view.dart';
import '../views/banned_account_view.dart';
import '../views/deactivated_account_view.dart';

/// Routes signed-in users after users/{uid}.accountStatus resolves.
/// Does not flash Home while the first snapshot is in flight.
class AccountStatusGuard extends ConsumerWidget {
  const AccountStatusGuard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(robustAuthServiceProvider);
    if (!authState.isLoggedIn) {
      return child;
    }
    final String? uid =
        FirebaseAuth.instance.currentUser?.uid ?? authState.currentUser?.id;
    if (uid == null || uid.isEmpty) {
      return child;
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting &&
            !snap.hasData) {
          return const Scaffold(body: SizedBox.expand());
        }
        if (snap.hasError || !snap.hasData || !snap.data!.exists) {
          return child;
        }
        final Object? raw = snap.data!.data()?['accountStatus'];
        final AccountEnforcementResult enforcement =
            resolveAccountEnforcement(raw);
        if (enforcement.destination == 'banned') {
          return const BannedAccountView();
        }
        if (enforcement.destination == 'deactivated') {
          return const DeactivatedAccountView();
        }
        if (enforcement.destination == 'unavailable' ||
            enforcement.destination == 'deleted') {
          return const AccountUnavailableView();
        }
        return child;
      },
    );
  }
}
