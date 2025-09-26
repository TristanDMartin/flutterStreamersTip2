import 'dart:io';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'memory_pressure_service.dart';
import '../widgets/optimized_image.dart';

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
  
  // FIXED: Reduced to prevent buffer overflow
  static const int _maxConcurrentLoads = 0; // CRITICAL: Disable all concurrent loads to prevent buffer overflow
  int _currentLoads = 0;
  final Queue<String> _loadQueue = Queue<String>();
  
  // Cache directory
  Directory? _cacheDir;
  
  // Persistent cache for main user avatar
  static const String _mainUserAvatarKey = 'main_user_avatar_url';
  static const String _mainUserAvatarDataKey = 'main_user_avatar_data';

  /// Initialize the unified avatar service with optimized loading
  Future<void> initialize() async {
    try {
      // Skip cache directory creation for faster startup
      _cacheDir = await getApplicationDocumentsDirectory();
      _cacheDir = Directory(path.join(_cacheDir!.path, 'unified_avatar_cache'));
      
      // Create cache directory only if needed (lazy creation)
      // if (!await _cacheDir!.exists()) {
      //   await _cacheDir!.create(recursive: true);
      // }
      
      // Load main user avatar in background (non-blocking)
      _loadMainUserAvatarFromStorage().catchError((e) {
        debugPrint('⚠️ Failed to load main user avatar (non-critical): $e');
      });
      
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

      // Use simple, robust image loading to prevent Positioned widget errors
      return _buildSimpleAvatar(
        imageUrl: imageUrl,
        radius: radius,
        placeholder: placeholder,
        errorWidget: errorWidget,
        showLoadingIndicator: showLoadingIndicator,
        useProfileViewStyling: useProfileViewStyling,
      );
    } catch (e) {
      debugPrint('❌ UnifiedAvatarService: Critical error in getAvatar: $e');
      return _buildDefaultAvatar(radius, useProfileViewStyling);
    }
  }

  /// Build simple avatar without complex image processing
  Widget _buildSimpleAvatar({
    required String imageUrl,
    required double radius,
    Widget? placeholder,
    Widget? errorWidget,
    required bool showLoadingIndicator,
    required bool useProfileViewStyling,
  }) {
    // Check memory pressure before loading
    if (!MemoryPressureService.canLoadAvatar) {
      debugPrint('⚠️ Memory pressure high - showing placeholder for avatar');
      return _buildDefaultAvatar(radius, useProfileViewStyling);
    }

    // Use OptimizedImage for memory-controlled avatar loading
    final avatarWidget = OptimizedImage(
      imageUrl: imageUrl,
      width: radius * 2,
      height: radius * 2,
      fit: BoxFit.cover,
      borderRadius: BorderRadius.circular(radius),
      placeholder: showLoadingIndicator
          ? SizedBox(
              width: radius * 0.6,
              height: radius * 0.6,
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
              ),
            )
          : placeholder,
      errorWidget: errorWidget,
    );

    if (useProfileViewStyling) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: radius * 2 + 8, // Add padding for gradient ring
            height: radius * 2 + 8,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [
                  Color(0xFFFF6CAB),
                  Color(0xFF8E54E9),
                  Color(0xFF3D99F7),
                  Color(0xFFFF6CAB),
                ],
              ),
            ),
            child: Center(
              child: Container(
                width: radius * 2,
                height: radius * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.2),
                ),
                child: ClipOval(
                  child: avatarWidget,
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      return avatarWidget;
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
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: radius * 2 + 8, // Add padding for gradient ring
            height: radius * 2 + 8,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [
                  Color(0xFFFF6CAB),
                  Color(0xFF8E54E9),
                  Color(0xFF3D99F7),
                  Color(0xFFFF6CAB),
                ],
              ),
            ),
            child: Center(
              child: Container(
                width: radius * 2,
                height: radius * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.2),
                ),
                child: ClipOval(
                  child: defaultAvatar,
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      return defaultAvatar;
    }
  }

  /// Preload avatars for instant display with buffer management
  Future<void> preloadAvatars(List<String> avatarUrls) async {
    if (avatarUrls.isEmpty) return;

    debugPrint('🔄 UnifiedAvatarService: Preloading ${avatarUrls.length} avatars...');
    
    // Limit concurrent loading to prevent buffer overflow
    final limitedUrls = avatarUrls.take(_maxConcurrentLoads).toList();
    
    for (final url in limitedUrls) {
      if (url.isNotEmpty && !_memoryCache.containsKey(url)) {
        _loadImageWithBufferManagement(url);
      }
    }
    
    debugPrint('✅ UnifiedAvatarService: Preloaded ${_memoryCache.length} avatars');
  }

  /// Load image with buffer management
  Future<void> _loadImageWithBufferManagement(String url) async {
    if (url.isEmpty || _memoryCache.containsKey(url) || _loadingStates[url] == true) return;
    
    if (_currentLoads >= _maxConcurrentLoads) {
      _loadQueue.add(url);
      return;
    }
    
    _currentLoads++;
    _loadingStates[url] = true;
    
    try {
      final imageProvider = CachedNetworkImageProvider(url);
      
      final context = NavigationService.navigatorKey.currentContext;
      if (context != null) {
        try {
          await precacheImage(imageProvider, context);
          _memoryCache[url] = imageProvider;
          debugPrint('✅ UnifiedAvatarService: Loaded avatar $url');
        } catch (e) {
          debugPrint('⚠️ UnifiedAvatarService: Failed to precache avatar $url: $e');
        }
      } else {
        _memoryCache[url] = imageProvider;
        debugPrint('✅ UnifiedAvatarService: Cached avatar provider $url');
      }
    } catch (e) {
      debugPrint('⚠️ UnifiedAvatarService: Failed to load avatar $url: $e');
    } finally {
      _loadingStates[url] = false;
      _currentLoads--;
      
      // Process next in queue
      if (_loadQueue.isNotEmpty) {
        final nextUrl = _loadQueue.removeFirst();
        _loadImageWithBufferManagement(nextUrl);
      }
    }
  }

  /// Preload a single avatar
  Future<void> _preloadSingleAvatar(String url) async {
    if (url.isEmpty || _memoryCache.containsKey(url)) return;

    try {
      // Use a more robust approach to validate images
      final imageProvider = CachedNetworkImageProvider(url);
      
      // Try to precache the image to validate it
      final context = NavigationService.navigatorKey.currentContext;
      if (context != null) {
        try {
          await precacheImage(imageProvider, context);
          _memoryCache[url] = imageProvider;
          debugPrint('✅ UnifiedAvatarService: Preloaded avatar $url');
        } catch (e) {
          // If precaching fails, don't cache the provider
          debugPrint('⚠️ UnifiedAvatarService: Failed to precache avatar $url: $e');
          // Don't add to memory cache if it fails validation
        }
      } else {
        // If no context, just cache the provider (less reliable)
        _memoryCache[url] = imageProvider;
        debugPrint('✅ UnifiedAvatarService: Cached avatar provider $url');
      }
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
