import 'package:shared_preferences/shared_preferences.dart';

/// Native key/value store backed by SharedPreferences.
class PrefsStore {
  PrefsStore(this._p);

  static Future<PrefsStore> open() async =>
      PrefsStore(await SharedPreferences.getInstance());

  final SharedPreferences _p;

  String? getString(String key) => _p.getString(key);
  Future<void> setString(String key, String value) => _p.setString(key, value);
  bool? getBool(String key) => _p.getBool(key);
  Future<void> setBool(String key, bool value) => _p.setBool(key, value);
  int? getInt(String key) => _p.getInt(key);
  Future<void> setInt(String key, int value) => _p.setInt(key, value);
  List<String>? getStringList(String key) => _p.getStringList(key);
  Future<void> setStringList(String key, List<String> value) =>
      _p.setStringList(key, value);
  Future<void> remove(String key) => _p.remove(key);
}
