import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import '../services/favorites_service.dart' show FavoritesSyncStatus;
import '../services/unified_bookmark_service.dart';

part 'favorites_provider.freezed.dart';

@freezed
sealed class FavoritesState with _$FavoritesState {
  const factory FavoritesState({
    @Default({}) Set<String> favorites,
    @Default(FavoritesSyncStatus.synced) FavoritesSyncStatus syncStatus,
    @Default(false) bool isLoading,
    String? error,
  }) = _FavoritesState;
}

class FavoritesNotifier extends StateNotifier<FavoritesState> {
  FavoritesNotifier() : super(const FavoritesState()) {
    _bookmarkService.addListener(_onBookmarksChanged);
    _onBookmarksChanged();
  }

  final UnifiedBookmarkService _bookmarkService = UnifiedBookmarkService.instance;

  void detach() {
    _bookmarkService.removeListener(_onBookmarksChanged);
  }

  void _onBookmarksChanged() {
    final Set<String> ids = _bookmarkService.bookmarkStates.entries
        .where((MapEntry<String, BookmarkState> e) => e.value.isBookmarked)
        .map((MapEntry<String, BookmarkState> e) => e.key)
        .toSet();
    final bool anyPending = _bookmarkService.bookmarkStates.values
        .any((BookmarkState s) => s.status == BookmarkStatus.pending);
    state = state.copyWith(
      favorites: ids,
      syncStatus:
          anyPending ? FavoritesSyncStatus.pending : FavoritesSyncStatus.synced,
    );
  }

  Future<void> toggleFavorite(String videoId) async {
    if (state.isLoading) {
      return;
    }
    state = state.copyWith(isLoading: true, error: null);
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        state = state.copyWith(
          error: 'Not signed in',
          isLoading: false,
        );
        return;
      }
      await _bookmarkService.initialize(user.uid);
      final BookmarkResult result =
          await _bookmarkService.toggleBookmark(videoId);
      if (!result.success) {
        state = state.copyWith(
          error: result.error ?? 'Bookmark failed',
          isLoading: false,
        );
        return;
      }
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  bool isFavorite(String videoId) => _bookmarkService.isBookmarked(videoId);

  List<String> getFavorites() => _bookmarkService.bookmarkStates.entries
      .where((MapEntry<String, BookmarkState> e) => e.value.isBookmarked)
      .map((MapEntry<String, BookmarkState> e) => e.key)
      .toList();

  Future<void> forceSync() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
    await _bookmarkService.initialize(user.uid);
  }

  void clearFavorites() {
    _bookmarkService.clearBookmarks();
  }
}

final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, FavoritesState>((Ref ref) {
  final FavoritesNotifier notifier = FavoritesNotifier();
  ref.onDispose(notifier.detach);
  return notifier;
});
