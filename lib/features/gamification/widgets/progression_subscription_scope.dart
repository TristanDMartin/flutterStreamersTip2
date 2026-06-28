import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gamification_providers.dart';

/// Activates progression Firestore listeners only while [child] is mounted.
class ProgressionSubscriptionScope extends ConsumerStatefulWidget {
  const ProgressionSubscriptionScope({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ProgressionSubscriptionScope> createState() =>
      _ProgressionSubscriptionScopeState();
}

class _ProgressionSubscriptionScopeState
    extends ConsumerState<ProgressionSubscriptionScope> {
  ProviderContainer? _container;
  ProgressionSubscriptionsActiveNotifier? _activeNotifier;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) {
      return;
    }
    _initialized = true;
    _container = ProviderScope.containerOf(context, listen: false);
    _activeNotifier =
        _container!.read(progressionSubscriptionsActiveProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _activeNotifier?.setActive(true);
    });
  }

  @override
  void dispose() {
    _activeNotifier?.setActive(false);
    _container?.invalidate(userProgressBundleProvider);
    _activeNotifier = null;
    _container = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
