import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'logging_service.dart';

class CachingService {
  static final CachingService _instance = CachingService._internal();
  factory CachingService() => _instance;
  CachingService._internal();

  SharedPreferences? _prefs;
  Map<String, dynamic> _memoryCache = {};
  static const int _maxMemoryCacheSize = 50;
  static const Duration _defaultCacheExpiry = Duration(hours: 24);

  Future<SharedPreferences> get prefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // Memory Cache Management
  Future<void> setMemoryCache(String key, dynamic value, {Duration? expiry}) async {
    try {
      final cacheItem = {
        'value': value,
        'expiry': expiry != null 
          ? DateTime.now().add(expiry).millisecondsSinceEpoch 
          : DateTime.now().add(_defaultCacheExpiry).millisecondsSinceEpoch,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      };

      // Remove oldest items if cache is full
      if (_memoryCache.length >= _maxMemoryCacheSize) {
        final oldestKey = _memoryCache.keys.first;
        _memoryCache.remove(oldestKey);
      }

      _memoryCache[key] = cacheItem;
      
      LoggingService.instance.debug('Memory cache set: $key', tag: 'CachingService');
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to set memory cache',
        tag: 'CachingService',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  T? getMemoryCache<T>(String key) {
    try {
      final item = _memoryCache[key];
      if (item == null) return null;

      final now = DateTime.now().millisecondsSinceEpoch;
      if (now > item['expiry']) {
        _memoryCache.remove(key);
        return null;
      }

      return item['value'] as T?;
    } catch (e) {
      LoggingService.instance.error(
        'Failed to get memory cache: $key',
        tag: 'CachingService',
        error: e,
      );
      return null;
    }
  }

  void clearMemoryCache() {
    _memoryCache.clear();
    LoggingService.instance.info('Memory cache cleared', tag: 'CachingService');
  }

  // Persistent Cache Management
  Future<void> setPersistentCache(String key, dynamic value, {Duration? expiry}) async {
    try {
      final prefs = await this.prefs;
      final cacheItem = {
        'value': value,
        'expiry': expiry != null 
          ? DateTime.now().add(expiry).millisecondsSinceEpoch 
          : DateTime.now().add(_defaultCacheExpiry).millisecondsSinceEpoch,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      };

      await prefs.setString('cache_$key', jsonEncode(cacheItem));
      
      LoggingService.instance.debug('Persistent cache set: $key', tag: 'CachingService');
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to set persistent cache',
        tag: 'CachingService',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<T?> getPersistentCache<T>(String key) async {
    try {
      final prefs = await this.prefs;
      final cacheString = prefs.getString('cache_$key');
      if (cacheString == null) return null;

      final cacheItem = jsonDecode(cacheString);
      final now = DateTime.now().millisecondsSinceEpoch;
      
      if (now > cacheItem['expiry']) {
        await prefs.remove('cache_$key');
        return null;
      }

      return cacheItem['value'] as T?;
    } catch (e) {
      LoggingService.instance.error(
        'Failed to get persistent cache: $key',
        tag: 'CachingService',
        error: e,
      );
      return null;
    }
  }

  Future<void> clearPersistentCache() async {
    try {
      final prefs = await this.prefs;
      final keys = prefs.getKeys().where((key) => key.startsWith('cache_'));
      for (final key in keys) {
        await prefs.remove(key);
      }
      LoggingService.instance.info('Persistent cache cleared', tag: 'CachingService');
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to clear persistent cache',
        tag: 'CachingService',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // File Cache Management
  Future<String> getCacheDirectory() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${directory.path}/cache');
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }
      return cacheDir.path;
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to get cache directory',
        tag: 'CachingService',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> setFileCache(String key, String content, {Duration? expiry}) async {
    try {
      final cacheDir = await getCacheDirectory();
      final file = File('$cacheDir/$key');
      
      final cacheItem = {
        'content': content,
        'expiry': expiry != null 
          ? DateTime.now().add(expiry).millisecondsSinceEpoch 
          : DateTime.now().add(_defaultCacheExpiry).millisecondsSinceEpoch,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      };

      await file.writeAsString(jsonEncode(cacheItem));
      
      LoggingService.instance.debug('File cache set: $key', tag: 'CachingService');
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to set file cache',
        tag: 'CachingService',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<String?> getFileCache(String key) async {
    try {
      final cacheDir = await getCacheDirectory();
      final file = File('$cacheDir/$key');
      
      if (!await file.exists()) return null;

      final content = await file.readAsString();
      final cacheItem = jsonDecode(content);
      final now = DateTime.now().millisecondsSinceEpoch;
      
      if (now > cacheItem['expiry']) {
        await file.delete();
        return null;
      }

      return cacheItem['content'] as String?;
    } catch (e) {
      LoggingService.instance.error(
        'Failed to get file cache: $key',
        tag: 'CachingService',
        error: e,
      );
      return null;
    }
  }

  Future<void> clearFileCache() async {
    try {
      final cacheDir = await getCacheDirectory();
      final directory = Directory(cacheDir);
      if (await directory.exists()) {
        await directory.delete(recursive: true);
        await directory.create(recursive: true);
      }
      LoggingService.instance.info('File cache cleared', tag: 'CachingService');
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to clear file cache',
        tag: 'CachingService',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // Image Cache Management
  Future<String?> getCachedImagePath(String imageUrl) async {
    try {
      final hash = md5.convert(utf8.encode(imageUrl)).toString();
      final cacheDir = await getCacheDirectory();
      final imageFile = File('$cacheDir/images/$hash');
      
      if (await imageFile.exists()) {
        return imageFile.path;
      }
      return null;
    } catch (e) {
      LoggingService.instance.error(
        'Failed to get cached image path: $imageUrl',
        tag: 'CachingService',
        error: e,
      );
      return null;
    }
  }

  Future<String> cacheImage(String imageUrl, List<int> imageBytes) async {
    try {
      final hash = md5.convert(utf8.encode(imageUrl)).toString();
      final cacheDir = await getCacheDirectory();
      final imagesDir = Directory('$cacheDir/images');
      
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      final imageFile = File('${imagesDir.path}/$hash');
      await imageFile.writeAsBytes(imageBytes);
      
      LoggingService.instance.debug('Image cached: $imageUrl', tag: 'CachingService');
      return imageFile.path;
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to cache image: $imageUrl',
        tag: 'CachingService',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // Cache Statistics
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final prefs = await this.prefs;
      final keys = prefs.getKeys().where((key) => key.startsWith('cache_'));
      
      int expiredCount = 0;
      int validCount = 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      for (final key in keys) {
        try {
          final cacheString = prefs.getString(key);
          if (cacheString != null) {
            final cacheItem = jsonDecode(cacheString);
            if (now > cacheItem['expiry']) {
              expiredCount++;
            } else {
              validCount++;
            }
          }
        } catch (e) {
          // Skip invalid cache items
        }
      }

      return {
        'memory_cache_size': _memoryCache.length,
        'persistent_cache_valid': validCount,
        'persistent_cache_expired': expiredCount,
        'total_persistent_cache': keys.length,
      };
    } catch (e) {
      return {
        'memory_cache_size': _memoryCache.length,
        'persistent_cache_valid': 0,
        'persistent_cache_expired': 0,
        'total_persistent_cache': 0,
      };
    }
  }

  // Cleanup expired cache
  Future<void> cleanupExpiredCache() async {
    try {
      final prefs = await this.prefs;
      final keys = prefs.getKeys().where((key) => key.startsWith('cache_'));
      final now = DateTime.now().millisecondsSinceEpoch;
      int cleanedCount = 0;

      for (final key in keys) {
        try {
          final cacheString = prefs.getString(key);
          if (cacheString != null) {
            final cacheItem = jsonDecode(cacheString);
            if (now > cacheItem['expiry']) {
              await prefs.remove(key);
              cleanedCount++;
            }
          }
        } catch (e) {
          // Remove invalid cache items
          await prefs.remove(key);
          cleanedCount++;
        }
      }

      // Clean memory cache
      final memoryKeysToRemove = <String>[];
      for (final entry in _memoryCache.entries) {
        if (now > entry.value['expiry']) {
          memoryKeysToRemove.add(entry.key);
        }
      }
      for (final key in memoryKeysToRemove) {
        _memoryCache.remove(key);
      }

      LoggingService.instance.info(
        'Cache cleanup completed: $cleanedCount persistent items, ${memoryKeysToRemove.length} memory items',
        tag: 'CachingService',
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to cleanup expired cache',
        tag: 'CachingService',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // Clear all cache
  Future<void> clearAllCache() async {
    clearMemoryCache();
    await clearPersistentCache();
    await clearFileCache();
    LoggingService.instance.info('All cache cleared', tag: 'CachingService');
  }
}
