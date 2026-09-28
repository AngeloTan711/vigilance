import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import 'secure_storage_service.dart';

/// Thrown for any non-2xx API response. Screens catch this and show
/// [message] (or a field-specific entry from [errors]) rather than a raw
/// exception — per docs spec §27 (no stack traces to users).
class ApiException implements Exception {
  final int statusCode;
  final String message;
  final Map<String, dynamic>? errors;

  ApiException({required this.statusCode, required this.message, this.errors});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Thrown when there is no network path to the server at all (DNS/socket
/// failure, timeout) — distinct from ApiException so callers can trigger
/// offline-queue behavior instead of showing a generic error.
class ApiUnreachableException implements Exception {
  final String message;
  ApiUnreachableException([this.message = 'Unable to connect to the server.']);
}

class ApiClient {
  final SecureStorageService _storage;
  final http.Client _http;

  ApiClient({SecureStorageService? storage, http.Client? httpClient})
      : _storage = storage ?? SecureStorageService(),
        _http = httpClient ?? http.Client();

  Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  Future<Map<String, String>> _headers({bool authenticated = true}) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (authenticated) {
      final token = await _storage.readToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<dynamic> get(String path, {bool authenticated = true}) async {
    return _send(() async => _http
        .get(_uri(path), headers: await _headers(authenticated: authenticated))
        .timeout(ApiConfig.requestTimeout));
  }

  Future<dynamic> post(String path, Map<String, dynamic> body, {bool authenticated = true}) async {
    return _send(() async => _http
        .post(_uri(path), headers: await _headers(authenticated: authenticated), body: jsonEncode(body))
        .timeout(ApiConfig.requestTimeout));
  }

  Future<dynamic> put(String path, Map<String, dynamic> body, {bool authenticated = true}) async {
    return _send(() async => _http
        .put(_uri(path), headers: await _headers(authenticated: authenticated), body: jsonEncode(body))
        .timeout(ApiConfig.requestTimeout));
  }

  Future<dynamic> delete(String path, {bool authenticated = true}) async {
    return _send(() async => _http
        .delete(_uri(path), headers: await _headers(authenticated: authenticated))
        .timeout(ApiConfig.requestTimeout));
  }

  Future<dynamic> _send(Future<http.Response> Function() request) async {
    http.Response response;
    try {
      response = await request();
    } on Exception {
      // Covers SocketException, TimeoutException, HandshakeException, etc.
      // Deliberately not surfaced as raw exception text (spec §27).
      throw ApiUnreachableException();
    }

    final status = response.statusCode;
    final bodyText = response.body.isEmpty ? '{}' : response.body;
    late final dynamic decoded;
    try {
      decoded = jsonDecode(bodyText);
    } catch (_) {
      decoded = {'message': bodyText};
    }

    if (status >= 200 && status < 300) {
      return decoded;
    }

    final message = (decoded is Map && decoded['message'] != null)
        ? decoded['message'] as String
        : _defaultMessageFor(status);
    final errors = (decoded is Map && decoded['errors'] != null)
        ? Map<String, dynamic>.from(decoded['errors'] as Map)
        : null;

    throw ApiException(statusCode: status, message: message, errors: errors);
  }

  String _defaultMessageFor(int status) {
    switch (status) {
      case 401:
        return 'Your session has expired. Please log in again.';
      case 403:
        return 'You do not have permission to do that.';
      case 404:
        return 'The requested resource was not found.';
      case 409:
        return 'This alert has already changed status. Refreshing…';
      case 422:
        return 'Some information was invalid.';
      case 500:
      default:
        return 'Something went wrong on our end. Please try again.';
    }
  }
}
