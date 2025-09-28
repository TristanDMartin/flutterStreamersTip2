import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/discover_provider.dart';
import '../models/user.dart';
import '../models/video_clip.dart';
import 'optimized_image.dart';
import 'streamer_card_view.dart';
import 'discover_view.dart';
import '../services/robust_auth_service.dart';

class SearchResultsView extends ConsumerStatefulWidget {
  final String searchText;
  final DiscoverNotifier viewModel;

  const SearchResultsView({
    super.key,
    required this.searchText,
    required this.viewModel,
  });

  @override
  ConsumerState<SearchResultsView> createState() => _SearchResultsViewState();
}

class _SearchResultsViewState extends ConsumerState<SearchResultsView> {
  @override
  void initState() {
    super.initState();
    // Perform initial search if needed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.searchText.isNotEmpty) {
        widget.viewModel.search(widget.searchText);
      }
    });
  }

  @override
  void didUpdateWidget(SearchResultsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only trigger search if text actually changed
    if (oldWidget.searchText != widget.searchText && widget.searchText.isNotEmpty) {
      widget.viewModel.search(widget.searchText);
    } else if (widget.searchText.isEmpty) {
      // Clear results immediately for empty search
      widget.viewModel.clearSearch();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only watch search results to minimize rebuilds
    final searchResults = ref.watch(discoverProvider.select((state) => state.searchResults));
    
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: searchResults.length,
      itemBuilder: (context, index) {
        final result = searchResults[index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SearchResultRow(
            result: result,
            onProfileTap: (user) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => StreamerCardView(
                    userId: user.id,
                    currentUserId: ref.read(robustAuthServiceProvider).currentUser?.id,
                    onDismiss: () => Navigator.of(context).pop(),
                  ),
                ),
              );
            },
            onVideoTap: (clip) {
              // Navigate to video player or category view
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => DiscoverView(), // This will show the category content
                ),
              );
            },
            onCategoryTap: (categoryId) {
              // Navigate back to DiscoverView with category selected
              Navigator.of(context).pop(); // Go back to DiscoverView
              // The category selection will be handled by the DiscoverView
            },
          ),
        );
      },
    );
  }
}

class SearchResultRow extends StatelessWidget {
  final SearchResult result;
  final ValueChanged<User> onProfileTap;
  final ValueChanged<VideoClip> onVideoTap;
  final ValueChanged<String> onCategoryTap;

  const SearchResultRow({
    super.key,
    required this.result,
    required this.onProfileTap,
    required this.onVideoTap,
    required this.onCategoryTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: const BoxDecoration(
          color: Color(0x26FFFFFF), // Pre-calculated alpha value
          borderRadius: BorderRadius.all(Radius.circular(16)),
          border: Border.fromBorderSide(
            BorderSide(
              color: Color(0x4DFFFFFF), // Pre-calculated alpha value
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x1A000000), // Pre-calculated alpha value
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon or Image
            _buildIconOrImage(),
            
            const SizedBox(width: 12),
            
            // Content
            Expanded(
              child: _buildContent(),
            ),
            
            const SizedBox(width: 12),
            
            // Arrow
            const Icon(
              Icons.chevron_right,
              color: Colors.grey,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconOrImage() {
    // Make avatars larger and more prominent
    const double avatarSize = 48.0;
    
    if (result.imageURL != null && result.imageURL!.isNotEmpty) {
      return Container(
        width: avatarSize,
        height: avatarSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: ClipOval(
          child: OptimizedImage(
            imageUrl: result.imageURL!,
            width: avatarSize,
            height: avatarSize,
            fit: BoxFit.cover,
          ),
        ),
      );
    } else {
      return _buildIconPlaceholder();
    }
  }

  Widget _buildIconPlaceholder() {
    const double avatarSize = 48.0;
    
    return Container(
      width: avatarSize,
      height: avatarSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [
            Color(0xFF6633CC), // Purple
            Color(0xFF1A1A4D), // Dark blue
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Icon(
        _getIconForType(result.type),
        color: Colors.white,
        size: 20,
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          result.title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        
        const SizedBox(height: 2),
        
        Text(
          result.subtitle,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xB3FFFFFF), // Pre-calculated alpha value
          ),
        ),
        
        if (result.metadata != null) ...[
          const SizedBox(height: 2),
          Text(
            result.metadata!,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0x80FFFFFF), // Pre-calculated alpha value
            ),
          ),
        ],
      ],
    );
  }

  IconData _getIconForType(ResultType type) {
    switch (type) {
      case ResultType.creator:
        return Icons.person;
      case ResultType.category:
        return Icons.tag;
      case ResultType.content:
        return Icons.play_arrow;
    }
  }

  void _handleTap() {
    switch (result.type) {
      case ResultType.creator:
        final user = User(
          id: result.id,
          username: result.title,
          displayName: result.title,
          bio: result.subtitle,
          avatarURL: result.imageURL,
          onlineStatus: 'online',
        );
        onProfileTap(user);
        break;
      case ResultType.content:
        final clip = VideoClip(
          id: result.id,
          title: result.title,
          videoURL: '',
          thumbnailURL: result.imageURL,
          views: 0,
          likes: 0,
          comments: 0,
          categoryId: '',
          description: '',
          creator: result.subtitle,
          duration: 0.0,
          tags: const [],
          score: 0.0,
        );
        onVideoTap(clip);
        break;
      case ResultType.category:
        final categoryId = result.id;
        onCategoryTap(categoryId);
        break;
    }
  }
}
