import '../core/network/api_client.dart';
import '../models/auth_models.dart';

class AuthService {
  AuthService(this._apiClient);

  final ApiClient _apiClient;

  Future<AuthSession> login(String email, String password) async {
    final response = await _apiClient.dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    return AuthSession.fromJson(response.data);
  }

  Future<AuthSession> register(String fullName, String email, String phoneNumber, String password) async {
    final response = await _apiClient.dio.post('/auth/register', data: {
      'fullName': fullName,
      'email': email,
      'phoneNumber': phoneNumber,
      'password': password,
    });
    return AuthSession.fromJson(response.data);
  }

  Future<String> forgotPassword(String email) async {
    final response = await _apiClient.dio.post('/auth/forgot-password', data: {
      'email': email,
    });
    return response.data['resetToken']?.toString() ?? '';
  }

  Future<void> resetPassword(String email, String resetToken, String newPassword) async {
    await _apiClient.dio.post('/auth/reset-password', data: {
      'email': email,
      'resetToken': resetToken,
      'newPassword': newPassword,
    });
  }
}
