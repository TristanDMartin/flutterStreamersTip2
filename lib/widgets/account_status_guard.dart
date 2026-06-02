import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/robust_auth_service.dart';
import '../views/banned_account_view.dart';

/// Shows [BannedAccountView] when `users/{uid}.accountStatus == banned`.
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
        if (snap.hasError || !snap.hasData || !snap.data!.exists) {
          return child;
        }
        final String? st = snap.data!.data()?['accountStatus'] as String?;
        if (st == 'banned') {
          return const BannedAccountView();
        }
        return child;
      },
    );
  }
}
