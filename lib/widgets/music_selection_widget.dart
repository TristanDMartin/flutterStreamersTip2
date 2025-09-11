import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/music_library_service.dart';
import 'instant_response_button.dart';

class MusicSelectionWidget extends StatefulWidget {
  final Function(MusicTrack?) onMusicSelected;
  final MusicTrack? selectedTrack;

  const MusicSelectionWidget({
    super.key,
    required this.onMusicSelected,
    this.selectedTrack,
  });

  @override
  State<MusicSelectionWidget> createState() => _MusicSelectionWidgetState();
}

class _MusicSelectionWidgetState extends State<MusicSelectionWidget>
    with TickerProviderStateMixin {
  final MusicLibraryService _musicService = MusicLibraryService();
  final TextEditingController _searchController = TextEditingController();
  
  List<MusicTrack> _tracks = [];
  List<MusicTrack> _filteredTracks = [];
  bool _isLoading = false;
  String _selectedGenre = 'All';
  String _selectedMood = 'All';
  
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadMusic();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMusic() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final tracks = await _musicService.getPopularMusic(limit: 20);
      setState(() {
        _tracks = tracks;
        _filteredTracks = tracks;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Failed to load music: $e');
    }
  }

  void _filterTracks() {
    setState(() {
      if (_selectedGenre == 'All' && _selectedMood == 'All' && _searchController.text.isEmpty) {
        _filteredTracks = _tracks;
      } else {
        _filteredTracks = _tracks.where((track) {
          bool matchesGenre = _selectedGenre == 'All' || track.genre == _selectedGenre;
          bool matchesMood = _selectedMood == 'All' || 
              _musicService.getAvailableMoods().any((mood) => 
                  mood.toLowerCase() == _selectedMood.toLowerCase() && 
                  _getMoodGenre(mood) == track.genre);
          bool matchesSearch = _searchController.text.isEmpty ||
              track.title.toLowerCase().contains(_searchController.text.toLowerCase()) ||
              track.artist.toLowerCase().contains(_searchController.text.toLowerCase());
          
          return matchesGenre && matchesMood && matchesSearch;
        }).toList();
      }
    });
  }

  String _getMoodGenre(String mood) {
    final moodToGenre = {
      'Happy': 'Upbeat',
      'Sad': 'Ambient',
      'Energetic': 'Electronic',
      'Calm': 'Ambient',
      'Romantic': 'Acoustic',
      'Dramatic': 'Cinematic',
      'Funky': 'Jazz',
    };
    return moodToGenre[mood] ?? 'Upbeat';
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search music...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _filterTracks();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[100],
            ),
            onChanged: (value) => _filterTracks(),
          ),
        ),

        // Filter Tabs
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Genre'),
            Tab(text: 'Mood'),
            Tab(text: 'Popular'),
          ],
        ),

        // Filter Content
        SizedBox(
          height: 200,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildGenreFilter(),
              _buildMoodFilter(),
              _buildPopularFilter(),
            ],
          ),
        ),

        // Music List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredTracks.isEmpty
                  ? const Center(
                      child: Text(
                        'No music found',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredTracks.length,
                      itemBuilder: (context, index) {
                        final track = _filteredTracks[index];
                        final isSelected = widget.selectedTrack?.id == track.id;
                        
                        return _buildTrackItem(track, isSelected);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildGenreFilter() {
    final genres = ['All', ..._musicService.getAvailableGenres()];
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: genres.length,
        itemBuilder: (context, index) {
          final genre = genres[index];
          final isSelected = _selectedGenre == genre;
          
          return InstantResponseButton(
            onPressed: () {
              setState(() {
                _selectedGenre = genre;
              });
              _filterTracks();
            },
            hapticType: HapticFeedbackType.selectionClick,
            child: Container(
              decoration: BoxDecoration(
                color: isSelected ? Colors.blue : Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  genre,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMoodFilter() {
    final moods = ['All', ..._musicService.getAvailableMoods()];
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: moods.length,
        itemBuilder: (context, index) {
          final mood = moods[index];
          final isSelected = _selectedMood == mood;
          
          return InstantResponseButton(
            onPressed: () {
              setState(() {
                _selectedMood = mood;
              });
              _filterTracks();
            },
            hapticType: HapticFeedbackType.selectionClick,
            child: Container(
              decoration: BoxDecoration(
                color: isSelected ? Colors.purple : Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  mood,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPopularFilter() {
    return const Center(
      child: Text(
        'Popular tracks are shown above',
        style: TextStyle(
          fontSize: 16,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildTrackItem(MusicTrack track, bool isSelected) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue.withValues(alpha:0.1) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: isSelected ? Border.all(color: Colors.blue, width: 2) : null,
      ),
      child: InstantResponseButton(
        onPressed: () {
          HapticFeedback.selectionClick();
          widget.onMusicSelected(isSelected ? null : track);
        },
        hapticType: HapticFeedbackType.selectionClick,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Track Icon
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.music_note,
                  color: Colors.blue,
                  size: 24,
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Track Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      track.artist,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          track.genre,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _musicService.getFormattedDuration(track),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _musicService.getFormattedFileSize(track),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Selection Indicator
              if (isSelected)
                const Icon(
                  Icons.check_circle,
                  color: Colors.blue,
                  size: 24,
                )
              else
                const Icon(
                  Icons.radio_button_unchecked,
                  color: Colors.grey,
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
