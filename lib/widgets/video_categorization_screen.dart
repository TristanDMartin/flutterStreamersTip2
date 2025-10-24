import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/video_categorization_service.dart';

class VideoCategorizationScreen extends ConsumerStatefulWidget {
  const VideoCategorizationScreen({super.key});

  @override
  ConsumerState<VideoCategorizationScreen> createState() =>
      _VideoCategorizationScreenState();
}

class _VideoCategorizationScreenState
    extends ConsumerState<VideoCategorizationScreen> {
  bool _isCategorizing = false;
  Map<String, int> _categoryStats = {};
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _loadCategoryStats();
  }

  Future<void> _loadCategoryStats() async {
    try {
      final stats = await VideoCategorizationService.getCategoryStats();
      if (mounted) {
        setState(() {
          _categoryStats = stats;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Error loading stats: $e';
        });
      }
    }
  }

  Future<void> _categorizeAllVideos() async {
    setState(() {
      _isCategorizing = true;
      _statusMessage = 'Starting video categorization...';
    });

    try {
      final stats =
          await VideoCategorizationService.categorizeAllExistingVideos();

      if (mounted) {
        setState(() {
          _isCategorizing = false;
          _categoryStats = stats;
          _statusMessage = '✅ Successfully categorized all videos!';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCategorizing = false;
          _statusMessage = '❌ Error: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Categorization'),
        backgroundColor: const Color(0xFF9248D2),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text(
              'Categorize Existing Videos',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF9248D2),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This will analyze your video content and assign appropriate categories based on captions and hashtags.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),

            // Status Message
            if (_statusMessage.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _statusMessage.contains('✅')
                      ? Colors.green.withOpacity(0.1)
                      : _statusMessage.contains('❌')
                          ? Colors.red.withOpacity(0.1)
                          : Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _statusMessage.contains('✅')
                        ? Colors.green
                        : _statusMessage.contains('❌')
                            ? Colors.red
                            : Colors.blue,
                  ),
                ),
                child: Text(
                  _statusMessage,
                  style: TextStyle(
                    color: _statusMessage.contains('✅')
                        ? Colors.green[700]
                        : _statusMessage.contains('❌')
                            ? Colors.red[700]
                            : Colors.blue[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            const SizedBox(height: 24),

            // Categorize Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isCategorizing ? null : _categorizeAllVideos,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9248D2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isCategorizing
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Categorizing Videos...'),
                        ],
                      )
                    : const Text(
                        'Categorize All Videos',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(height: 32),

            // Category Stats
            const Text(
              'Category Distribution',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF9248D2),
              ),
            ),
            const SizedBox(height: 16),

            if (_categoryStats.isEmpty)
              const Text(
                'No category data available. Run categorization to see stats.',
                style: TextStyle(color: Colors.grey),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _categoryStats.length,
                  itemBuilder: (context, index) {
                    final entry = _categoryStats.entries.toList()[index];
                    final category = entry.key;
                    final count = entry.value;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getCategoryColor(category),
                          child: Text(
                            category[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          _getCategoryDisplayName(category),
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text('$count videos'),
                        trailing: Text(
                          '${((count / _categoryStats.values.reduce((a, b) => a + b)) * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF9248D2),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'gaming':
        return const Color(0xFF9C27B0);
      case 'music':
        return const Color(0xFFE91E63);
      case 'art':
        return const Color(0xFF2196F3);
      case 'tech':
        return const Color(0xFF4CAF50);
      case 'sports':
        return const Color(0xFFFF9800);
      case 'food':
        return const Color(0xFFF44336);
      case 'just-chatting':
        return const Color(0xFF00BCD4);
      case 'tutorials':
        return const Color(0xFF3F51B5);
      case 'fitness':
        return const Color(0xFF4DB6AC);
      case 'podcasts':
        return const Color(0xFF795548);
      case 'fashion':
        return const Color(0xFF9C27B0);
      case 'roleplay':
        return const Color(0xFFFFEB3B);
      default:
        return const Color(0xFF6633CC);
    }
  }

  String _getCategoryDisplayName(String category) {
    switch (category) {
      case 'gaming':
        return 'Gaming';
      case 'music':
        return 'Music';
      case 'art':
        return 'Art';
      case 'tech':
        return 'Tech';
      case 'sports':
        return 'Sports';
      case 'food':
        return 'Food';
      case 'just-chatting':
        return 'Just Chatting';
      case 'tutorials':
        return 'Tutorials';
      case 'fitness':
        return 'Fitness';
      case 'podcasts':
        return 'Podcasts';
      case 'fashion':
        return 'Fashion';
      case 'roleplay':
        return 'Roleplay';
      case 'uncategorized':
        return 'Uncategorized';
      default:
        return category.toUpperCase();
    }
  }
}
