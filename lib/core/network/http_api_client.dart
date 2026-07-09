import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_client.dart';
import 'api_exception.dart';

typedef TokenProvider = Future<String?> Function();

class HttpApiClient implements ApiClient {
  const HttpApiClient({
    required http.Client httpClient,
    required String baseUrl,
    TokenProvider? tokenProvider,
  }) : _httpClient = httpClient,
       _baseUrl = baseUrl,
       _tokenProvider = tokenProvider;

  final http.Client _httpClient;
  final String _baseUrl;
  final TokenProvider? _tokenProvider;

  @override
  Future<Object?> get(String path, {bool authenticated = false}) {
    return _send('GET', path, authenticated: authenticated);
  }

  @override
  Future<Object?> post(
    String path, {
    Object? body,
    bool authenticated = false,
  }) {
    return _send('POST', path, body: body, authenticated: authenticated);
  }

  @override
  Future<Object?> put(String path, {Object? body, bool authenticated = false}) {
    return _send('PUT', path, body: body, authenticated: authenticated);
  }

  @override
  Future<Object?> delete(String path, {bool authenticated = false}) {
    return _send('DELETE', path, authenticated: authenticated);
  }

  Future<Object?> _send(
    String method,
    String path, {
    Object? body,
    required bool authenticated,
  }) async {
    final uri = Uri.parse('$_normalizedBaseUrl/${_cleanPath(path)}');
    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
    };
    if (authenticated) {
      final token = await _tokenProvider?.call();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    try {
      final response = switch (method) {
        'GET' => await _httpClient.get(uri, headers: headers),
        'POST' => await _httpClient.post(
          uri,
          headers: headers,
          body: body == null ? null : jsonEncode(body),
        ),
        'PUT' => await _httpClient.put(
          uri,
          headers: headers,
          body: body == null ? null : jsonEncode(body),
        ),
        'DELETE' => await _httpClient.delete(uri, headers: headers),
        _ => throw ArgumentError.value(method, 'method'),
      };
      return _decodeResponse(response);
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException(message: 'Network request failed: $error');
    }
  }

  Object? _decodeResponse(http.Response response) {
    final body = response.body.trim();
    final decoded = body.isEmpty ? null : jsonDecode(body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        message: _messageFrom(decoded) ?? 'Request failed',
        statusCode: response.statusCode,
        responseBody: decoded,
      );
    }
    return decoded;
  }

  String? _messageFrom(Object? decoded) {
    if (decoded is Map<String, Object?>) {
      final message = decoded['message'];
      if (message is String) {
        return message;
      }
      if (message is List && message.isNotEmpty) {
        return message.join(', ');
      }
    }
    return null;
  }

  String get _normalizedBaseUrl {
    return _baseUrl.endsWith('/')
        ? _baseUrl.substring(0, _baseUrl.length - 1)
        : _baseUrl;
  }

  String _cleanPath(String path) {
    return path.startsWith('/') ? path.substring(1) : path;
  }
}
