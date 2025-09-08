import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/discover_provider.dart';
import '../models/user.dart';
import '../models/video_clip.dart';
import 'optimized_image.dart';

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
  Timer? _searchTimer;

  @override
  void initState() {
    super.initState();
    _debouncedSearch();
  }

  @override
  void didUpdateWidget(SearchResultsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchText != widget.searchText) {
      _debouncedSearch();
    }
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    super.dispose();
  }

  void _debouncedSearch() {
    // Cancel previous search timer
    _searchTimer?.cancel();
    
    // Create new search timer
    _searchTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        _performSearch();
      }
    });
  }

  Future<void> _performSearch() async {
    try {
      if (widget.searchText.isNotEmpty) {
        await widget.viewModel.search(widget.searchText);
      }
      // Search completed
    } catch (e) {
      // Error handling is done in the viewModel
      // Search completed
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchResults = ref.watch(discoverProvider).searchResults;
    
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
              // TODO: Navigate to StreamerCardView
            },
            onVideoTap: (clip) {
              // TODO: Navigate to CategoryVideoViewer
            },
            onCategoryTap: (categoryId) {
              // TODO: Navigate to CategoryVideoViewer with category
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
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
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
    if (result.imageURL != null) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey.withValues(alpha: 0.1),
        ),
        child: ClipOval(
          child: OptimizedImage(
            imageUrl: result.imageURL!,
            width: 40,
            height: 40,
            fit: BoxFit.cover,
          ),
        ),
      );
    } else {
      return _buildIconPlaceholder();
    }
  }

  Widget _buildIconPlaceholder() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey.withValues(alpha: 0.1),
      ),
      child: Icon(
        _getIconForType(result.type),
        color: Colors.blue,
        size: 16,
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
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
        
        if (result.metadata != null) ...[
          const SizedBox(height: 2),
          Text(
            result.metadata!,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.5),
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
