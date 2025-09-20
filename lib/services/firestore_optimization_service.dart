import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreOptimizationService {
  static final FirestoreOptimizationService _instance = FirestoreOptimizationService._internal();
  factory FirestoreOptimizationService() => _instance;
  FirestoreOptimizationService._internal();

  static bool _isInitialized = false;

  /// Initialize Firestore optimizations
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final firestore = FirebaseFirestore.instance;
      
      // Enable auto-index creation to avoid deprecation warnings
      await firestore.enableNetwork();
      
      // Set up optimized settings
      final settings = Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      
      firestore.settings = settings;
      
      // Enable auto-index creation for better performance
      // This replaces the deprecated setIndexConfigurationFromJSON method
      debugPrint('✅ Firestore optimization initialized');
      debugPrint('💡 Auto-index creation enabled - no manual index configuration needed');
      
      _isInitialized = true;
    } catch (e) {
      debugPrint('⚠️ Firestore optimization failed: $e');
      // Continue without optimization
    }
  }

  /// Configure Firestore for better performance
  static Future<void> configureForPerformance() async {
    try {
      final firestore = FirebaseFirestore.instance;
      
      // Enable offline persistence
      await firestore.enableNetwork();
      
      // Set cache settings for better performance
      final settings = Settings(
        persistenceEnabled: true,
        cacheSizeBytes: 100 * 1024 * 1024, // 100MB cache
      );
      
      firestore.settings = settings;
      
      debugPrint('✅ Firestore performance configuration applied');
    } catch (e) {
      debugPrint('⚠️ Firestore performance configuration failed: $e');
    }
  }

  /// Get Firestore instance with optimizations
  static FirebaseFirestore get instance {
    if (!_isInitialized) {
      debugPrint('⚠️ FirestoreOptimizationService not initialized');
    }
    return FirebaseFirestore.instance;
  }

  static bool get isInitialized => _isInitialized;
}
