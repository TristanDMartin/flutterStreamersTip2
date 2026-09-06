import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../../core/app_check_http_headers.dart';
import '../../core/backend/site_api_base.dart';
import 'tippy_brain_contract.dart';

/// Reads the canonical Tippy Brain (`users/{uid}/creatorMemory/main`).
/// Does not write Firestore. Does not create a Flutter-only store.
class TippyBrainClient {
  TippyBrainClient({
    http.Client? httpClient,
    String? siteApiBase,
  })  : _injectedClient = httpClient,
        _base = resolveSiteApiBase(explicitOverride: siteApiBase);

  final http.Client? _injectedClient;
  final String _base;

  Future<TippyBrainLayers?> fetchBrain() async {
    final User? user = FirebaseAuth.instance.currentUser;
    final String? token = await user?.getIdToken();
    if (token == null || token.isEmpty) {
      return null;
    }
    final Map<String, String> headers = await buildAuthenticatedHttpHeaders(
      idToken: token,
      extra: const <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );
    final http.Client client = _injectedClient ?? http.Client();
    try {
      final http.Response response = await client
          .get(
            Uri.parse(siteTippyCreatorMemoryUrl(base: _base)),
            headers: headers,
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final Object? decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        return null;
      }
      final Map<String, dynamic> data = decoded.cast<String, dynamic>();
      final Object? brain = data['brain'] ?? data['memory'];
      if (brain is! Map) {
        return null;
      }
      return TippyBrainLayers.fromJson(brain.cast<String, dynamic>());
    } catch (_) {
      return null;
    } finally {
      if (_injectedClient == null) {
        client.close();
      }
    }
  }

  Future<TippyBrainLayers?> confirmOrCorrect({
    required String op,
    required String section,
    required String field,
    Object? value,
  }) async {
    final User? user = FirebaseAuth.instance.currentUser;
    final String? token = await user?.getIdToken();
    if (token == null || token.isEmpty) {
      return null;
    }
    final Map<String, String> headers = await buildAuthenticatedHttpHeaders(
      idToken: token,
      extra: const <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );
    final http.Client client = _injectedClient ?? http.Client();
    try {
      final http.Response response = await client
          .post(
            Uri.parse(siteTippyCreatorMemoryUrl(base: _base)),
            headers: headers,
            body: jsonEncode(<String, dynamic>{
              'op': op,
              'section': section,
              'field': field,
              if (value != null) 'value': value,
            }),
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final Object? decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        return null;
      }
      final Object? brain = decoded['brain'] ?? decoded['memory'];
      if (brain is! Map) {
        return null;
      }
      return TippyBrainLayers.fromJson(brain.cast<String, dynamic>());
    } catch (_) {
      return null;
    } finally {
      if (_injectedClient == null) {
        client.close();
      }
    }
  }
}
