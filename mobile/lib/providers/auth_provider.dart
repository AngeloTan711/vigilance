import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../repositories/auth_repository.dart';
import '../services/api_client.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final AuthRepository _repo;
  AuthProvider({AuthRepository? repo}) : _repo = repo ?? AuthRepository();

  AuthStatus status = AuthStatus.unknown;
  User? user;
  String? error;
  bool isLoading = false;

  /// Called once from the Splash screen (§Screen 1): if a token is stored
  /// AND still valid (profile fetch succeeds), go straight to Home;
  /// otherwise Login.
  Future<void> restoreSession() async {
    try {
      final restored = await _repo.fetchProfileIfAuthenticated();
      if (restored != null) {
        user = restored;
        status = AuthStatus.authenticated;
      } else {
        status = AuthStatus.unauthenticated;
      }
    } on ApiException catch (e) {
      // Token existed but is no longer valid server-side (401) — treat as
      // logged out rather than surfacing an error on the splash screen.
      status = AuthStatus.unauthenticated;
      if (e.statusCode != 401) error = e.message;
    } catch (_) {
      status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      user = await _repo.login(email: email, password: password);
      status = AuthStatus.authenticated;
      return true;
    } on ApiException catch (e) {
      error = e.message;
      return false;
    } on ApiUnreachableException catch (e) {
      error = e.message;
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String name,
    required String schoolIdNumber,
    required String email,
    required String phone,
    required String password,
    required String passwordConfirmation,
    required int schoolId,
  }) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      user = await _repo.register(
        name: name,
        schoolIdNumber: schoolIdNumber,
        email: email,
        phone: phone,
        password: password,
        passwordConfirmation: passwordConfirmation,
        schoolId: schoolId,
      );
      status = AuthStatus.authenticated;
      return true;
    } on ApiException catch (e) {
      error = e.errors != null ? e.errors!.values.first[0] as String : e.message;
      return false;
    } on ApiUnreachableException catch (e) {
      error = e.message;
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    user = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
