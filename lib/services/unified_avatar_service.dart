import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Unified Avatar Service
///
/// Bulletproof avatar loading with aggressive caching, error handling,
/// and fallback mechanisms to ensure avatars always display.
class UnifiedAvatarService {
  static final UnifiedAvatarService _instance = UnifiedAvatarService._internal();
  factory UnifiedAvatarService() => _instance;
  UnifiedAvatarService._internal();

  // Memory cache for instant access
  final Map<String, ImageProvider> _memoryCache = {};
  final Map<String, bool> _loadingStates = {};
  
  // Cache directory
  Directory? _cacheDir;
  
  // Persistent cache for main user avatar
  static const String _mainUserAvatarKey = 'main_user_avatar_url';
  static const String _mainUserAvatarDataKey = 'main_user_avatar_data';

  /// Initialize the unified avatar service
  Future<void> initialize() async {
    try {
      _cacheDir = await getApplicationDocumentsDirectory();
      _cacheDir = Directory(path.join(_cacheDir!.path, 'unified_avatar_cache'));
      if (!await _cacheDir!.exists()) {
        await _cacheDir!.create(recursive: true);
      }
      
      // Load main user avatar from persistent storage
      await _loadMainUserAvatarFromStorage();
      
      debugPrint('✅ UnifiedAvatarService: Initialized with cache directory: ${_cacheDir!.path}');
    } catch (e) {
      debugPrint('❌ UnifiedAvatarService: Failed to initialize: $e');
    }
  }

  /// Get bulletproof avatar widget with ProfileView styling
  Widget getAvatar({
    required String imageUrl,
    double radius = 20,
    Widget? placeholder,
    Widget? errorWidget,
    bool showLoadingIndicator = true,
    bool useProfileViewStyling = true,
  }) {
    try {
      // Handle empty URLs
      if (imageUrl.isEmpty) {
        return _buildDefaultAvatar(radius, useProfileViewStyling);
      }

      // Validate URL
      final uri = Uri.tryParse(imageUrl);
      if (uri == null || !uri.hasAbsolutePath) {
        return _buildDefaultAvatar(radius, useProfileViewStyling);
      }

      // Check memory cache first
      if (_memoryCache.containsKey(imageUrl)) {
        return _buildProfileViewStyledAvatar(radius, imageUrl, useProfileViewStyling);
      }

      // Check if already loading
      if (_loadingStates[imageUrl] == true) {
        return placeholder ?? _buildLoadingAvatar(radius, showLoadingIndicator, useProfileViewStyling);
      }

      // Start loading
      _loadingStates[imageUrl] = true;

      return CachedNetworkImage(
        imageUrl: imageUrl,
        imageBuilder: (context, imageProvider) {
          try {
            // Cache the image provider
            _memoryCache[imageUrl] = imageProvider;
            _loadingStates[imageUrl] = false;
            
            return _buildProfileViewStyledAvatar(radius, imageUrl, useProfileViewStyling);
          } catch (e) {
            debugPrint('⚠️ UnifiedAvatarService: Error building cached avatar: $e');
            _loadingStates[imageUrl] = false;
            return _buildDefaultAvatar(radius, useProfileViewStyling);
          }
        },
        placeholder: (context, url) => placeholder ?? _buildLoadingAvatar(radius, showLoadingIndicator, useProfileViewStyling),
        errorWidget: (context, url, error) {
          _loadingStates[imageUrl] = false;
          debugPrint('⚠️ UnifiedAvatarService: Failed to load avatar $url: $error');
          return errorWidget ?? _buildDefaultAvatar(radius, useProfileViewStyling);
        },
        memCacheHeight: (radius * 2).toInt(),
        memCacheWidth: (radius * 2).toInt(),
        maxWidthDiskCache: (radius * 2).toInt(),
        maxHeightDiskCache: (radius * 2).toInt(),
        // Add error handling for invalid images
        httpHeaders: const {
          'User-Agent': 'Mozilla/5.0 (compatible; FlutterApp/1.0)',
        },
      );
    } catch (e) {
      debugPrint('❌ UnifiedAvatarService: Critical error in getAvatar: $e');
      return _buildDefaultAvatar(radius, useProfileViewStyling);
    }
  }

  /// Build ProfileView styled avatar
  Widget _buildProfileViewStyledAvatar(double radius, String imageUrl, bool useProfileViewStyling) {
    try {
      final imageProvider = _memoryCache[imageUrl];
      if (imageProvider == null) {
        return _buildDefaultAvatar(radius, useProfileViewStyling);
      }
      
      if (useProfileViewStyling) {
        return Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF0A0A0A), // Dark ring like ProfileView
          ),
          padding: const EdgeInsets.all(4), // 4px padding like ProfileView
          child: CircleAvatar(
            radius: radius,
            backgroundColor: Colors.grey[300],
            backgroundImage: imageProvider,
          ),
        );
      } else {
        return CircleAvatar(
          radius: radius,
          backgroundColor: Colors.grey[300],
          backgroundImage: imageProvider,
        );
      }
    } catch (e) {
      debugPrint('⚠️ UnifiedAvatarService: Error building cached avatar: $e');
      return _buildDefaultAvatar(radius, useProfileViewStyling);
    }
  }

  /// Build loading avatar with ProfileView styling
  Widget _buildLoadingAvatar(double radius, bool showLoadingIndicator, bool useProfileViewStyling) {
    final loadingAvatar = CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey[300],
      child: showLoadingIndicator
          ? SizedBox(
              width: radius * 0.6,
              height: radius * 0.6,
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
              ),
            )
          : null,
    );

    if (useProfileViewStyling) {
      return Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF0A0A0A), // Dark ring like ProfileView
        ),
        padding: const EdgeInsets.all(4), // 4px padding like ProfileView
        child: loadingAvatar,
      );
    } else {
      return loadingAvatar;
    }
  }

  /// Build default avatar with ProfileView styling
  Widget _buildDefaultAvatar(double radius, [bool useProfileViewStyling = true]) {
    final defaultAvatar = CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey[300],
      child: Icon(
        Icons.person,
        size: radius * 0.8,
        color: Colors.grey[600],
      ),
    );

    if (useProfileViewStyling) {
      return Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF0A0A0A), // Dark ring like ProfileView
        ),
        padding: const EdgeInsets.all(4), // 4px padding like ProfileView
        child: defaultAvatar,
      );
    } else {
      return defaultAvatar;
    }
  }

  /// Preload avatars for instant display
  Future<void> preloadAvatars(List<String> avatarUrls) async {
    if (avatarUrls.isEmpty) return;

    debugPrint('🔄 UnifiedAvatarService: Preloading ${avatarUrls.length} avatars...');
    
    final futures = avatarUrls.map((url) => _preloadSingleAvatar(url));
    await Future.wait(futures, eagerError: false);
    
    debugPrint('✅ UnifiedAvatarService: Preloaded ${_memoryCache.length} avatars');
  }

  /// Preload a single avatar
  Future<void> _preloadSingleAvatar(String url) async {
    if (url.isEmpty || _memoryCache.containsKey(url)) return;

    try {
      final imageProvider = CachedNetworkImageProvider(url);
      _memoryCache[url] = imageProvider;
      
      debugPrint('✅ UnifiedAvatarService: Preloaded avatar $url');
    } catch (e) {
      debugPrint('⚠️ UnifiedAvatarService: Failed to preload avatar $url: $e');
    }
  }

  /// Clear avatar cache
  Future<void> clearCache() async {
    try {
      _memoryCache.clear();
      _loadingStates.clear();
      
      if (_cacheDir != null && await _cacheDir!.exists()) {
        await _cacheDir!.delete(recursive: true);
        await _cacheDir!.create(recursive: true);
      }
      
      debugPrint('✅ UnifiedAvatarService: Cache cleared');
    } catch (e) {
      debugPrint('❌ UnifiedAvatarService: Failed to clear cache: $e');
    }
  }

  /// Get cache size
  Future<int> getCacheSize() async {
    try {
      if (_cacheDir == null || !await _cacheDir!.exists()) return 0;
      
      int totalSize = 0;
      await for (final entity in _cacheDir!.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
      return totalSize;
    } catch (e) {
      debugPrint('⚠️ UnifiedAvatarService: Failed to get cache size: $e');
      return 0;
    }
  }

  /// Check if avatar is cached
  bool isAvatarCached(String imageUrl) {
    return _memoryCache.containsKey(imageUrl);
  }

  /// Get cached avatar count
  int getCachedAvatarCount() {
    return _memoryCache.length;
  }

  /// Load main user avatar from persistent storage
  Future<void> _loadMainUserAvatarFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final avatarUrl = prefs.getString(_mainUserAvatarKey);
      
      if (avatarUrl != null && avatarUrl.isNotEmpty) {
        // Preload the main user avatar for instant display
        await _preloadSingleAvatar(avatarUrl);
        debugPrint('✅ UnifiedAvatarService: Loaded main user avatar from storage: $avatarUrl');
      }
    } catch (e) {
      debugPrint('⚠️ UnifiedAvatarService: Failed to load main user avatar from storage: $e');
    }
  }

  /// Save main user avatar to persistent storage
  Future<void> saveMainUserAvatar(String avatarUrl) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_mainUserAvatarKey, avatarUrl);
      
      // Preload the avatar for instant access
      await _preloadSingleAvatar(avatarUrl);
      
      debugPrint('✅ UnifiedAvatarService: Saved main user avatar to storage: $avatarUrl');
    } catch (e) {
      debugPrint('⚠️ UnifiedAvatarService: Failed to save main user avatar: $e');
    }
  }

  /// Get main user avatar with instant loading
  Widget getMainUserAvatar({
    required String imageUrl,
    double radius = 48,
    Widget? placeholder,
    Widget? errorWidget,
    bool showLoadingIndicator = true,
  }) {
    // Save the avatar URL for persistence
    if (imageUrl.isNotEmpty) {
      saveMainUserAvatar(imageUrl);
    }
    
    return getAvatar(
      imageUrl: imageUrl,
      radius: radius,
      placeholder: placeholder,
      errorWidget: errorWidget,
      showLoadingIndicator: showLoadingIndicator,
      useProfileViewStyling: true,
    );
  }

  /// Clear main user avatar from storage
  Future<void> clearMainUserAvatar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_mainUserAvatarKey);
      await prefs.remove(_mainUserAvatarDataKey);
      
      debugPrint('✅ UnifiedAvatarService: Cleared main user avatar from storage');
    } catch (e) {
      debugPrint('⚠️ UnifiedAvatarService: Failed to clear main user avatar: $e');
    }
  }
}

/// Navigation Service for accessing context
class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
}
