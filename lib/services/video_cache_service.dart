import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class VideoCacheService {
  static final VideoCacheService _instance = VideoCacheService._internal();
  factory VideoCacheService() => _instance;
  VideoCacheService._internal();

  // Cache configuration
  static const int _maxCacheSize = 500 * 1024 * 1024; // 500MB
  static const int _maxCacheAge = 7 * 24 * 60 * 60; // 7 days in seconds
  static const int _maxCacheFiles = 100;

  // Cache state
  Directory? _cacheDirectory;
  final Map<String, CacheEntry> _cacheIndex = {};
  int _currentCacheSize = 0;
  bool _isInitialized = false;

  /// Initialize the cache service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Get cache directory
      final appDir = await getApplicationDocumentsDirectory();
      _cacheDirectory = Directory(path.join(appDir.path, 'video_cache'));
      
      // Create cache directory if it doesn't exist
      if (!await _cacheDirectory!.exists()) {
        await _cacheDirectory!.create(recursive: true);
      }

      // Load cache index
      await _loadCacheIndex();
      
      // Clean up old cache entries
      await _cleanupExpiredEntries();
      
      _isInitialized = true;
      print('📦 Video cache initialized: ${_currentCacheSize ~/ 1024}KB');
    } catch (e) {
      print('❌ Error initializing video cache: $e');
    }
  }

  /// Load cache index from SharedPreferences
  Future<void> _loadCacheIndex() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final indexJson = prefs.getString('video_cache_index');
      
      if (indexJson != null) {
        final indexData = json.decode(indexJson) as Map<String, dynamic>;
        _cacheIndex.clear();
        _currentCacheSize = 0;
        
        for (final entry in indexData.entries) {
          final entryData = entry.value as Map<String, dynamic>;
          final cacheEntry = CacheEntry.fromJson(entryData);
          _cacheIndex[entry.key] = cacheEntry;
          _currentCacheSize += cacheEntry.size;
        }
      }
    } catch (e) {
      print('❌ Error loading cache index: $e');
    }
  }

  /// Save cache index to SharedPreferences
  Future<void> _saveCacheIndex() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final indexData = <String, dynamic>{};
      
      for (final entry in _cacheIndex.entries) {
        indexData[entry.key] = entry.value.toJson();
      }
      
      await prefs.setString('video_cache_index', json.encode(indexData));
    } catch (e) {
      print('❌ Error saving cache index: $e');
    }
  }

  /// Generate cache key for video URL
  String _generateCacheKey(String videoUrl) {
    final bytes = utf8.encode(videoUrl);
    final digest = md5.convert(bytes);
    return digest.toString();
  }

  /// Check if video is cached
  bool isVideoCached(String videoUrl) {
    final key = _generateCacheKey(videoUrl);
    return _cacheIndex.containsKey(key) && _isCacheEntryValid(key);
  }

  /// Check if cache entry is valid (not expired)
  bool _isCacheEntryValid(String key) {
    final entry = _cacheIndex[key];
    if (entry == null) return false;
    
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return (now - entry.timestamp) < _maxCacheAge;
  }

  /// Get cached video file
  File? getCachedVideo(String videoUrl) {
    if (!isVideoCached(videoUrl)) return null;
    
    final key = _generateCacheKey(videoUrl);
    final entry = _cacheIndex[key];
    if (entry == null) return null;
    
    final file = File(path.join(_cacheDirectory!.path, entry.filename));
    return file.existsSync() ? file : null;
  }

  /// Cache video file
  Future<bool> cacheVideo(String videoUrl, File videoFile) async {
    if (!_isInitialized) await initialize();
    
    try {
      final key = _generateCacheKey(videoUrl);
      final filename = '$key.mp4';
      final cachedFile = File(path.join(_cacheDirectory!.path, filename));
      
      // Copy video file to cache
      await videoFile.copy(cachedFile.path);
      
      // Get file size
      final fileSize = await cachedFile.length();
      
      // Create cache entry
      final entry = CacheEntry(
        key: key,
        filename: filename,
        originalUrl: videoUrl,
        size: fileSize,
        timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      
      // Add to index
      _cacheIndex[key] = entry;
      _currentCacheSize += fileSize;
      
      // Save index
      await _saveCacheIndex();
      
      // Check if we need to clean up
      await _enforceCacheLimits();
      
      print('📦 Video cached: $videoUrl (${fileSize ~/ 1024}KB)');
      return true;
    } catch (e) {
      print('❌ Error caching video: $e');
      return false;
    }
  }

  /// Cache video thumbnail
  Future<bool> cacheThumbnail(String videoUrl, Uint8List thumbnailData) async {
    if (!_isInitialized) await initialize();
    
    try {
      final key = _generateCacheKey(videoUrl);
      final filename = '${key}_thumb.jpg';
      final cachedFile = File(path.join(_cacheDirectory!.path, filename));
      
      // Write thumbnail data
      await cachedFile.writeAsBytes(thumbnailData);
      
      print('📦 Thumbnail cached: $videoUrl');
      return true;
    } catch (e) {
      print('❌ Error caching thumbnail: $e');
      return false;
    }
  }

  /// Get cached thumbnail
  File? getCachedThumbnail(String videoUrl) {
    final key = _generateCacheKey(videoUrl);
    final filename = '${key}_thumb.jpg';
    final file = File(path.join(_cacheDirectory!.path, filename));
    return file.existsSync() ? file : null;
  }

  /// Enforce cache size limits
  Future<void> _enforceCacheLimits() async {
    // Check cache size limit
    if (_currentCacheSize > _maxCacheSize) {
      await _cleanupOldestEntries();
    }
    
    // Check file count limit
    if (_cacheIndex.length > _maxCacheFiles) {
      await _cleanupOldestEntries();
    }
  }

  /// Clean up oldest cache entries
  Future<void> _cleanupOldestEntries() async {
    // Sort entries by timestamp (oldest first)
    final sortedEntries = _cacheIndex.entries.toList()
      ..sort((a, b) => a.value.timestamp.compareTo(b.value.timestamp));
    
    // Remove oldest entries until we're under limits
    while ((_currentCacheSize > _maxCacheSize || _cacheIndex.length > _maxCacheFiles) && 
           sortedEntries.isNotEmpty) {
      final entry = sortedEntries.removeAt(0);
      await _removeCacheEntry(entry.key);
    }
  }

  /// Clean up expired entries
  Future<void> _cleanupExpiredEntries() async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final expiredKeys = <String>[];
    
    for (final entry in _cacheIndex.entries) {
      if ((now - entry.value.timestamp) >= _maxCacheAge) {
        expiredKeys.add(entry.key);
      }
    }
    
    for (final key in expiredKeys) {
      await _removeCacheEntry(key);
    }
  }

  /// Remove cache entry
  Future<void> _removeCacheEntry(String key) async {
    final entry = _cacheIndex.remove(key);
    if (entry == null) return;
    
    try {
      // Remove video file
      final videoFile = File(path.join(_cacheDirectory!.path, entry.filename));
      if (await videoFile.exists()) {
        await videoFile.delete();
      }
      
      // Remove thumbnail file
      final thumbnailFile = File(path.join(_cacheDirectory!.path, '${entry.filename}_thumb.jpg'));
      if (await thumbnailFile.exists()) {
        await thumbnailFile.delete();
      }
      
      _currentCacheSize -= entry.size;
    } catch (e) {
      print('❌ Error removing cache entry: $e');
    }
  }

  /// Clear all cache
  Future<void> clearCache() async {
    try {
      // Remove all files
      if (_cacheDirectory != null && await _cacheDirectory!.exists()) {
        await _cacheDirectory!.delete(recursive: true);
        await _cacheDirectory!.create(recursive: true);
      }
      
      // Clear index
      _cacheIndex.clear();
      _currentCacheSize = 0;
      
      // Save empty index
      await _saveCacheIndex();
      
      print('📦 Cache cleared');
    } catch (e) {
      print('❌ Error clearing cache: $e');
    }
  }

  /// Get cache statistics
  CacheStatistics getCacheStatistics() {
    return CacheStatistics(
      totalFiles: _cacheIndex.length,
      totalSize: _currentCacheSize,
      maxSize: _maxCacheSize,
      maxFiles: _maxCacheFiles,
      usagePercentage: (_currentCacheSize / _maxCacheSize * 100).round(),
    );
  }

  /// Dispose resources
  void dispose() {
    _cacheIndex.clear();
    _currentCacheSize = 0;
  }
}

/// Cache entry data class
class CacheEntry {
  final String key;
  final String filename;
  final String originalUrl;
  final int size;
  final int timestamp;

  CacheEntry({
    required this.key,
    required this.filename,
    required this.originalUrl,
    required this.size,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'key': key,
    'filename': filename,
    'originalUrl': originalUrl,
    'size': size,
    'timestamp': timestamp,
  };

  factory CacheEntry.fromJson(Map<String, dynamic> json) => CacheEntry(
    key: json['key'] as String,
    filename: json['filename'] as String,
    originalUrl: json['originalUrl'] as String,
    size: json['size'] as int,
    timestamp: json['timestamp'] as int,
  );
}

/// Cache statistics
class CacheStatistics {
  final int totalFiles;
  final int totalSize;
  final int maxSize;
  final int maxFiles;
  final int usagePercentage;

  CacheStatistics({
    required this.totalFiles,
    required this.totalSize,
    required this.maxSize,
    required this.maxFiles,
    required this.usagePercentage,
  });

  String get formattedSize => '${(totalSize / 1024 / 1024).toStringAsFixed(1)}MB';
  String get formattedMaxSize => '${(maxSize / 1024 / 1024).toStringAsFixed(1)}MB';
  bool get isNearLimit => usagePercentage > 80;
}
