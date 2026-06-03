import 'package:flutter/foundation.dart';
import '../core/network/token_store.dart';
import '../models/auth_models.dart';
import '../models/profile_models.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._authService, this._tokenStore);

  final AuthService _authService;
  final TokenStore _tokenStore;
  AuthSession? session;
  bool isLoading = false;
  String? lastResetToken;
  bool isBootstrapping = false;

  bool get isAuthenticated => session != null;

  Future<void> login(String email, String password) async {
    await _runAuth(() => _authService.login(email, password));
  }

  Future<void> register(String fullName, String email, String phoneNumber, String password) async {
    await _runAuth(() => _authService.register(fullName, email, phoneNumber, password));
  }

  Future<DateTime?> sendRegisterOtp({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
    required String confirmPassword,
  }) async {
    isLoading = true;
    notifyListeners();
    try {
      return await _authService.sendRegisterOtp(
        fullName: fullName,
        email: email,
        phoneNumber: phoneNumber,
        password: password,
        confirmPassword: confirmPassword,
      );
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> verifyRegisterOtp(String email, String otp) async {
    await _runAuth(() => _authService.verifyRegisterOtp(email, otp));
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

  Future<bool> hasSeenOnboarding() => _tokenStore.hasSeenOnboarding;

  Future<void> markOnboardingSeen() => _tokenStore.setHasSeenOnboarding(true);

  Future<bool> restoreSessionFromStorage() async {
    isBootstrapping = true;
    notifyListeners();
    try {
      final accessToken = await _tokenStore.accessToken;
      final refreshToken = await _tokenStore.refreshToken;
      if (accessToken == null || refreshToken == null) {
        return false;
      }
      session ??= AuthSession(
        userId: '',
        fullName: '',
        email: '',
        accessToken: accessToken,
        refreshToken: refreshToken,
      );
      return true;
    } finally {
      isBootstrapping = false;
      notifyListeners();
    }
  }

  void syncFromProfile(UserProfile profile) {
    final current = session;
    if (current == null) return;
    session = AuthSession(
      userId: profile.id,
      fullName: profile.fullName,
      email: profile.email,
      accessToken: current.accessToken,
      refreshToken: current.refreshToken,
    );
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
