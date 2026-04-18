import 'package:shared_preferences/shared_preferences.dart';

class UserPreferencesManager {
  const UserPreferencesManager();

  static const String _usernameKey = 'username';

  Future<String?> getUsername() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(_usernameKey);
  }

  Future<void> saveUsername(String username) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usernameKey, username);
  }
}
