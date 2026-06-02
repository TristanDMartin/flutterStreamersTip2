import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/shared_draft_service.dart';
import '../models/shared_draft.dart';
import '../models/connection.dart';
import 'package:streamers_tip/utils/secure_log.dart';

final sharedDraftServiceProvider = Provider<SharedDraftService>((ref) {
  final service = SharedDraftService();
  service.initialize();
  ref.onDispose(() => service.dispose());
  return service;
});

final sharedDraftsProvider = StreamProvider<List<SharedDraft>>((ref) {
  final service = ref.watch(sharedDraftServiceProvider);
  return service.sharedDraftsStream;
});

final sharedDraftConnectionsProvider = StreamProvider<List<Connection>>((ref) {
  final service = ref.watch(sharedDraftServiceProvider);
  return service.connectionsStream;
});

final unreadSharedDraftsCountProvider = Provider<int>((ref) {
  final sharedDrafts = ref.watch(sharedDraftsProvider).value ?? [];
  return sharedDrafts
      .where((draft) => draft.status != SharedDraftStatus.viewed)
      .length;
});

class SharedDraftNotifier extends StateNotifier<AsyncValue<void>> {
  final SharedDraftService _service;

  SharedDraftNotifier(this._service) : super(const AsyncValue.data(null));

  Future<void> shareDraft({
    required String draftId,
    required String receiverId,
    required String draftTitle,
    required String draftThumbnailUrl,
    required int draftDuration,
    String? message,
  }) async {
    state = const AsyncValue.loading();

    try {
      final success = await _service.shareDraft(
        draftId: draftId,
        receiverId: receiverId,
        draftTitle: draftTitle,
        draftThumbnailUrl: draftThumbnailUrl,
        draftDuration: draftDuration,
        message: message,
      );

      if (success) {
        state = const AsyncValue.data(null);
      } else {
        state = AsyncValue.error('Failed to share draft', StackTrace.current);
      }
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> markAsViewed(String sharedDraftId) async {
    try {
      await _service.markAsViewed(sharedDraftId);
    } catch (e) {
      // Handle error silently for now
      secureLog('Error marking as viewed: $e');
    }
  }

  Future<void> declineDraft(String sharedDraftId) async {
    try {
      await _service.declineDraft(sharedDraftId);
    } catch (e) {
      // Handle error silently for now
      secureLog('Error declining draft: $e');
    }
  }

  Future<void> deleteSharedDraft(String sharedDraftId) async {
    try {
      await _service.deleteSharedDraft(sharedDraftId);
    } catch (e) {
      // Handle error silently for now
      secureLog('Error deleting shared draft: $e');
    }
  }

  Future<void> addConnection({
    required String userId,
    required String name,
    required String avatar,
    required String username,
  }) async {
    try {
      await _service.addConnection(
        userId: userId,
        name: name,
        avatar: avatar,
        username: username,
      );
    } catch (e) {
      // Handle error silently for now
      secureLog('Error adding connection: $e');
    }
  }

  Future<void> removeConnection(String connectionId) async {
    try {
      await _service.removeConnection(connectionId);
    } catch (e) {
      // Handle error silently for now
      secureLog('Error removing connection: $e');
    }
  }
}

final sharedDraftNotifierProvider =
    StateNotifierProvider<SharedDraftNotifier, AsyncValue<void>>((ref) {
  final service = ref.watch(sharedDraftServiceProvider);
  return SharedDraftNotifier(service);
});
