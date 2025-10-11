import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/unified_bookmark_service.dart';

/// Provider for the unified bookmark service
final unifiedBookmarkServiceProvider = Provider<UnifiedBookmarkService>((ref) {
  return UnifiedBookmarkService.instance;
});

/// Provider for current user's bookmark states
final bookmarkStatesProvider =
    StreamProvider<Map<String, BookmarkState>>((ref) {
  final service = ref.watch(unifiedBookmarkServiceProvider);
  final currentUser = FirebaseAuth.instance.currentUser;

  if (currentUser == null) {
    return Stream.value({});
  }

  // Initialize service if not already done
  service.initialize(currentUser.uid);

  return service.eventStream.map((event) => service.bookmarkStates);
});

/// Provider for a specific video's bookmark state
final videoBookmarkStateProvider =
    Provider.family<BookmarkState?, String>((ref, videoId) {
  final states = ref.watch(bookmarkStatesProvider);
  return states.when(
    data: (states) => states[videoId],
    loading: () => null,
    error: (_, __) => null,
  );
});

/// Provider for checking if a video is bookmarked
final isVideoBookmarkedProvider = Provider.family<bool, String>((ref, videoId) {
  final state = ref.watch(videoBookmarkStateProvider(videoId));
  return state?.isBookmarked ?? false;
});

/// Provider for checking if there's a pending operation
final hasPendingBookmarkOperationProvider =
    Provider.family<bool, String>((ref, videoId) {
  final service = ref.watch(unifiedBookmarkServiceProvider);
  return service.hasPendingOperation(videoId);
});
