import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart' as fa; // Not used here

class URLHandlerService extends ChangeNotifier {
  static final URLHandlerService _instance = URLHandlerService._internal();
  static URLHandlerService get shared => _instance;
  
  String? _pendingURL;
  bool _isProcessingURL = false;
  
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  // Getters
  String? get pendingURL => _pendingURL;
  bool get isProcessingURL => _isProcessingURL;
  
  URLHandlerService._internal();
  
  void handleURL(String url) {
    // print("🔗 URLHandlerService handling URL: $url");
    // cspell:ignore streamerstip
    if (!url.startsWith("streamerstip://")) {
    // print("❌ Not a streamerstip URL: $url");
      return;
    }
    
    _pendingURL = url;
    _processURL(url);
  }
  
  void _processURL(String url) {
    _isProcessingURL = true;
    notifyListeners();
    
    // Remove scheme and parse path
    final path = url.replaceFirst("streamerstip://", ""); // cspell:ignore streamerstip
    final pathComponents = path.split("/").where((component) => component.isNotEmpty).toList();
    
    // print("📋 Path components: $pathComponents");
    
    if (pathComponents.isEmpty) {
    // print("❌ Empty path components");
      _isProcessingURL = false;
      notifyListeners();
      return;
    }
    
    switch (pathComponents.first) {
      case "streamercard": // cspell:ignore streamercard
        if (pathComponents.length > 1) {
          final userId = pathComponents[1];
    // print("👤 Processing streamer card for user ID: $userId");
          _handleStreamerCard(userId);
        } else {
    // print("❌ Missing user ID in streamercard URL"); // cspell:ignore streamercard
          _isProcessingURL = false;
          notifyListeners();
        }
        
      case "profile":
        if (pathComponents.length > 1) {
          final username = pathComponents[1];
    // print("👤 Processing profile for username: $username");
          _handleProfile(username);
        } else {
    // print("❌ Missing username in profile URL");
          _isProcessingURL = false;
          notifyListeners();
        }
        
      default:
    // print("❌ Unknown URL path: $pathComponents");
        _isProcessingURL = false;
        notifyListeners();
    }
  }
  
  Future<void> _handleStreamerCard(String userId) async {
    try {
      final streamerCard = await _loadUserForStreamerCard(userId);
    // print("✅ URLHandlerService: Loaded streamer card for user: $userId");
      
      // Navigate to the streamer card view
      await _navigateToStreamerCard(streamerCard);
      
    } catch (e) {
    // print("❌ Error fetching user data: $e");
    }
    
    _isProcessingURL = false;
    notifyListeners();
  }
  
  Future<void> _handleProfile(String username) async {
    try {
      final streamerCard = await _loadUserByUsername(username);
    // print("✅ URLHandlerService: Loaded streamer card for username: $username");
      
      // Navigate to the streamer card view
      await _navigateToStreamerCard(streamerCard);
      
    } catch (e) {
    // print("❌ Error fetching user by username: $e");
    }
    
    _isProcessingURL = false;
    notifyListeners();
  }
  
  Future<StreamerCard> _loadUserForStreamerCard(String userId) async {
    try {
      final doc = await _db.collection("users").doc(userId).get();
      if (doc.exists) {
        final data = doc.data()!;
        return StreamerCard.fromMap(data);
      } else {
        throw Exception("User not found");
      }
    } catch (e) {
    // print("❌ Error loading user for streamer card: $e");
      rethrow;
    }
  }
  
  Future<StreamerCard> _loadUserByUsername(String username) async {
    try {
      final query = await _db
          .collection("users")
          .where("username", isEqualTo: username)
          .limit(1)
          .get();
      
      if (query.docs.isNotEmpty) {
        final data = query.docs.first.data();
        return StreamerCard.fromMap(data);
      } else {
        throw Exception("User not found");
      }
    } catch (e) {
    // print("❌ Error loading user by username: $e");
      rethrow;
    }
  }
  
  
  Future<void> _navigateToStreamerCard(StreamerCard streamerCard) async {
    // Post notification to navigate to streamer card
    // In Flutter, you would typically use a navigation service or callback
    // print("🔄 Navigate to streamer card: ${streamerCard.username}");
    
    // Clear the pending URL
    _pendingURL = null;
    notifyListeners();
  }
  
  // Additional methods for URL handling
  
  void clearPendingURL() {
    _pendingURL = null;
    notifyListeners();
  }
  
  bool isValidStreamerTipURL(String url) {
    return url.startsWith("streamerstip://"); // cspell:ignore streamerstip
  }
  
  // Method to handle deep links from app launch
  void handleInitialURL(String? url) {
    if (url != null && isValidStreamerTipURL(url)) {
    // print("🔗 Handling initial URL: $url");
      handleURL(url);
    }
  }
  
  // Method to handle URL changes while app is running
  void handleURLChange(String? url) {
    if (url != null && isValidStreamerTipURL(url)) {
    // print("🔗 Handling URL change: $url");
      handleURL(url);
    }
  }
}

// StreamerCard model for navigation
class StreamerCard {
  final String id;
  final String username;
  final String displayName;
  final String? bio;
  final String? avatarURL;
  final List<String> platforms;
  final bool isOnline;
  
  const StreamerCard({
    required this.id,
    required this.username,
    required this.displayName,
    this.bio,
    this.avatarURL,
    this.platforms = const [],
    this.isOnline = false,
  });
  
  factory StreamerCard.fromMap(Map<String, dynamic> map) {
    return StreamerCard(
      id: map['id'] ?? '',
      username: map['username'] ?? '',
      displayName: map['displayName'] ?? '',
      bio: map['bio'],
      avatarURL: map['avatarURL'],
      platforms: List<String>.from(map['platforms'] ?? []),
      isOnline: map['isOnline'] ?? false,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'displayName': displayName,
      'bio': bio,
      'avatarURL': avatarURL,
      'platforms': platforms,
      'isOnline': isOnline,
    };
  }
}
