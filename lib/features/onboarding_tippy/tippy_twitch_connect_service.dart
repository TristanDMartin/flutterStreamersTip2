import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_check_http_headers.dart';
import '../../core/backend/site_api_base.dart';

/// Starts Twitch OAuth for Tippy onboarding and checks connection state.
class TippyTwitchConnectService {
  TippyTwitchConnectService({
    http.Client? httpClient,
    FirebaseFirestore? firestore,
    String? siteApiBase,
  })  : _client = httpClient ?? http.Client(),
        _firestore = firestore ?? FirebaseFirestore.instance,
        _base = resolveSiteApiBase(explicitOverride: siteApiBase);

  final http.Client _client;
  final FirebaseFirestore _firestore;
  final String _base;

  Future<void> startOAuth() async {
    final User? user = FirebaseAuth.instance.currentUser;
    final String? token = await user?.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError('Sign in required to connect Twitch.');
    }
    final Map<String, String> headers =
        await buildAuthenticatedHttpHeaders(idToken: token);
    final http.Response response = await _client
        .get(
          Uri.parse(
            siteApiPath(
              '/api/twitch/auth/start?returnTo=tippy_onboarding',
              base: _base,
            ),
          ),
          headers: headers,
        )
        .timeout(const Duration(seconds: 25));
    final Object? decoded = jsonDecode(response.body);
    final Map<String, dynamic> body = decoded is Map
        ? decoded.cast<String, dynamic>()
        : <String, dynamic>{};
    final String authUrl = (body['authUrl'] as String?)?.trim() ?? '';
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        authUrl.isEmpty) {
      throw StateError(
        (body['message'] as String?) ??
            (body['error'] as String?) ??
            'Could not start Twitch connect.',
      );
    }
    final Uri uri = Uri.parse(authUrl);
    final bool launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      throw StateError('Could not open Twitch authorization.');
    }
  }

  Future<bool> hasTwitchConnection(String uid) async {
    final DocumentSnapshot<Map<String, dynamic>> snap =
        await _firestore.collection('twitchConnections').doc(uid).get();
    return snap.exists;
  }

  Future<void> persistConnectionStatus({
    required String uid,
    required String status,
  }) async {
    await _firestore.collection('users').doc(uid).set(
      <String, dynamic>{
        'onboarding': <String, dynamic>{
          'twitchConnectionStatus': status,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
