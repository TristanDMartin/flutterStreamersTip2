# Favorites System Integration Guide

This guide shows how to integrate the comprehensive favorites system with error handling, offline support, and performance optimizations.

## 🚀 Quick Start

### 1. Basic Integration in HomeView

```dart
class HomeView extends ConsumerStatefulWidget {
  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView> {
  @override
  void initState() {
    super.initState();
    
    // Setup favorites manager on app appear
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupFavoritesManager();
    });
  }

  /// Setup favorites manager - equivalent to Swift's .onAppear
  void _setupFavoritesManager() {
    // The favorites service is automatically initialized via Riverpod
    // This is equivalent to: viewModel.setFavoritesManager(favoritesManager)
    final favoritesNotifier = ref.read(favoritesProvider.notifier);
    
    // Force sync with Firebase when HomeView appears
    favoritesNotifier.forceSync();
    
    print('🏠 HomeView: Favorites manager setup complete');
  }
}
```

### 2. Using the FavoriteButton Widget

```dart
// Simple favorite button with instant response
FavoriteButton(
  videoId: 'video_123',
  size: 28,
  activeColor: const Color(0xFF9248d2), // User's preferred purple
)
```

### 3. Complete Video Card Integration

```dart
VideoCardWithFavorites(
  videoId: 'video_123',
  title: 'Epic Gaming Moment',
  creator: 'GamingPro',
  description: 'Check out this insane play! 🔥',
  likes: '12.5K',
  comments: '1.2K',
  shares: '500',
  videoUrl: 'https://example.com/video.mp4',
  onTap: () {
    // Handle video tap
  },
)
```

## 🏗️ Architecture Overview

### Error Handling & Offline Support

#### A. Graceful Degradation:
- **No User ID**: Falls back to local storage only
- **Network Issues**: Continues with local state
- **Firebase Errors**: Logs errors but doesn't break UI

#### B. State Recovery:
- **App Restart**: Loads from SharedPreferences
- **User Login**: Syncs with Firebase
- **Network Recovery**: Automatic background sync

### Performance Optimizations

#### A. Immediate UI Feedback:
- **Optimistic Updates**: UI changes instantly
- **Loading States**: Prevents double-taps
- **Debounced Actions**: Prevents race conditions

#### B. Efficient Data Management:
- **Set-based Storage**: O(1) lookup for favorites
- **Lazy Loading**: Only sync when needed
- **Memory Management**: Proper cleanup on logout

## 📱 Usage Examples

### 1. Check if Video is Favorited

```dart
class VideoWidget extends ConsumerWidget {
  final String videoId;
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesState = ref.watch(favoritesProvider);
    final isFavorited = favoritesState.favorites.contains(videoId);
    
    return Icon(
      isFavorited ? Icons.favorite : Icons.favorite_border,
      color: isFavorited ? Colors.red : Colors.white,
    );
  }
}
```

### 2. Toggle Favorite with Loading State

```dart
class FavoriteToggleButton extends ConsumerWidget {
  final String videoId;
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesState = ref.watch(favoritesProvider);
    final favoritesNotifier = ref.read(favoritesProvider.notifier);
    
    return GestureDetector(
      onTap: favoritesState.isLoading 
          ? null 
          : () => favoritesNotifier.toggleFavorite(videoId),
      child: Container(
        child: favoritesState.isLoading
            ? const CircularProgressIndicator()
            : Icon(
                favoritesState.favorites.contains(videoId)
                    ? Icons.favorite
                    : Icons.favorite_border,
              ),
      ),
    );
  }
}
```

### 3. Monitor Sync Status

```dart
class SyncStatusIndicator extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesState = ref.watch(favoritesProvider);
    
    switch (favoritesState.syncStatus) {
      case FavoritesSyncStatus.synced:
        return const SizedBox.shrink();
      case FavoritesSyncStatus.pending:
        return const Text('Syncing...', style: TextStyle(color: Colors.orange));
      case FavoritesSyncStatus.error:
        return const Text('Sync Error', style: TextStyle(color: Colors.red));
      case FavoritesSyncStatus.offline:
        return const Text('Offline', style: TextStyle(color: Colors.grey));
    }
  }
}
```

## 🔧 Advanced Configuration

### 1. Custom Favorites Service

```dart
// In your main.dart or app initialization
final favoritesServiceProvider = Provider<FavoritesService>((ref) {
  final service = FavoritesService();
  ref.onDispose(() => service.dispose());
  service.initialize();
  return service;
});
```

### 2. Force Sync on Network Recovery

```dart
class NetworkAwareWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Listen to network changes and force sync
    ref.listen(connectivityProvider, (previous, next) {
      if (next == ConnectivityResult.wifi || next == ConnectivityResult.mobile) {
        ref.read(favoritesProvider.notifier).forceSync();
      }
    });
    
    return YourWidget();
  }
}
```

### 3. Clear Favorites on Logout

```dart
class LogoutButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ElevatedButton(
      onPressed: () {
        // Clear favorites when user logs out
        ref.read(favoritesProvider.notifier).clearFavorites();
        // Perform other logout actions...
      },
      child: const Text('Logout'),
    );
  }
}
```

## 🎯 Key Features

### ✅ Instant Button Response
- UI updates immediately on tap
- No waiting for network requests
- Prevents double-tap issues

### ✅ Offline Support
- Works without internet connection
- Syncs when connection is restored
- Local state persistence

### ✅ Error Recovery
- Graceful handling of network errors
- Automatic retry mechanisms
- User-friendly error states

### ✅ Performance Optimized
- O(1) lookup for favorite status
- Efficient memory usage
- Minimal rebuilds

### ✅ State Management
- Reactive updates with Riverpod
- Proper cleanup on disposal
- Consistent state across app

## 🔍 Testing

### Unit Tests
```dart
testWidgets('Favorite button toggles correctly', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: FavoriteButton(videoId: 'test_video'),
      ),
    ),
  );
  
  // Test favorite toggle
  await tester.tap(find.byType(FavoriteButton));
  await tester.pump();
  
  // Verify UI update
  expect(find.byIcon(Icons.favorite), findsOneWidget);
});
```

### Integration Tests
```dart
testWidgets('Favorites persist across app restarts', (tester) async {
  // Test local persistence
  // Test Firebase sync
  // Test state recovery
});
```

## 🚨 Important Notes

1. **Memory Management**: Always dispose of the FavoritesService when done
2. **Error Handling**: Check sync status before critical operations
3. **Performance**: Use `isFavorited()` for O(1) lookups instead of iterating
4. **State Consistency**: Use Riverpod providers for reactive updates
5. **Offline Behavior**: Test with network disabled to ensure graceful degradation

## 📚 Related Files

- `lib/services/favorites_service.dart` - Core favorites logic
- `lib/providers/favorites_provider.dart` - Riverpod state management
- `lib/widgets/favorite_button.dart` - Reusable favorite button
- `lib/widgets/video_card_with_favorites.dart` - Complete video card example
