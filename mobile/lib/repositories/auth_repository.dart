import '../models/user.dart';
import '../services/api_client.dart';
import '../services/secure_storage_service.dart';

/// Wraps the auth-related endpoints (docs/ARCHITECTURE.md §4:
/// POST /login, /register, /logout, GET/PUT /profile). Providers depend on
/// this, never on ApiClient directly, so screens never build request bodies
/// or parse responses themselves.
class AuthRepository {
  final ApiClient _api;
  final SecureStorageService _storage;

  AuthRepository({ApiClient? api, SecureStorageService? storage})
      : _api = api ?? ApiClient(),
        _storage = storage ?? SecureStorageService();

  Future<User> login({required String email, required String password}) async {
    final response = await _api.post('/login', {'email': email, 'password': password}, authenticated: false);
    await _storage.saveToken(response['token'] as String);
    return User.fromJson(response['user'] as Map<String, dynamic>);
  }

  /// Registration is student/staff self-service only — the backend rejects
  /// role=responder/admin here regardless of what's sent (§5). This app
  /// never offers those roles as an option in the UI either.
  Future<User> register({
    required String name,
    required String schoolIdNumber,
    required String email,
    required String phone,
    required String password,
    required String passwordConfirmation,
    required int schoolId,
  }) async {
    final response = await _api.post('/register', {
      'name': name,
      'school_id_number': schoolIdNumber,
      'email': email,
      'phone': phone,
      'password': password,
      'password_confirmation': passwordConfirmation,
      'school_id': schoolId,
      'role': 'student', // staff accounts are provisioned/promoted by an admin, not self-selected
    }, authenticated: false);
    await _storage.saveToken(response['token'] as String);
    return User.fromJson(response['user'] as Map<String, dynamic>);
  }

  Future<void> logout() async {
    try {
      await _api.post('/logout', {});
    } finally {
      // Clear the local token even if the network call fails/times out —
      // the user must always be able to log out on-device.
      await _storage.clearToken();
    }
  }

  Future<User?> fetchProfileIfAuthenticated() async {
    final token = await _storage.readToken();
    if (token == null) return null;
    final response = await _api.get('/profile');
    return User.fromJson(response as Map<String, dynamic>);
  }

  Future<User> updateProfile({String? name, String? phone, String? email}) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (phone != null) body['phone'] = phone;
    if (email != null) body['email'] = email;
    final response = await _api.put('/profile', body);
    return User.fromJson(response as Map<String, dynamic>);
  }

  Future<bool> hasStoredSession() async => (await _storage.readToken()) != null;
}
