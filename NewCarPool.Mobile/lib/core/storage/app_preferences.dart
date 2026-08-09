//  cat > /home/claude/NewCarPool/NewCarPool.Mobile/lib/core/storage/app_preferences.dart << 'EOF'
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores simple user preferences (theme, notification toggle, etc).
class AppPreferences {
  static const _darkModeKey = 'pref_dark_mode';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<bool> get isDarkModeEnabled async =>
      (await _storage.read(key: _darkModeKey)) == 'true';

  Future<void> setDarkModeEnabled(bool value) async {
    await _storage.write(key: _darkModeKey, value: value ? 'true' : 'false');
  }
}
// EOF
// cat /home/claude/NewCarPool/NewCarPool.Mobile/lib/core/storage/app_preferences.dart
// Output

// import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// /// Stores simple user preferences (theme, notification toggle, etc).
// class AppPreferences {
//   static const _darkModeKey = 'pref_dark_mode';

//   final FlutterSecureStorage _storage = const FlutterSecureStorage();

//   Future<bool> get isDarkModeEnabled async =>
//       (await _storage.read(key: _darkModeKey)) == 'true';

//   Future<void> setDarkModeEnabled(bool value) async {
//     await _storage.write(key: _darkModeKey, value: value ? 'true' : 'false');
//   }
// }
