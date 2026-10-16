import 'dart:async';

import 'package:http/http.dart' as http;

/// HTTP client wrapper that supports request cancellation.
class CancelableHttpClient {
  CancelableHttpClient({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;
  final Map<String, Completer<void>> _cancelTokens = {};

  /// Execute a request with cancellation support.
  /// Returns the response or throws CanceledException if canceled.
  Future<http.Response> execute({
    required String requestId,
    required Future<http.Response> Function(http.Client) request,
  }) async {
    final Completer<void> cancelToken = Completer<void>();
    _cancelTokens[requestId] = cancelToken;

    try {
      final Future<http.Response> responseFuture = request(_client);
      final Future<http.Response> result = await Future.any([
        responseFuture,
        cancelToken.future.then((_) => throw CanceledException()),
      ]);
      return result;
    } finally {
      _cancelTokens.remove(requestId);
      if (!cancelToken.isCompleted) {
        cancelToken.complete();
      }
    }
  }

  /// Cancel a specific request by ID.
  void cancel(String requestId) {
    final Completer<void>? token = _cancelTokens[requestId];
    if (token != null && !token.isCompleted) {
      token.complete();
    }
  }

  /// Cancel all pending requests.
  void cancelAll() {
    for (final Completer<void> token in _cancelTokens.values) {
      if (!token.isCompleted) {
        token.complete();
      }
    }
    _cancelTokens.clear();
  }

  void dispose() {
    cancelAll();
    _client.close();
  }
}

class CanceledException implements Exception {
  const CanceledException();

  @override
  String toString() => 'Request was canceled';
}
