import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_bootstrap.dart';

/// Reactive signal for post-runApp Firebase initialization.
class FirebaseBootstrapReadyNotifier extends Notifier<bool> {
  Timer? _pollTimer;

  @override
  bool build() {
    ref.onDispose(() {
      _pollTimer?.cancel();
      _pollTimer = null;
    });
    if (FirebaseBootstrap.isReady) {
      return true;
    }
    unawaited(
      FirebaseBootstrap.ensureInitialized().then((bool ready) {
        if (ready && !state) {
          state = true;
        }
      }),
    );
    _pollTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (Timer timer) {
        if (!FirebaseBootstrap.isReady) {
          return;
        }
        timer.cancel();
        _pollTimer = null;
        if (!state) {
          state = true;
        }
      },
    );
    return false;
  }
}

final firebaseBootstrapReadyProvider =
    NotifierProvider<FirebaseBootstrapReadyNotifier, bool>(
  FirebaseBootstrapReadyNotifier.new,
);
