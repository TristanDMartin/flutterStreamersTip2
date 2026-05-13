import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Drives feed UI during the product tour (e.g. open Progression row).
enum ProductTourUiPhase {
  idle,
  progressionView,
  threadsView,
  tippyCommandCenter,
  progressionDropdown,
}

final StateProvider<ProductTourUiPhase> productTourUiPhaseProvider =
    StateProvider<ProductTourUiPhase>(
  (Ref ref) => ProductTourUiPhase.idle,
);

/// Main shell tab index (0 home, 1 network) requested by the product tour.
final StateProvider<int?> productTourMainTabIndexRequestProvider =
    StateProvider<int?>((Ref ref) => null);

/// Bumped when the tour enters the creator-card step so [DiscoverView] clears
/// category selection and scrolls to the default (trending) layout.
final StateProvider<int> productTourDiscoverCreatorsPrepProvider =
    StateProvider<int>((Ref ref) => 0);
