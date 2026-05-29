import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStore {
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _hasSeenOnboardingKey = 'has_seen_onboarding';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<String?> get accessToken => _storage.read(key: _accessTokenKey);
  Future<String?> get refreshToken => _storage.read(key: _refreshTokenKey);

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }

  Future<bool> get hasSeenOnboarding async =>
      (await _storage.read(key: _hasSeenOnboardingKey)) == 'true';

  Future<void> setHasSeenOnboarding(bool value) async {
    await _storage.write(
      key: _hasSeenOnboardingKey,
      value: value ? 'true' : 'false',
    );
  }
}
