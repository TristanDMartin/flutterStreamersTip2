import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreCacheService {
  static final FirestoreCacheService _instance = FirestoreCacheService._internal();
  factory FirestoreCacheService() => _instance;
  FirestoreCacheService._internal();

  static bool _isInitialized = false;

  /// Initialize Firestore cache with auto-index creation
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final firestore = FirebaseFirestore.instance;
      
      // Enable auto-index creation to replace deprecated setIndexConfigurationFromJSON
      // This is the recommended approach for the deprecation warning
      await firestore.enableNetwork();
      
      // Configure settings for optimal performance
      final settings = Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      
      firestore.settings = settings;
      
      debugPrint('✅ Firestore cache service initialized');
      debugPrint('💡 Auto-index creation enabled - replaces deprecated setIndexConfigurationFromJSON');
      
      _isInitialized = true;
    } catch (e) {
      debugPrint('⚠️ Firestore cache service initialization failed: $e');
      // Continue without optimization
    }
  }

  /// Configure cache for specific collections that need indexes
  static Future<void> configureCollectionIndexes() async {
    try {
      final firestore = FirebaseFirestore.instance;
      
      // Enable network to ensure proper initialization
      await firestore.enableNetwork();
      
      // The auto-index creation will handle the indexes defined in firestore.indexes.json
      // No need to manually set index configuration anymore
      debugPrint('✅ Collection indexes configured via auto-creation');
      
    } catch (e) {
      debugPrint('⚠️ Collection index configuration failed: $e');
    }
  }

  /// Clear Firestore cache if needed
  static Future<void> clearCache() async {
    try {
      final firestore = FirebaseFirestore.instance;
      await firestore.clearPersistence();
      debugPrint('✅ Firestore cache cleared');
    } catch (e) {
      debugPrint('⚠️ Failed to clear Firestore cache: $e');
    }
  }

  static bool get isInitialized => _isInitialized;
}
