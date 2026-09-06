import 'package:flutter_riverpod/flutter_riverpod.dart';

/// True only when account status says the authenticated app shell may boot
/// (ACTIVATED / allowApp). Tippy onboarding must keep this false so feed,
/// gamification, and MainTabView services stay dark.
final StateProvider<bool> authenticatedAppShellReadyProvider =
    StateProvider<bool>((Ref ref) => false);
