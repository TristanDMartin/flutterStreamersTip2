import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

/// Service for syncing avatar data between the Flutter app and website
class WebsiteSyncService extends ChangeNotifier {
  static final WebsiteSyncService _instance = WebsiteSyncService._internal();
  factory WebsiteSyncService() => _instance;
  WebsiteSyncService._internal();

  // Website API configuration
  static const String _websiteAPIURL = "https://your-website.com/api/sync-avatar.js";
  
  // Firestore instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Storage instance
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  // Stream subscriptions for real-time updates
  StreamSubscription<DocumentSnapshot>? _userListener;
  
  // Current user being monitored
  String? _currentUserId;

  /// Sync avatar data to website
  Future<bool> syncAvatarToWebsite({
    required String userId,
    required String? avatarURL,
    required String displayName,
    required String username,
  }) async {
    try {
      if (avatarURL == null || avatarURL.isEmpty) {
        print("⚠️ No avatar URL to sync");
        return false;
      }

      print("🔄 Starting avatar sync to website for user: $userId");
      
      // Get avatar data as base64
      final avatarBase64 = await _getAvatarAsBase64(avatarURL);
      if (avatarBase64 == null) {
        print("❌ Failed to get avatar as base64");
        return false;
      }

      print("📸 Successfully fetched avatar data: ${avatarBase64.length} characters");
      
      // Prepare sync data
      final syncData = {
        'userId': userId,
        'avatarURL': avatarURL,
        'displayName': displayName,
        'username': username,
        'timestamp': DateTime.now().millisecondsSinceEpoch / 1000,
        'avatarBase64': avatarBase64,
      };

      print("📤 Sending avatar data to website:");
      print("   - User ID: $userId");
      print("   - Display Name: $displayName");
      print("   - Username: $username");
      print("   - Avatar URL: $avatarURL");
      print("   - Has Base64: ${avatarBase64.isNotEmpty}");

      // Send to website
      final response = await _sendToWebsite(syncData);
      
      if (response) {
        print("✅ Avatar successfully synced to website");
        
        // Save sync timestamp locally
        await _saveSyncTimestamp(userId);
        
        // Set up real-time listener for this user
        _setupUserListener(userId);
        
        return true;
      } else {
        print("❌ Failed to sync avatar to website");
        return false;
      }
    } catch (e) {
      print("❌ Error syncing avatar to website: $e");
      return false;
    }
  }

  /// Get avatar image as base64 string
  Future<String?> _getAvatarAsBase64(String avatarURL) async {
    try {
      final response = await http.get(Uri.parse(avatarURL));
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final base64String = base64Encode(bytes);
        return 'data:image/jpeg;base64,$base64String';
      }
    } catch (e) {
      print("❌ Error fetching avatar: $e");
    }
    return null;
  }

  /// Send avatar data to website
  Future<bool> _sendToWebsite(Map<String, dynamic> data) async {
    try {
      // Build query parameters
      final queryParams = <String, String>{};
      data.forEach((key, value) {
        if (value != null && value.toString().isNotEmpty) {
          queryParams[key] = value.toString();
        }
      });

      final uri = Uri.parse(_websiteAPIURL).replace(queryParameters: queryParams);
      
      print("🌐 Sending request to: $uri");
      
      final response = await http.get(uri).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Request timed out', const Duration(seconds: 30));
        },
      );

      print("📡 Website response status: ${response.statusCode}");
      print("📡 Website response body: ${response.body}");

      if (response.statusCode == 200) {
        try {
          final responseData = jsonDecode(response.body);
          print("📡 Website response data: $responseData");
          return true;
        } catch (e) {
          print("⚠️ Invalid JSON response from website: $e");
          return true; // Still consider it successful if status is 200
        }
      } else {
        print("❌ Website sync failed with status: ${response.statusCode}");
        return false;
      }
    } catch (e) {
      print("❌ Error sending to website: $e");
      return false;
    }
  }

  /// Save sync timestamp locally
  Future<void> _saveSyncTimestamp(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'avatar_sync_${userId}_timestamp';
      await prefs.setInt(key, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      print("⚠️ Error saving sync timestamp: $e");
    }
  }

  /// Get last sync timestamp
  Future<DateTime?> getLastSyncTimestamp(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'avatar_sync_${userId}_timestamp';
      final timestamp = prefs.getInt(key);
      if (timestamp != null) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
    } catch (e) {
      print("⚠️ Error getting sync timestamp: $e");
    }
    return null;
  }

  /// Set up real-time listener for user avatar changes
  void _setupUserListener(String userId) {
    // Clean up previous listener
    _userListener?.cancel();
    
    if (_currentUserId == userId) {
      return; // Already listening to this user
    }
    
    _currentUserId = userId;
    
    print("👂 Setting up real-time listener for user: $userId");
    
    _userListener = _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data()!;
        final newAvatarURL = data['avatarURL'] as String?;
        
        // Check if avatar URL changed
        _checkAvatarUpdate(userId, newAvatarURL);
      }
    });
  }

  /// Check if avatar was updated from website
  Future<void> _checkAvatarUpdate(String userId, String? newAvatarURL) async {
    try {
      // Get previous avatar URL from local storage
      final prefs = await SharedPreferences.getInstance();
      final key = 'previous_avatar_$userId';
      final previousAvatarURL = prefs.getString(key);
      
      if (previousAvatarURL != null && 
          newAvatarURL != null && 
          previousAvatarURL != newAvatarURL) {
        
        print("🔄 Avatar URL changed in Firestore - updating app");
        print("   Old: $previousAvatarURL");
        print("   New: $newAvatarURL");
        
        // Update local storage
        await prefs.setString(key, newAvatarURL);
        
        // Notify listeners about avatar update
        notifyListeners();
        
        print("✅ Avatar updated in app from website sync");
      } else if (previousAvatarURL == null && newAvatarURL != null) {
        // First time setting avatar
        await prefs.setString(key, newAvatarURL);
      }
    } catch (e) {
      print("❌ Error checking avatar update: $e");
    }
  }

  /// Test function for development
  Future<void> testSyncWithRealData() async {
    print("🧪 Testing avatar sync with real data...");
    
    // Replace these with your actual test data
    const testUserId = "test_user_123";
    const testAvatarURL = "https://example.com/test-avatar.jpg";
    const testDisplayName = "Test User";
    const testUsername = "testuser";
    
    final success = await syncAvatarToWebsite(
      userId: testUserId,
      avatarURL: testAvatarURL,
      displayName: testDisplayName,
      username: testUsername,
    );
    
    if (success) {
      print("✅ Test sync successful");
    } else {
      print("❌ Test sync failed");
    }
  }

  /// Test two-way sync functionality
  Future<void> testTwoWaySync() async {
    print("🧪 Testing two-way sync functionality...");
    
    // Test website → app sync
    print("📱 Testing website → app sync...");
    await _simulateWebsiteUpdate();
    
    // Test app → website sync
    print("🌐 Testing app → website sync...");
    await testSyncWithRealData();
  }

  /// Simulate website updating avatar (for testing)
  Future<void> _simulateWebsiteUpdate() async {
    try {
      const testUserId = "test_user_123";
      const newAvatarURL = "https://example.com/new-avatar.jpg";
      
      // Update Firestore (this will trigger the listener)
      await _firestore
          .collection('users')
          .doc(testUserId)
          .update({'avatarURL': newAvatarURL});
      
      print("🔄 Simulated website update - new avatar URL: $newAvatarURL");
    } catch (e) {
      print("❌ Error simulating website update: $e");
    }
  }

  /// Clean up resources
  @override
  void dispose() {
    _userListener?.cancel();
    super.dispose();
  }

  /// Get sync status for a user
  Future<Map<String, dynamic>> getSyncStatus(String userId) async {
    try {
      final lastSync = await getLastSyncTimestamp(userId);
      final isListening = _currentUserId == userId;
      
      return {
        'userId': userId,
        'lastSync': lastSync?.toIso8601String(),
        'isListening': isListening,
        'status': lastSync != null ? 'synced' : 'not_synced',
      };
    } catch (e) {
      return {
        'userId': userId,
        'error': e.toString(),
        'status': 'error',
      };
    }
  }

  /// Force sync for a user
  Future<bool> forceSync(String userId, User user) async {
    return await syncAvatarToWebsite(
      userId: userId,
      avatarURL: user.avatarURL,
      displayName: user.displayName,
      username: user.username,
    );
  }

  /// Batch sync multiple users
  Future<Map<String, bool>> batchSyncUsers(List<User> users) async {
    final results = <String, bool>{};
    
    for (final user in users) {
      final success = await syncAvatarToWebsite(
        userId: user.id,
        avatarURL: user.avatarURL,
        displayName: user.displayName,
        username: user.username,
      );
      results[user.id] = success;
    }
    
    return results;
  }
}

/// Custom exception for timeout
class TimeoutException implements Exception {
  final String message;
  final Duration duration;
  
  TimeoutException(this.message, this.duration);
  
  @override
  String toString() => 'TimeoutException: $message after ${duration.inSeconds} seconds';
}
