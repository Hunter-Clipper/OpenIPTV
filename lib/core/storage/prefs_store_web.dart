import 'dart:convert';
import 'dart:html' as html;

/// Web key/value store backed by the browser's `localStorage`.
///
/// Used because shared_preferences_web isn't registered in this Flutter web
/// build (its dart2js registrant is tree-shaken), so SharedPreferences's
/// MethodChannel calls are silent no-ops and nothing would persist. Pointing
/// the store at `localStorage` keeps profiles/sources/settings saved across
/// reloads on web. `localStorage` behaves like a `Map<String, String>`.
class PrefsStore {
  PrefsStore._();

  static Future<PrefsStore> open() async => PrefsStore._();

  final html.Storage _ls = html.window.localStorage;

  String? getString(String key) => _ls[key];

  Future<void> setString(String key, String value) async => _ls[key] = value;

  bool? getBool(String key) {
    final v = _ls[key];
    if (v == null) return null;
    return v == 'true';
  }

  Future<void> setBool(String key, bool value) async => _ls[key] = value.toString();

  int? getInt(String key) {
    final v = _ls[key];
    return v == null ? null : int.tryParse(v);
  }

  Future<void> setInt(String key, int value) async => _ls[key] = value.toString();

  List<String>? getStringList(String key) {
    final v = _ls[key];
    if (v == null) return null;
    final decoded = jsonDecode(v);
    return decoded is List ? decoded.map((e) => e.toString()).toList() : null;
  }

  Future<void> setStringList(String key, List<String> value) async =>
      _ls[key] = jsonEncode(value);

  Future<void> remove(String key) async => _ls.remove(key);
}
