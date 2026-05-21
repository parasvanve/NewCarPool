import '../core/network/api_client.dart';
import '../models/profile_models.dart';

class ProfileService {
  ProfileService(this._apiClient);

  final ApiClient _apiClient;

  Future<UserProfile> getProfile() async {
    final response = await _apiClient.dio.get('/profile');
    return UserProfile.fromJson(Map<String, dynamic>.from(response.data));
  }

  Future<UserProfile> update(String fullName, String phoneNumber) async {
    final response = await _apiClient.dio.put('/profile', data: {
      'fullName': fullName,
      'phoneNumber': phoneNumber,
    });
    return UserProfile.fromJson(Map<String, dynamic>.from(response.data));
  }
}
