import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/onboarding/account_enforcement.dart';
import '../services/account_visibility_service.dart';
import '../services/robust_auth_service.dart';
import 'manage_account_view.dart';

class DeactivatedAccountView extends ConsumerStatefulWidget {
  const DeactivatedAccountView({super.key});

  @override
  ConsumerState<DeactivatedAccountView> createState() =>
      _DeactivatedAccountViewState();
}

class _DeactivatedAccountViewState
    extends ConsumerState<DeactivatedAccountView> {
  bool _isBusy = false;
  String? _error;

  Future<void> _reactivate() async {
    if (_isBusy) {
      return;
    }
    setState(() {
      _isBusy = true;
      _error = null;
    });
    final AccountVisibilityResult result =
        await AccountVisibilityService().reactivateCurrentAccount();
    if (!mounted) {
      return;
    }
    setState(() {
      _isBusy = false;
      _error = result.ok ? null : (result.message ?? 'Reactivate failed.');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Icon(
                Icons.visibility_off,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                kDeactivatedAccountTitle,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your profile and videos are hidden from public feeds, '
                'search, and profile links. Your data is still here — '
                'reactivate anytime.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const Spacer(),
              FilledButton(
                onPressed: _isBusy ? null : _reactivate,
                child: Text(_isBusy ? 'Reactivating…' : 'Reactivate'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _isBusy
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const ManageAccountView(),
                          ),
                        );
                      },
                child: const Text('Settings'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _isBusy
                    ? null
                    : () async {
                        await ref.read(robustAuthServiceProvider).signOut();
                      },
                child: const Text('Sign Out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
