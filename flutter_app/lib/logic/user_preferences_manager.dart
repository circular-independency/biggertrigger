import 'package:shared_preferences/shared_preferences.dart';

/// Simple persistent storage for user-editable local app settings.
class UserPreferencesManager {
  const UserPreferencesManager();

  static const String _usernameKey = 'username';
  static const String _serverUrlKey = 'server_url';

  static Future<String?> getUsername() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(_usernameKey);
  }

  static Future<void> saveUsername(String username) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usernameKey, username);
  }

  static Future<String?> getServerUrl() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(_serverUrlKey);
  }

  static Future<void> saveServerUrl(String serverUrl) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverUrlKey, serverUrl);
  }
}
