import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import '../services/favorites_service.dart';

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
  FavoritesNotifier(this._favoritesService) : super(const FavoritesState()) {
    _initialize();
  }

  final FavoritesService _favoritesService;

  void _initialize() {
    // Listen to favorites changes
    _favoritesService.favoritesStream.listen((favorites) {
      state = state.copyWith(favorites: favorites);
    });

    // Listen to sync status changes
    _favoritesService.syncStatusStream.listen((syncStatus) {
      state = state.copyWith(syncStatus: syncStatus);
    });
  }

  Future<void> toggleFavorite(String videoId) async {
    if (state.isLoading) return;
    
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      await _favoritesService.toggleFavorite(videoId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  bool isFavorite(String videoId) {
    return _favoritesService.isFavorited(videoId);
  }

  List<String> getFavorites() {
    return _favoritesService.getFavorites();
  }

  Future<void> forceSync() async {
    await _favoritesService.forceSync();
  }

  void clearFavorites() {
    _favoritesService.clearFavorites();
  }
}

final favoritesServiceProvider = Provider<FavoritesService>((ref) {
  final service = FavoritesService();
  ref.onDispose(() => service.dispose());
  service.initialize();
  return service;
});

final favoritesProvider = StateNotifierProvider<FavoritesNotifier, FavoritesState>((ref) {
  final favoritesService = ref.watch(favoritesServiceProvider);
  return FavoritesNotifier(favoritesService);
});
