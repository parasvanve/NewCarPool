import 'package:flutter/foundation.dart';
import '../core/network/token_store.dart';
import '../models/auth_models.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._authService, this._tokenStore);

  final AuthService _authService;
  final TokenStore _tokenStore;
  AuthSession? session;
  bool isLoading = false;
  String? lastResetToken;

  bool get isAuthenticated => session != null;

  Future<void> login(String email, String password) async {
    await _runAuth(() => _authService.login(email, password));
  }

  Future<void> register(String fullName, String email, String phoneNumber, String password) async {
    await _runAuth(() => _authService.register(fullName, email, phoneNumber, password));
  }

  Future<void> forgotPassword(String email) async {
    isLoading = true;
    notifyListeners();
    try {
      lastResetToken = await _authService.forgotPassword(email);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> resetPassword(String email, String resetToken, String newPassword) async {
    isLoading = true;
    notifyListeners();
    try {
      await _authService.resetPassword(email, resetToken, newPassword);
      lastResetToken = null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    session = null;
    await _tokenStore.clear();
    notifyListeners();
  }

  Future<void> _runAuth(Future<AuthSession> Function() action) async {
    isLoading = true;
    notifyListeners();
    try {
      session = await action();
      await _tokenStore.saveTokens(
        accessToken: session!.accessToken,
        refreshToken: session!.refreshToken,
      );
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
