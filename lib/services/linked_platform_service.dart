import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/backend/firebase_https_function_url.dart';
import '../models/scheduled_post.dart';
import '../utils/platform_rules.dart';
import '../utils/user_profile_firestore.dart';
import 'package:streamers_tip/utils/secure_log.dart';

/// Reads cross-post destination health from Firestore (no mock HTTP).
class LinkedPlatformService {
  static final LinkedPlatformService _instance = LinkedPlatformService._internal();
  factory LinkedPlatformService() => _instance;
  LinkedPlatformService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const Set<String> oauthReconnectPlatforms = <String>{'youtube'};

  /// Whether this destination supports OAuth reconnect from the mobile app.
  static bool supportsOAuthReconnect(PlatformKey platform) {
    return oauthReconnectPlatforms.contains(platform.name);
  }

  /// Cross-post OAuth connection status keyed by [PlatformKey.name].
  Future<Map<String, bool>> getPlatformConnections() async {
    final String? uid = _auth.currentUser?.uid;
    if (uid == null) {
      return _emptyConnectionMap();
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> userDoc =
          await _firestore.collection('users').doc(uid).get();
      final Map<String, dynamic>? userData = userDoc.data();
      final List<Map<String, dynamic>> profilePlatforms =
          UserProfileFirestore.parsePlatformsFromUserData(userData);

      final Map<String, bool> connections = _emptyConnectionMap();

      for (final PlatformKey platform in PlatformKey.values) {
        final String key = platform.name;
        connections[key] = _isProfilePlatformConnected(
          profilePlatforms,
          key,
        );
      }

      return connections;
    } catch (e, stackTrace) {
      secureLog(
        'LinkedPlatformService: failed to load connections: $e\n$stackTrace',
        name: 'LinkedPlatformService',
      );
      rethrow;
    }
  }

  /// Starts OAuth reconnect in the system browser (YouTube only today).
  Future<void> reconnectPlatform(PlatformKey platform) async {
    final String platformKey = platform.name;
    if (!supportsOAuthReconnect(platform)) {
      throw LinkedPlatformReconnectUnavailableException(
        'Cross-post OAuth reconnect is not available for '
        '${_displayName(platformKey)} yet. Add a profile link under '
        'Edit Profile → Platforms.',
      );
    }

    final String? uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw Exception('Sign in to reconnect platforms.');
    }

    final String startUrl = buildFirebaseHttpsFunctionUrlFromProject(
      functionName: 'apiYoutubeAuthStart',
    );
    if (startUrl.isEmpty) {
      throw Exception('Platform reconnect is unavailable right now.');
    }

    final Uri authUri = Uri.parse(startUrl).replace(
      queryParameters: <String, String>{
        'uid': uid,
      },
    );

    final bool launched = await launchUrl(
      authUri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      throw Exception('Could not open the sign-in page.');
    }
  }

  static Map<String, bool> _emptyConnectionMap() {
    return <String, bool>{
      for (final PlatformKey platform in PlatformKey.values)
        platform.name: false,
    };
  }

  static bool isOAuthDocConnected(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) {
      return false;
    }
    final String refreshToken = data['refreshToken']?.toString().trim() ?? '';
    if (refreshToken.isNotEmpty) {
      return true;
    }
    final String accessToken = data['accessToken']?.toString().trim() ?? '';
    return accessToken.isNotEmpty && data['connectedAt'] != null;
  }

  static bool _isProfilePlatformConnected(
    List<Map<String, dynamic>> profilePlatforms,
    String platformKey,
  ) {
    for (final Map<String, dynamic> platform in profilePlatforms) {
      final String type = PlatformRules.normalizePlatformType(
        platform['type']?.toString() ?? '',
      );
      if (type != platformKey) {
        continue;
      }
      if (platform['isConnected'] == false) {
        return false;
      }
      final String username = platform['username']?.toString().trim() ?? '';
      final String url = platform['url']?.toString().trim() ?? '';
      if (username.isNotEmpty || url.isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  static String _displayName(String key) {
    return PlatformRules.displayNameForType(key);
  }
}

class LinkedPlatformReconnectUnavailableException implements Exception {
  LinkedPlatformReconnectUnavailableException(this.message);

  final String message;

  @override
  String toString() => message;
}
