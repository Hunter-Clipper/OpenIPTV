import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'preferences.g.dart';

const _kActiveProfileId = 'active_profile_id';
const _kThemeMode = 'theme_mode'; // 'dark' | 'light' | 'system'
const _kAccentColor = 'accent_color'; // hex string e.g. '0A84FF'
const _kContentSort = 'content_sort'; // 'az' | 'provider'
const _kChannelListDensity = 'channel_list_density'; // 'comfortable' | 'compact'

@Riverpod(keepAlive: true)
Future<AppPreferences> appPreferences(AppPreferencesRef ref) async {
  final prefs = await SharedPreferences.getInstance();
  return AppPreferences(prefs);
}

class AppPreferences {
  AppPreferences(this._prefs);

  final SharedPreferences _prefs;

  String? get activeProfileId => _prefs.getString(_kActiveProfileId);
  Future<void> setActiveProfileId(String id) =>
      _prefs.setString(_kActiveProfileId, id);

  String get themeMode => _prefs.getString(_kThemeMode) ?? 'dark';
  Future<void> setThemeMode(String mode) =>
      _prefs.setString(_kThemeMode, mode);

  String get accentColor => _prefs.getString(_kAccentColor) ?? '0A84FF';
  Future<void> setAccentColor(String hex) =>
      _prefs.setString(_kAccentColor, hex);

  String get contentSort => _prefs.getString(_kContentSort) ?? 'provider';
  Future<void> setContentSort(String sort) =>
      _prefs.setString(_kContentSort, sort);

  String get channelListDensity =>
      _prefs.getString(_kChannelListDensity) ?? 'comfortable';
  Future<void> setChannelListDensity(String density) =>
      _prefs.setString(_kChannelListDensity, density);
}
