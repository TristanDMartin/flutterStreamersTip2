import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../widgets/optimized_image.dart';
import '../widgets/optimized_avatar_image.dart';
import '../widgets/ios_optimized_image.dart';
import '../services/image_preload_service.dart';

class DiscoverView extends StatefulWidget {
  const DiscoverView({super.key});

  @override
  State<DiscoverView> createState() => _DiscoverViewState();
}

class _DiscoverViewState extends State<DiscoverView> {
  @override
  void initState() {
    super.initState();
    // Preload critical images for better UX
    ImagePreloadService.preloadCriticalImages();
  }

  // Platform-specific image widget selection
  Widget _buildPlatformImage({
    required String imageUrl,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
    BorderRadius? borderRadius,
  }) {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return IOSOptimizedImage(
        imageUrl: imageUrl,
        width: width,
        height: height,
        fit: fit,
        placeholder: placeholder,
        errorWidget: errorWidget,
        borderRadius: borderRadius,
      );
    } else {
      return OptimizedImage(
        imageUrl: imageUrl,
        width: width,
        height: height,
        fit: fit,
        placeholder: placeholder,
        errorWidget: errorWidget,
        borderRadius: borderRadius,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6137EB), Color(0xFF1C135D)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom App Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.arrow_back_ios,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const Text(
                      'Discover',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Trending Topics',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          _buildTrendingTopic('Gaming', '🎮', Colors.purple),
          _buildTrendingTopic('Streaming', '📺', Colors.blue),
          _buildTrendingTopic('Esports', '🏆', Colors.green),
          _buildTrendingTopic('Content Creation', '✨', Colors.orange),
          const SizedBox(height: 30),
          const Text(
            'Popular Creators',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          _buildCreatorCard('GamingPro', '2.5M followers', 'https://via.placeholder.com/60x60/9248D2/FFFFFF'),
          _buildCreatorCard('StreamMaster', '1.8M followers', 'https://via.placeholder.com/60x60/1670DE/FFFFFF'),
          _buildCreatorCard('ContentKing', '3.2M followers', 'https://via.placeholder.com/60x60/4CAF50/FFFFFF'),
          const SizedBox(height: 20),
          _buildLazyLoadedContent(),
        ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrendingTopic(String title, String emoji, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Text(
            emoji,
            style: const TextStyle(fontSize: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(1000 + (title.length * 100)).toString()} posts',
                  style: TextStyle(
                    color: color.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios,
            color: color.withValues(alpha: 0.7),
            size: 16,
          ),
        ],
      ),
    );
  }

  Widget _buildCreatorCard(String name, String followers, String avatarUrl) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          OptimizedAvatarImage(
            imageUrl: avatarUrl,
            size: 30,
            placeholder: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person,
                color: Colors.white,
                size: 28,
              ),
            ),
            errorWidget: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  followers,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text('Follow'),
          ),
        ],
      ),
    );
  }

  Widget _buildLazyLoadedContent() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadLazyContent(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Failed to load content: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        final content = snapshot.data ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Featured Content',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ...content.map((item) => _buildFeaturedItem(item)).toList(),
          ],
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _loadLazyContent() async {
    // Simulate network delay for lazy loading
    await Future.delayed(const Duration(seconds: 1));
    
    return [
      {
        'title': 'Gaming Highlights',
        'subtitle': 'Best moments from this week',
        'imageUrl': 'https://via.placeholder.com/300x200/9248D2/FFFFFF?text=Gaming',
        'views': '2.3M views',
      },
      {
        'title': 'Streaming Tips',
        'subtitle': 'How to grow your audience',
        'imageUrl': 'https://via.placeholder.com/300x200/1670DE/FFFFFF?text=Streaming',
        'views': '1.8M views',
      },
      {
        'title': 'Esports Tournament',
        'subtitle': 'Championship finals',
        'imageUrl': 'https://via.placeholder.com/300x200/4CAF50/FFFFFF?text=Esports',
        'views': '5.2M views',
      },
    ];
  }

  Widget _buildFeaturedItem(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: _buildPlatformImage(
              imageUrl: item['imageUrl'],
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: Container(
                height: 200,
                color: Colors.grey[800],
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
                  ),
                ),
              ),
              errorWidget: Container(
                height: 200,
                color: Colors.grey[800],
                child: const Center(
                  child: Icon(
                    Icons.error_outline,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['title'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item['subtitle'],
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item['views'],
                  style: const TextStyle(
                    color: Colors.purple,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
