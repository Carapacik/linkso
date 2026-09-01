import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:linkso_client/src/core/api/api_failure.dart';
import 'package:linkso_client/src/core/auth/session_token_store.dart';

final class LinkSoApiClient({
  required final Uri baseUri,
  http.Client? client,
  SessionTokenStore? sessionTokenStore,
  final bool usesBearerSession = false,
  final Duration requestTimeout = const Duration(seconds: 20),
}) {
  final http.Client _client = client ?? http.Client();
  final SessionTokenStore _sessionTokenStore = sessionTokenStore ?? createSessionTokenStore();

  Future<void> storeSessionToken(String token) => usesBearerSession ? _sessionTokenStore.write(token) : Future.value();

  Future<void> clearSessionToken() => usesBearerSession ? _sessionTokenStore.clear() : Future.value();

  Future<Map<String, Object?>> getJson({required String path}) => _requestJson(method: 'GET', path: path);

  Future<List<Object?>> getJsonList({required String path}) async {
    final http.Response response = await _request(method: 'GET', path: path);
    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw invalidResponseApiFailure;
    }
    if (decoded case final List<Object?> value) {
      return value;
    }
    throw invalidResponseApiFailure;
  }

  Future<Map<String, Object?>> postJson({required String path, required Map<String, Object?> body}) =>
      _requestJson(method: 'POST', path: path, body: body);

  Future<Map<String, Object?>> putJson({required String path, required Map<String, Object?> body}) =>
      _requestJson(method: 'PUT', path: path, body: body);

  Future<void> putEmpty({required String path, required Map<String, Object?> body}) async {
    await _request(method: 'PUT', path: path, body: body);
  }

  Future<void> postEmpty({required String path, Map<String, Object?>? body}) async {
    await _request(method: 'POST', path: path, body: body);
  }

  Future<void> deleteEmpty({required String path, Map<String, Object?>? body}) async {
    await _request(method: 'DELETE', path: path, body: body);
  }

  Future<Map<String, Object?>> _requestJson({
    required String method,
    required String path,
    Map<String, Object?>? body,
  }) async {
    final http.Response response = await _request(method: method, path: path, body: body);
    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw invalidResponseApiFailure;
    }
    if (decoded case final Map<String, Object?> value) {
      return value;
    }
    throw invalidResponseApiFailure;
  }

  Future<http.Response> _request({required String method, required String path, Map<String, Object?>? body}) async {
    final abort = Completer<void>();
    final ({http.Response response, String? authorization}) result;
    try {
      result = await _sendRequest(method: method, path: path, body: body, abort: abort).timeout(
        requestTimeout,
        onTimeout: () {
          abort.complete();
          _log('$method $path: timed out after ${requestTimeout.inMilliseconds}ms');
          throw requestTimeoutApiFailure;
        },
      );
    } on http.ClientException {
      _log('$method $path: network error');
      throw networkApiFailure;
    }

    final http.Response response = result.response;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final ApiFailure failure = parseApiFailureResponse(statusCode: response.statusCode, responseBody: response.body);
      if (usesBearerSession && response.statusCode == 401 && failure.code == 'authentication_required') {
        final String? authorization = result.authorization;
        if (authorization != null && authorization == 'Bearer ${await _sessionTokenStore.read()}') {
          await _sessionTokenStore.clear();
        }
      }
      throw failure;
    }

    return response;
  }

  Future<({http.Response response, String? authorization})> _sendRequest({
    required String method,
    required String path,
    required Map<String, Object?>? body,
    required Completer<void> abort,
  }) async {
    final request = http.AbortableRequest(method, _resolve(path), abortTrigger: abort.future);
    _log('$method ${request.url}: preparing request');
    if (usesBearerSession) {
      _log('reading native session token');
      final String? token = await _sessionTokenStore.read();
      _log('native session token read completed (present: ${token != null})');
      // A late storage read must not send a mutation after the UI has timed out.
      if (abort.isCompleted) {
        throw requestTimeoutApiFailure;
      }
      if (token != null) {
        request.headers['authorization'] = 'Bearer $token';
      }
    }
    if (body != null) {
      request.headers['content-type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    _log('sending request');
    final http.Response response = await http.Response.fromStream(await _client.send(request));
    if (abort.isCompleted) {
      _log('late response discarded after timeout');
      throw requestTimeoutApiFailure;
    }
    _log('response received (${response.statusCode})');
    return (response: response, authorization: request.headers['authorization']);
  }

  static void _log(String message) {
    if (kDebugMode) {
      debugPrint('[LinkSoApiClient] $message');
    }
  }

  void close() => _client.close();

  Uri _resolve(String path) {
    final String relativePath = path.startsWith('/') ? path.substring(1) : path;
    return baseUri.resolve(relativePath);
  }
}
