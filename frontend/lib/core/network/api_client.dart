import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class ApiClient {
  ApiClient({http.Client? client})
    : _client = client ?? http.Client(),
      _baseUri = _normalizeBase(ApiConfig.baseUrl);

  final http.Client _client;
  final Uri _baseUri;
  String? _bearerToken;

  Uri get baseUri => _baseUri;

  static const Map<String, String> _jsonHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  static Uri _normalizeBase(String base) {
    final normalized = base.endsWith('/') ? base : '$base/';
    return Uri.parse(normalized);
  }

  Future<Map<String, dynamic>> getJson(String path) async {
    final uri = _resolve(path);
    final response = await _client.get(uri, headers: _buildHeaders());
    return _parseJsonResponse('GET', uri, response);
  }

  Future<List<dynamic>> getList(String path) async {
    final data = await getJson(path);
    if (data case {'items': final List<dynamic> items}) {
      return items;
    }
    if (data case {'data': final List<dynamic> items}) {
      return items;
    }
    return data.values.whereType<List<dynamic>>().firstOrNull ?? [];
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = _resolve(path);
    final response = await _client.post(
      uri,
      headers: _buildHeaders(),
      body: jsonEncode(body),
    );
    return _parseJsonResponse('POST', uri, response);
  }

  Future<Map<String, dynamic>> putJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = _resolve(path);
    final response = await _client.put(
      uri,
      headers: _buildHeaders(),
      body: jsonEncode(body),
    );
    return _parseJsonResponse('PUT', uri, response);
  }

  Future<Map<String, dynamic>> patchJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = _resolve(path);
    final response = await _client.patch(
      uri,
      headers: _buildHeaders(),
      body: jsonEncode(body),
    );
    return _parseJsonResponse('PATCH', uri, response);
  }

  Future<void> delete(String path) async {
    final uri = _resolve(path);
    final response = await _client.delete(uri, headers: _buildHeaders());
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'DELETE $uri failed with ${response.statusCode}',
        response.body,
      );
    }
  }

  void setBearerToken(String token) {
    _bearerToken = token;
  }

  void clearBearerToken() {
    _bearerToken = null;
  }

  void close() {
    _client.close();
  }

  Map<String, String> buildHeaders([Map<String, String>? overrides]) =>
      _buildHeaders(overrides);

  Uri _resolve(String path) {
    final normalized = path.startsWith('/') ? path.substring(1) : path;
    return _baseUri.resolve(normalized);
  }

  Map<String, String> _buildHeaders([Map<String, String>? overrides]) {
    final headers = <String, String>{..._jsonHeaders};
    if (_bearerToken != null && _bearerToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_bearerToken';
    }
    if (overrides != null && overrides.isNotEmpty) {
      headers.addAll(overrides);
    }
    return headers;
  }

  Map<String, dynamic> _parseJsonResponse(
    String method,
    Uri uri,
    http.Response response,
  ) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) {
        return const {};
      }
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return {'data': decoded};
    }

    throw ApiException(
      '$method $uri failed with ${response.statusCode}',
      response.body,
    );
  }
}

class ApiException implements Exception {
  ApiException(this.message, [this.body]);

  final String message;
  final String? body;

  @override
  String toString() => 'ApiException(message: $message, body: $body)';
}
