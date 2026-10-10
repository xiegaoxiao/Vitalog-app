import 'package:shared_preferences/shared_preferences.dart';

// Browser preview only. The Android app uses SQLite transactions instead.
class LocalStore {
  final _prefs = SharedPreferencesAsync();
  Future<String?> load() => _prefs.getString('vitalog.state.v1');
  Future<void> save(String value) async {
    final old = await load();
    if (old != null) {
      await _prefs.setString('vitalog.previous.v1', old);
    }
    await _prefs.setString('vitalog.state.v1', value);
  }

  Future<String?> previous() => _prefs.getString('vitalog.previous.v1');
}
