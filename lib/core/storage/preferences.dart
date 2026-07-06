import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'preferences.g.dart';

const _kActiveProfileId = 'active_profile_id';
const _kActiveSourceId = 'active_source_id';
const _kAccentColor = 'accent_color'; // hex string e.g. '0A84FF'
const _kContentSort = 'content_sort'; // 'az' | 'provider'
const _kChannelListDensity = 'channel_list_density'; // 'comfortable' | 'compact'
const _kViewModeLive = 'view_mode_live';       // 'list' | 'grid'
const _kViewModeMovies = 'view_mode_movies';   // 'list' | 'grid'
const _kViewModeSeries = 'view_mode_series';   // 'list' | 'grid'
const _kParentalProtectionEnabled = 'parental_protection_enabled';
const _kParentalLockedCats = 'parental_locked_cats';
const _kParentalScanDone = 'parental_scan_done';
const _kRefreshIntervalHours = 'refresh_interval_hours'; // 0 = off
const _kLastRegisteredRefreshIntervalHours = 'last_registered_refresh_interval_hours';
const _kRefreshNotificationsEnabled = 'refresh_notifications_enabled';
const _kPipEnabled = 'pip_enabled';
const _kMediaNotificationEnabled = 'media_notification_enabled';

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

  String? get activeSourceId => _prefs.getString(_kActiveSourceId);
  Future<void> setActiveSourceId(String? id) =>
      id != null ? _prefs.setString(_kActiveSourceId, id) : _prefs.remove(_kActiveSourceId);

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

  String get viewModeLive => _prefs.getString(_kViewModeLive) ?? 'list';
  Future<void> setViewModeLive(String mode) =>
      _prefs.setString(_kViewModeLive, mode);

  String get viewModeMovies => _prefs.getString(_kViewModeMovies) ?? 'grid';
  Future<void> setViewModeMovies(String mode) =>
      _prefs.setString(_kViewModeMovies, mode);

  String get viewModeSeries => _prefs.getString(_kViewModeSeries) ?? 'grid';
  Future<void> setViewModeSeries(String mode) =>
      _prefs.setString(_kViewModeSeries, mode);

  // Parental controls
  bool get parentalProtectionEnabled =>
      _prefs.getBool(_kParentalProtectionEnabled) ?? false;
  Future<void> setParentalProtectionEnabled(bool v) =>
      _prefs.setBool(_kParentalProtectionEnabled, v);

  List<String> get parentalLockedCategories =>
      _prefs.getStringList(_kParentalLockedCats) ?? [];
  Future<void> setParentalLockedCategories(List<String> cats) =>
      _prefs.setStringList(_kParentalLockedCats, cats);

  bool get parentalScanDone => _prefs.getBool(_kParentalScanDone) ?? false;
  Future<void> setParentalScanDone(bool v) =>
      _prefs.setBool(_kParentalScanDone, v);

  // Background auto-refresh
  int get refreshIntervalHours =>
      _prefs.getInt(_kRefreshIntervalHours) ?? 0;
  Future<void> setRefreshIntervalHours(int hours) =>
      _prefs.setInt(_kRefreshIntervalHours, hours);

  /// Bookkeeping only — the interval WorkManager was last registered with.
  /// Used to decide whether the periodic task needs re-registering, since
  /// WorkManager has no API to read back a task's currently-set interval.
  int get lastRegisteredRefreshIntervalHours =>
      _prefs.getInt(_kLastRegisteredRefreshIntervalHours) ?? 0;
  Future<void> setLastRegisteredRefreshIntervalHours(int hours) =>
      _prefs.setInt(_kLastRegisteredRefreshIntervalHours, hours);

  bool get refreshNotificationsEnabled =>
      _prefs.getBool(_kRefreshNotificationsEnabled) ?? true;
  Future<void> setRefreshNotificationsEnabled(bool v) =>
      _prefs.setBool(_kRefreshNotificationsEnabled, v);

  // Picture-in-Picture
  bool get pipEnabled => _prefs.getBool(_kPipEnabled) ?? true;
  Future<void> setPipEnabled(bool v) => _prefs.setBool(_kPipEnabled, v);

  // Now Playing / media notification
  bool get mediaNotificationEnabled =>
      _prefs.getBool(_kMediaNotificationEnabled) ?? true;
  Future<void> setMediaNotificationEnabled(bool v) =>
      _prefs.setBool(_kMediaNotificationEnabled, v);
}
