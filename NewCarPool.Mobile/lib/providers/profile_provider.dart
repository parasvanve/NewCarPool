import 'package:flutter/foundation.dart';

import '../models/profile_models.dart';
import '../services/profile_service.dart';

class ProfileProvider extends ChangeNotifier {
  ProfileProvider(this._profileService);

  final ProfileService _profileService;

  UserProfile? profile;
  bool isLoading = false;
  String? errorMessage;

  Future<void> loadProfile() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      profile = await _profileService.getProfile();
    } catch (error) {
      errorMessage = error.toString();
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> update(String fullName, String phoneNumber) async {
    isLoading = true;
    notifyListeners();
    try {
      profile = await _profileService.update(fullName, phoneNumber);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
