import '../core/network/api_client.dart';

class ProfileService {
  ProfileService(this._apiClient);

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> getProfile() async {
    final response = await _apiClient.dio.get('/profile');
    return Map<String, dynamic>.from(response.data);
  }

  Future<void> update(String fullName, String phoneNumber) async {
    await _apiClient.dio.put('/profile', data: {'fullName': fullName, 'phoneNumber': phoneNumber});
  }
}
