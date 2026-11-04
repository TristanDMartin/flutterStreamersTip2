import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

@immutable
class AdaptiveNavState {
  const AdaptiveNavState({
    required this.isVisible,
    required this.hasKeyboard,
    required this.hasOverlay,
    required this.isInteracting,
  });

  final bool isVisible;
  final bool hasKeyboard;
  final bool hasOverlay;
  final bool isInteracting;

  AdaptiveNavState copyWith({
    bool? isVisible,
    bool? hasKeyboard,
    bool? hasOverlay,
    bool? isInteracting,
  }) {
    return AdaptiveNavState(
      isVisible: isVisible ?? this.isVisible,
      hasKeyboard: hasKeyboard ?? this.hasKeyboard,
      hasOverlay: hasOverlay ?? this.hasOverlay,
      isInteracting: isInteracting ?? this.isInteracting,
    );
  }
}

class AdaptiveNavNotifier extends StateNotifier<AdaptiveNavState> {
  AdaptiveNavNotifier()
      : super(const AdaptiveNavState(
          isVisible: true,
          hasKeyboard: false,
          hasOverlay: false,
          isInteracting: false,
        ));

  Timer? _hideTimer;
  static const Duration _autoHideDuration = Duration(seconds: 3);

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void onUserInteraction() {
    _hideTimer?.cancel();
    
    if (state.hasKeyboard || state.hasOverlay) {
      return;
    }

    if (!state.isVisible) {
      show();
    }

    state = state.copyWith(isInteracting: true);

    _hideTimer = Timer(_autoHideDuration, () {
      if (mounted && !state.hasKeyboard && !state.hasOverlay) {
        hide();
        state = state.copyWith(isInteracting: false);
      }
    });
  }

  void onPageChanged() {
    show();
    onUserInteraction();
  }

  void setKeyboardVisible(bool visible) {
    if (state.hasKeyboard != visible) {
      state = state.copyWith(hasKeyboard: visible);
      if (visible) {
        _hideTimer?.cancel();
        show();
      } else {
        onUserInteraction();
      }
    }
  }

  void setOverlayVisible(bool visible) {
    if (state.hasOverlay != visible) {
      state = state.copyWith(hasOverlay: visible);
      if (visible) {
        _hideTimer?.cancel();
        show();
      } else {
        onUserInteraction();
      }
    }
  }

  void show() {
    if (!state.isVisible) {
      state = state.copyWith(isVisible: true);
    }
  }

  void hide() {
    if (state.isVisible && !state.hasKeyboard && !state.hasOverlay) {
      state = state.copyWith(isVisible: false);
    }
  }

  void reset() {
    _hideTimer?.cancel();
    state = const AdaptiveNavState(
      isVisible: true,
      hasKeyboard: false,
      hasOverlay: false,
      isInteracting: false,
    );
  }
}

final adaptiveNavProvider =
    StateNotifierProvider<AdaptiveNavNotifier, AdaptiveNavState>(
  (ref) => AdaptiveNavNotifier(),
);
