import 'package:flutter/foundation.dart';

import 'iap_billing_facade.dart';

/// One shared [IapBillingFacade] for the whole app (purchase stream + products).
class IapBillingCoordinator {
  IapBillingCoordinator._();
  static final IapBillingCoordinator instance = IapBillingCoordinator._();

  IapBillingFacade? _facade;
  final List<VoidCallback> _listeners = <VoidCallback>[];
  final List<VoidCallback> _verifiedHandlers = <VoidCallback>[];

  IapBillingFacade get facade {
    _facade ??= IapBillingFacade(
      onUiChanged: _notifyListeners,
      onRecoverableMessage: (_) {},
      onVerified: () {
        for (final VoidCallback h in List<VoidCallback>.from(_verifiedHandlers)) {
          h();
        }
        _notifyListeners();
      },
    );
    return _facade!;
  }

  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void addVerifiedHandler(VoidCallback onVerified) {
    _verifiedHandlers.add(onVerified);
  }

  void removeVerifiedHandler(VoidCallback onVerified) {
    _verifiedHandlers.remove(onVerified);
  }

  void _notifyListeners() {
    for (final VoidCallback l in List<VoidCallback>.from(_listeners)) {
      l();
    }
  }

  /// Call after Firebase is up. No-op on web.
  Future<void> warmStart() async {
    if (kIsWeb) {
      return;
    }
    await facade.initialize();
    await facade.loadProducts();
  }
}
