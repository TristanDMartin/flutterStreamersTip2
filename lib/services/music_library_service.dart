import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class MusicTrack {
  final String id;
  final String title;
  final String artist;
  final String genre;
  final Duration duration;
  final String downloadUrl;
  final String? previewUrl;
  final String license;
  final bool requiresAttribution;
  final String? attributionText;
  final String? thumbnailUrl;
  final int fileSizeBytes;

  const MusicTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.genre,
    required this.duration,
    required this.downloadUrl,
    this.previewUrl,
    required this.license,
    required this.requiresAttribution,
    this.attributionText,
    this.thumbnailUrl,
    required this.fileSizeBytes,
  });

  factory MusicTrack.fromJson(Map<String, dynamic> json) {
    return MusicTrack(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Unknown Title',
      artist: json['artist'] ?? 'Unknown Artist',
      genre: json['genre'] ?? 'Unknown',
      duration: Duration(seconds: json['duration'] ?? 0),
      downloadUrl: json['downloadUrl'] ?? '',
      previewUrl: json['previewUrl'],
      license: json['license'] ?? 'Unknown',
      requiresAttribution: json['requiresAttribution'] ?? false,
      attributionText: json['attributionText'],
      thumbnailUrl: json['thumbnailUrl'],
      fileSizeBytes: json['fileSizeBytes'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'genre': genre,
      'duration': duration.inSeconds,
      'downloadUrl': downloadUrl,
      'previewUrl': previewUrl,
      'license': license,
      'requiresAttribution': requiresAttribution,
      'attributionText': attributionText,
      'thumbnailUrl': thumbnailUrl,
      'fileSizeBytes': fileSizeBytes,
    };
  }
}

class MusicLibraryService {
  static final MusicLibraryService _instance = MusicLibraryService._internal();
  factory MusicLibraryService() => _instance;
  MusicLibraryService._internal();

  // Free music sources
  static const String _freesoundApiKey = 'YOUR_FREESOUND_API_KEY'; // Get from https://freesound.org/
  static const String _freesoundBaseUrl = 'https://freesound.org/apiv2';
  
  // Curated free music collection (no API key required)
  static const List<Map<String, dynamic>> _curatedMusic = [
    {
      'id': 'happy_upbeat_1',
      'title': 'Happy Upbeat',
      'artist': 'Free Music Archive',
      'genre': 'Upbeat',
      'duration': 120,
      'downloadUrl': 'https://files.freemusicarchive.org/storage-freemusicarchive-org/music/ccCommunity/Chad_Crouch/Arps/Chad_Crouch_-_01_-_Bicycle_Ride.mp3',
      'license': 'CC BY',
      'requiresAttribution': true,
      'attributionText': 'Music by Chad Crouch',
      'fileSizeBytes': 2000000,
    },
    {
      'id': 'ambient_chill_1',
      'title': 'Ambient Chill',
      'artist': 'Incompetech',
      'genre': 'Ambient',
      'duration': 180,
      'downloadUrl': 'https://incompetech.com/music/royalty-free/music/Ambient_Chill.mp3',
      'license': 'CC BY',
      'requiresAttribution': true,
      'attributionText': 'Music by Kevin MacLeod',
      'fileSizeBytes': 3000000,
    },
    {
      'id': 'electronic_beat_1',
      'title': 'Electronic Beat',
      'artist': 'Bensound',
      'genre': 'Electronic',
      'duration': 150,
      'downloadUrl': 'https://www.bensound.com/bensound-music/bensound-sunny.mp3',
      'license': 'Royalty Free',
      'requiresAttribution': true,
      'attributionText': 'Music by Bensound',
      'fileSizeBytes': 2500000,
    },
    {
      'id': 'acoustic_guitar_1',
      'title': 'Acoustic Guitar',
      'artist': 'Free Music Archive',
      'genre': 'Acoustic',
      'duration': 200,
      'downloadUrl': 'https://files.freemusicarchive.org/storage-freemusicarchive-org/music/ccCommunity/Chad_Crouch/Arps/Chad_Crouch_-_02_-_Acoustic_Guitar.mp3',
      'license': 'CC BY',
      'requiresAttribution': true,
      'attributionText': 'Music by Chad Crouch',
      'fileSizeBytes': 3500000,
    },
    {
      'id': 'cinematic_epic_1',
      'title': 'Cinematic Epic',
      'artist': 'Incompetech',
      'genre': 'Cinematic',
      'duration': 240,
      'downloadUrl': 'https://incompetech.com/music/royalty-free/music/Cinematic_Epic.mp3',
      'license': 'CC BY',
      'requiresAttribution': true,
      'attributionText': 'Music by Kevin MacLeod',
      'fileSizeBytes': 4000000,
    },
    {
      'id': 'jazz_smooth_1',
      'title': 'Smooth Jazz',
      'artist': 'Bensound',
      'genre': 'Jazz',
      'duration': 160,
      'downloadUrl': 'https://www.bensound.com/bensound-music/bensound-jazz.mp3',
      'license': 'Royalty Free',
      'requiresAttribution': true,
      'attributionText': 'Music by Bensound',
      'fileSizeBytes': 2800000,
    },
  ];

  /// Search for music tracks by genre, mood, or keywords
  Future<List<MusicTrack>> searchMusic({
    String? query,
    String? genre,
    String? mood,
    int limit = 20,
  }) async {
    try {
      // For now, return curated music filtered by criteria
      List<Map<String, dynamic>> filteredMusic = List.from(_curatedMusic);
      
      if (query != null && query.isNotEmpty) {
        filteredMusic = filteredMusic.where((track) {
          final searchQuery = query.toLowerCase();
          return track['title'].toLowerCase().contains(searchQuery) ||
                 track['artist'].toLowerCase().contains(searchQuery) ||
                 track['genre'].toLowerCase().contains(searchQuery);
        }).toList();
      }
      
      if (genre != null && genre.isNotEmpty) {
        filteredMusic = filteredMusic.where((track) {
          return track['genre'].toLowerCase() == genre.toLowerCase();
        }).toList();
      }
      
      // Apply limit
      if (filteredMusic.length > limit) {
        filteredMusic = filteredMusic.take(limit).toList();
      }
      
      return filteredMusic.map((json) => MusicTrack.fromJson(json)).toList();
    } catch (e) {
    // print('Error searching music: $e');
      return [];
    }
  }

  /// Get music by genre
  Future<List<MusicTrack>> getMusicByGenre(String genre) async {
    return searchMusic(genre: genre);
  }

  /// Get popular music tracks
  Future<List<MusicTrack>> getPopularMusic({int limit = 10}) async {
    return searchMusic(limit: limit);
  }

  /// Get music by mood
  Future<List<MusicTrack>> getMusicByMood(String mood) async {
    // Map moods to genres
    final moodToGenre = {
      'happy': 'Upbeat',
      'sad': 'Ambient',
      'energetic': 'Electronic',
      'calm': 'Ambient',
      'romantic': 'Acoustic',
      'dramatic': 'Cinematic',
      'funky': 'Jazz',
    };
    
    final genre = moodToGenre[mood.toLowerCase()] ?? 'Upbeat';
    return getMusicByGenre(genre);
  }

  /// Download music track to local storage
  Future<String?> downloadTrack(MusicTrack track) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final fileName = '${track.id}_${DateTime.now().millisecondsSinceEpoch}.mp3';
      final filePath = path.join(tempDir.path, fileName);
      
      final response = await http.get(Uri.parse(track.downloadUrl));
      
      if (response.statusCode == 200) {
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        return filePath;
      } else {
    // print('Failed to download track: ${response.statusCode}');
        return null;
      }
    } catch (e) {
    // print('Error downloading track: $e');
      return null;
    }
  }

  /// Get available genres
  List<String> getAvailableGenres() {
    return ['Upbeat', 'Ambient', 'Electronic', 'Acoustic', 'Cinematic', 'Jazz'];
  }

  /// Get available moods
  List<String> getAvailableMoods() {
    return ['Happy', 'Sad', 'Energetic', 'Calm', 'Romantic', 'Dramatic', 'Funky'];
  }

  /// Get track preview URL (if available)
  String? getTrackPreviewUrl(MusicTrack track) {
    return track.previewUrl;
  }

  /// Check if track requires attribution
  bool requiresAttribution(MusicTrack track) {
    return track.requiresAttribution;
  }

  /// Get attribution text for track
  String? getAttributionText(MusicTrack track) {
    return track.attributionText;
  }

  /// Get track duration in formatted string
  String getFormattedDuration(MusicTrack track) {
    final minutes = track.duration.inMinutes;
    final seconds = track.duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Get file size in formatted string
  String getFormattedFileSize(MusicTrack track) {
    final mb = track.fileSizeBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  /// Search Freesound API (requires API key)
  Future<List<MusicTrack>> searchFreesound({
    String? query,
    String? genre,
    int limit = 20,
  }) async {
    if (_freesoundApiKey == 'YOUR_FREESOUND_API_KEY') {
    // print('Freesound API key not configured. Using curated music instead.');
      return searchMusic(query: query, genre: genre, limit: limit);
    }

    try {
      final searchQuery = query ?? 'music';
      final url = '$_freesoundBaseUrl/search/text/?query=$searchQuery&filter=type:mp3&page_size=$limit';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Token $_freesoundApiKey'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List;
        
        return results.map((item) {
          return MusicTrack(
            id: item['id'].toString(),
            title: item['name'] ?? 'Unknown Title',
            artist: 'Freesound',
            genre: genre ?? 'Unknown',
            duration: Duration(milliseconds: (item['duration'] ?? 0) * 1000),
            downloadUrl: item['previews']?['preview-hq-mp3'] ?? '',
            previewUrl: item['previews']?['preview-lq-mp3'],
            license: item['license'] ?? 'Unknown',
            requiresAttribution: true,
            attributionText: 'Sound from Freesound.org',
            fileSizeBytes: 0,
          );
        }).toList();
      } else {
    // print('Freesound API error: ${response.statusCode}');
        return searchMusic(query: query, genre: genre, limit: limit);
      }
    } catch (e) {
    // print('Freesound API error: $e');
      return searchMusic(query: query, genre: genre, limit: limit);
    }
  }

  /// Clean up downloaded tracks
  Future<void> cleanupDownloadedTracks() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final files = tempDir.listSync();
      
      for (final file in files) {
        if (file is File && file.path.endsWith('.mp3')) {
          await file.delete();
        }
      }
    } catch (e) {
    // print('Error cleaning up downloaded tracks: $e');
    }
  }
}
