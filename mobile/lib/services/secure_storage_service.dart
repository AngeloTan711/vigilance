import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/constants.dart';

/// Wraps flutter_secure_storage (Android Keystore / iOS Keychain backed) so
/// the auth token is never kept in plain SharedPreferences. Per docs spec
/// §18 — "Secure token storage", "No API secrets inside Flutter code".
class SecureStorageService {
  final FlutterSecureStorage _storage;

  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  Future<void> saveToken(String token) => _storage.write(key: kSecureStorageTokenKey, value: token);

  Future<String?> readToken() => _storage.read(key: kSecureStorageTokenKey);

  Future<void> clearToken() => _storage.delete(key: kSecureStorageTokenKey);
}
