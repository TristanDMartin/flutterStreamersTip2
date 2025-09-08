import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../models/connection.dart';
import '../models/video.dart';
import '../providers/shared_draft_provider.dart';

class ShareDraftSheetView extends HookConsumerWidget {
  final Video draft;
  final VoidCallback? onDismiss;

  const ShareDraftSheetView({
    super.key,
    required this.draft,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedConnections = useState<Set<String>>({});
    final messageController = useTextEditingController();
    final isSharing = useState(false);

    final connectionsAsync = ref.watch(sharedDraftConnectionsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text(
          'Share Draft',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            Navigator.of(context).pop();
            onDismiss?.call();
          },
        ),
        actions: [
          if (selectedConnections.value.isNotEmpty)
            TextButton(
              onPressed: isSharing.value
                  ? null
                  : () => _shareDraft(
                        context,
                        ref,
                        selectedConnections.value,
                        messageController.text,
                        isSharing,
                      ),
              child: isSharing.value
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'Share (${selectedConnections.value.length})',
                      style: const TextStyle(
                        color: Color(0xFF9248d2),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildDraftPreview(),
          _buildMessageInput(messageController),
          Expanded(
            child: connectionsAsync.when(
              data: (connections) => _buildConnectionsList(
                connections,
                selectedConnections,
              ),
              loading: () => const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              error: (error, stack) => _buildErrorState(error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraftPreview() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[800],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
                      child: draft.videoURL.isNotEmpty
            ? Image.network(
                draft.videoURL,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.video_library,
                    color: Colors.grey,
                    size: 24,
                  );
                },
              )
            : const Icon(
                Icons.video_library,
                color: Colors.grey,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  draft.creator.displayName.isNotEmpty ? draft.creator.displayName : 'Untitled Draft',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDuration(30), // Default duration
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput(TextEditingController messageController) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: messageController,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Add a message (optional)',
          hintStyle: const TextStyle(color: Colors.grey),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[700]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[700]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF9248d2)),
          ),
          contentPadding: const EdgeInsets.all(16),
        ),
        maxLines: 3,
        maxLength: 200,
      ),
    );
  }

  Widget _buildConnectionsList(
    List<Connection> connections,
    ValueNotifier<Set<String>> selectedConnections,
  ) {
    if (connections.isEmpty) {
      return _buildEmptyConnectionsState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: connections.length,
      itemBuilder: (context, index) {
        final connection = connections[index];
        final isSelected = selectedConnections.value.contains(connection.id);

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(color: const Color(0xFF9248d2), width: 2)
                : null,
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: CircleAvatar(
              radius: 20,
              backgroundImage: connection.avatarUrl.isNotEmpty
                  ? NetworkImage(connection.avatarUrl)
                  : null,
              child: connection.avatarUrl.isEmpty
                  ? Text(
                      connection.displayName.isNotEmpty
                          ? connection.displayName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            title: Text(
              connection.displayName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              '@${connection.username}',
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: connection.isOnline
                        ? Colors.green
                        : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: isSelected ? const Color(0xFF9248d2) : Colors.grey,
                ),
              ],
            ),
            onTap: () {
              final newSelection = Set<String>.from(selectedConnections.value);
              if (isSelected) {
                newSelection.remove(connection.id);
              } else {
                newSelection.add(connection.id);
              }
              selectedConnections.value = newSelection;
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyConnectionsState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'No connections yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Add friends to share your drafts with them',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          const Text(
            'Error loading connections',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Future<void> _shareDraft(
    BuildContext context,
    WidgetRef ref,
    Set<String> selectedConnectionIds,
    String message,
    ValueNotifier<bool> isSharing,
  ) async {
    isSharing.value = true;

    try {
      for (final connectionId in selectedConnectionIds) {
        await ref.read(sharedDraftNotifierProvider.notifier).shareDraft(
              draftId: draft.id,
              receiverId: connectionId,
              draftTitle: draft.creator.displayName.isNotEmpty ? draft.creator.displayName : 'Untitled Draft',
              draftThumbnailUrl: draft.videoURL,
              draftDuration: 30, // Default duration
              message: message.isNotEmpty ? message : null,
            );
      }

      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Draft shared with ${selectedConnectionIds.length} friend${selectedConnectionIds.length > 1 ? 's' : ''}',
            ),
            backgroundColor: const Color(0xFF9248d2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share draft: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      isSharing.value = false;
    }
  }
}
