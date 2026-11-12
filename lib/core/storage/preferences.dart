import 'package:open_iptv/ui/platform_helper.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'preferences.g.dart';

const _kActiveProfileId = 'active_profile_id';
const _kActiveSourceId = 'active_source_id';
const _kAccentColor = 'accent_color'; // hex string e.g. '0A84FF'
const kSkipDbEncryptionKey = 'skip_db_encryption';
const _kContentSort = 'content_sort'; // 'az' | 'provider'
const _kChannelListDensity =
    'channel_list_density'; // 'comfortable' | 'compact'
const _kViewModeLive = 'view_mode_live'; // 'list' | 'grid'
const _kViewModeMovies = 'view_mode_movies'; // 'list' | 'grid'
const _kViewModeSeries = 'view_mode_series'; // 'list' | 'grid'
const _kParentalProtectionEnabled = 'parental_protection_enabled';
const _kParentalLockedCats = 'parental_locked_cats';
const _kParentalScanDone = 'parental_scan_done';
// Device-only (never in backups): fingerprint / face in place of the admin PIN.
const _kAdminBiometricUnlock = 'admin_biometric_unlock';
const _kRefreshIntervalHours = 'refresh_interval_hours'; // 0 = off
const _kLastRegisteredRefreshIntervalHours =
    'last_registered_refresh_interval_hours';
const _kRefreshNotificationsEnabled = 'refresh_notifications_enabled';
const _kPipEnabled = 'pip_enabled';
const _kAutoFrameRate = 'auto_frame_rate';
const _kMediaNotificationEnabled = 'media_notification_enabled';
const _kAutoUpdateCheck = 'auto_update_check';
const _kCleanNames = 'clean_names';
const _kRecentSearches = 'recent_searches';
const _kVideoFit = 'video_fit'; // 'fit' | 'fill' | 'zoom'
const _kPlayerClockAlways = 'player_clock_always';
const _kAskStartOver = 'ask_start_over';
const _kPanelTimeoutSeconds = 'panel_timeout_seconds'; // player controls
const _kSkipSeconds = 'skip_seconds'; // skip buttons in the player
const _kLanguage = 'language'; // 'auto' or a language tag such as 'es' (#172)
const _kFontScale = 'font_scale'; // text size multiplier (Appearance)
const _kOverlayOpacity = 'overlay_opacity'; // 'solid' | 'normal' | 'clear' | 'veryclear'
const _kGuideDays = 'guide_days_ahead'; // days of guide to keep ahead
const _kSmartGuide = 'smart_guide_assign'; // match channels without a guide
const _kGuideMatchMode = 'guide_match_mode'; // explicit | standard | optimistic
const _kGuideDescriptions = 'guide_descriptions'; // store programme descriptions
const _kStartOnBoot = 'start_on_boot'; // TV: open the app when the TV starts
const _kStartOnWake = 'start_on_wake'; // TV: open the app when the TV wakes
const _kShowFavoritesCat = 'show_cat_favorites';
const _kShowRecentCat = 'show_cat_recent';
const _kShowAllCat = 'show_cat_all';
const _kGuideNames = 'guide_show_names';
const _kGuideTwoLineNames = 'guide_two_line_names';
const _kGuideTwoLineTitles = 'guide_two_line_titles';
const _kGuideHighlight = 'guide_highlight_playing';
const _kChannelCustom = 'channel_custom'; // per profile: hidden channels, names
const _kSeekKeys = 'seek_keys'; // which remote keys seek in catch-up / movies
const _kAudioDelayMs = 'audio_delay_ms'; // lip-sync shift
const _kStreamDetails = 'stream_details'; // resolution/fps/audio badges
const _kLastChannelOnStart = 'last_channel_on_start';
const _kBufferPreset = 'buffer_preset'; // see BufferPreset ids
const _kFullResImages = 'full_res_images'; // Power User Tools
const _kAudioPassthrough = 'audio_passthrough'; // auto | on | off (#159)
const _kTunneledPlayback = 'tunneled_playback'; // auto | on | off (#159)
const _kUserAgent = 'user_agent'; // custom player user agent (Power User Tools)
const _kVpnRoute = 'vpn_route'; // 'app' | 'device'
const _kVpnAutoConnect = 'vpn_auto_connect';
const _kVpnKind = 'vpn_kind'; // 'wireguard' | 'openvpn' (last connected)
const _kHomeLayoutMovies = 'home_layout_movies'; // 'posters' | 'compact'
const _kHomeLayoutSeries = 'home_layout_series'; // 'posters' | 'compact'
const _kLastUpdateCheckMs = 'last_update_check_ms';
const _kSkippedUpdateVersion = 'skipped_update_version';

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
  Future<void> setActiveSourceId(String? id) => id != null
      ? _prefs.setString(_kActiveSourceId, id)
      : _prefs.remove(_kActiveSourceId);

  String get accentColor => _prefs.getString(_kAccentColor) ?? '0A84FF';
  Future<void> setAccentColor(String hex) =>
      _prefs.setString(_kAccentColor, hex);

  bool get skipDbEncryption => _prefs.getBool(kSkipDbEncryptionKey) ?? false;
  Future<void> setSkipDbEncryption(bool value) =>
      _prefs.setBool(kSkipDbEncryptionKey, value);

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

  /// Fingerprint / face may stand in for the admin PIN on this device
  /// (#47). Turned on under profile → Security with the admin PIN.
  bool get adminBiometricUnlock =>
      _prefs.getBool(_kAdminBiometricUnlock) ?? false;
  Future<void> setAdminBiometricUnlock(bool v) =>
      _prefs.setBool(_kAdminBiometricUnlock, v);

  bool get parentalScanDone => _prefs.getBool(_kParentalScanDone) ?? false;
  Future<void> setParentalScanDone(bool v) =>
      _prefs.setBool(_kParentalScanDone, v);

  // Background auto-refresh
  int get refreshIntervalHours => _prefs.getInt(_kRefreshIntervalHours) ?? 0;
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

  // Picture-in-Picture — defaults to on for phones/tablets, off on TV (the TV
  // screen IS the display, so PiP is less useful — but the user can still
  // enable it in Settings, see setPipEnabled).
  bool get pipEnabled {
    final stored = _prefs.getBool(_kPipEnabled);
    if (stored != null) return stored;
    return !PlatformHelper.isTVDevice;
  }

  Future<void> setPipEnabled(bool v) => _prefs.setBool(_kPipEnabled, v);

  /// Match the screen's refresh rate to the video (#149). Off by default.
  bool get autoFrameRate => _prefs.getBool(_kAutoFrameRate) ?? false;
  Future<void> setAutoFrameRate(bool v) => _prefs.setBool(_kAutoFrameRate, v);

  // Now Playing / media notification
  bool get mediaNotificationEnabled =>
      _prefs.getBool(_kMediaNotificationEnabled) ?? true;
  Future<void> setMediaNotificationEnabled(bool v) =>
      _prefs.setBool(_kMediaNotificationEnabled, v);

  // Tidy provider names for display (display_name.dart).
  // Player: how the picture fits the screen.
  String get videoFit => _prefs.getString(_kVideoFit) ?? 'fit';
  Future<void> setVideoFit(String v) => _prefs.setString(_kVideoFit, v);

  bool get playerClockAlways => _prefs.getBool(_kPlayerClockAlways) ?? false;
  Future<void> setPlayerClockAlways(bool v) =>
      _prefs.setBool(_kPlayerClockAlways, v);

  /// Catch-up channels: ask "Start from the beginning or Watch live?" when
  /// opening a show that's already underway.
  bool get askStartOver => _prefs.getBool(_kAskStartOver) ?? true;
  Future<void> setAskStartOver(bool v) => _prefs.setBool(_kAskStartOver, v);

  /// How long the player's on-screen controls stay up before hiding.
  int get panelTimeoutSeconds => _prefs.getInt(_kPanelTimeoutSeconds) ?? 4;
  Future<void> setPanelTimeoutSeconds(int v) =>
      _prefs.setInt(_kPanelTimeoutSeconds, v);

  /// How far the player's skip back / forward buttons jump (5, 10 or 30).
  int get skipSeconds => _prefs.getInt(_kSkipSeconds) ?? 10;
  Future<void> setSkipSeconds(int v) => _prefs.setInt(_kSkipSeconds, v);

  /// 'media' (rewind / fast-forward keys), 'leftRight' or 'upDown'.
  /// Live TV categories the user can switch off.
  bool get showFavoritesCategory => _prefs.getBool(_kShowFavoritesCat) ?? true;
  Future<void> setShowFavoritesCategory(bool v) =>
      _prefs.setBool(_kShowFavoritesCat, v);
  bool get showRecentCategory => _prefs.getBool(_kShowRecentCat) ?? true;
  Future<void> setShowRecentCategory(bool v) =>
      _prefs.setBool(_kShowRecentCat, v);
  bool get showAllCategory => _prefs.getBool(_kShowAllCat) ?? true;
  Future<void> setShowAllCategory(bool v) => _prefs.setBool(_kShowAllCat, v);

  /// TV guide display options.
  bool get guideShowNames => _prefs.getBool(_kGuideNames) ?? true;
  Future<void> setGuideShowNames(bool v) => _prefs.setBool(_kGuideNames, v);
  bool get guideTwoLineNames => _prefs.getBool(_kGuideTwoLineNames) ?? true;
  Future<void> setGuideTwoLineNames(bool v) =>
      _prefs.setBool(_kGuideTwoLineNames, v);
  bool get guideTwoLineTitles => _prefs.getBool(_kGuideTwoLineTitles) ?? false;
  Future<void> setGuideTwoLineTitles(bool v) =>
      _prefs.setBool(_kGuideTwoLineTitles, v);
  bool get guideHighlightPlaying => _prefs.getBool(_kGuideHighlight) ?? true;
  Future<void> setGuideHighlightPlaying(bool v) =>
      _prefs.setBool(_kGuideHighlight, v);

  /// Hidden channels and display names, as JSON keyed by profile id.
  String? get channelCustomJson => _prefs.getString(_kChannelCustom);
  Future<void> setChannelCustomJson(String v) =>
      _prefs.setString(_kChannelCustom, v);

  /// App language: 'auto' (follow the system) or a language tag such as 'es'.
  /// One choice for the whole app, not per profile; included in backups.
  String get language => _prefs.getString(_kLanguage) ?? 'auto';
  Future<void> setLanguage(String v) => _prefs.setString(_kLanguage, v);

  /// Text size multiplier on top of the system's: 0.85, 1.0, 1.15 or 1.3.
  double get fontScale => _prefs.getDouble(_kFontScale) ?? 1.0;
  Future<void> setFontScale(double v) => _prefs.setDouble(_kFontScale, v);

  /// How see-through the player's panels and controls backdrop are.
  String get overlayOpacity => _prefs.getString(_kOverlayOpacity) ?? 'normal';
  Future<void> setOverlayOpacity(String v) =>
      _prefs.setString(_kOverlayOpacity, v);

  /// Days of TV guide kept ahead of now (1 to 14, default 5).
  int get guideDaysAhead => _prefs.getInt(_kGuideDays) ?? 5;
  Future<void> setGuideDaysAhead(int v) => _prefs.setInt(_kGuideDays, v);

  /// Whether programme descriptions are stored (they are most of the guide's size).
  bool get guideDescriptions => _prefs.getBool(_kGuideDescriptions) ?? true;
  Future<void> setGuideDescriptions(bool v) =>
      _prefs.setBool(_kGuideDescriptions, v);

  /// Whether channels with no guide are matched to a guide by name
  /// (Settings → Playlists & Guides → Extra Guides). On by default; it only does
  /// anything once a guide is available to match against.
  bool get smartGuideAssign => _prefs.getBool(_kSmartGuide) ?? true;
  Future<void> setSmartGuideAssign(bool v) => _prefs.setBool(_kSmartGuide, v);

  /// How strictly channels are matched to guides: 'explicit' (guide id only),
  /// 'standard' (id or exact name) or 'optimistic' (also similar names).
  String get guideMatchMode => _prefs.getString(_kGuideMatchMode) ?? 'standard';
  Future<void> setGuideMatchMode(String v) =>
      _prefs.setString(_kGuideMatchMode, v);

  bool get startOnBoot => _prefs.getBool(_kStartOnBoot) ?? false;
  Future<void> setStartOnBoot(bool v) => _prefs.setBool(_kStartOnBoot, v);
  bool get startOnWake => _prefs.getBool(_kStartOnWake) ?? false;
  Future<void> setStartOnWake(bool v) => _prefs.setBool(_kStartOnWake, v);

  // Per-playlist guide status (Settings → Advanced → Guide Data); not backed up.
  int? guideUpdatedMs(String sourceId) => _prefs.getInt('epg_ok_$sourceId');
  int? guideProgrammeCount(String sourceId) => _prefs.getInt('epg_n_$sourceId');
  String? guideError(String sourceId) => _prefs.getString('epg_err_$sourceId');
  Future<void> setGuideStatus(String sourceId,
      {int? updatedMs, int? count, String? error}) async {
    if (updatedMs != null) {
      await _prefs.setInt('epg_ok_$sourceId', updatedMs);
      await _prefs.setInt('epg_n_$sourceId', count ?? 0);
      await _prefs.remove('epg_err_$sourceId');
    } else if (error != null) {
      await _prefs.setString('epg_err_$sourceId', error);
    }
  }

  Future<void> clearGuideStatus() async {
    for (final k in _prefs.getKeys().toList()) {
      if (k.startsWith('epg_ok_') || k.startsWith('epg_n_') || k.startsWith('epg_err_')) {
        await _prefs.remove(k);
      }
    }
  }

  String get seekKeys => _prefs.getString(_kSeekKeys) ?? 'media';
  Future<void> setSeekKeys(String v) => _prefs.setString(_kSeekKeys, v);

  int get audioDelayMs => _prefs.getInt(_kAudioDelayMs) ?? 0;
  Future<void> setAudioDelayMs(int v) => _prefs.setInt(_kAudioDelayMs, v);

  bool get streamDetails => _prefs.getBool(_kStreamDetails) ?? true;
  Future<void> setStreamDetails(bool v) => _prefs.setBool(_kStreamDetails, v);

  /// Start the last watched channel when the app opens.
  bool get lastChannelOnStart => _prefs.getBool(_kLastChannelOnStart) ?? false;
  Future<void> setLastChannelOnStart(bool v) =>
      _prefs.setBool(_kLastChannelOnStart, v);

  /// Player buffer size (Power User Tools); null = the default.
  String? get bufferPreset => _prefs.getString(_kBufferPreset);
  Future<void> setBufferPreset(String v) => _prefs.setString(_kBufferPreset, v);

  /// Decode posters, logos and backdrops at full resolution (Power User
  /// Tools); off = sized to how they are drawn. On by default, for new
  /// installs and updates alike (no stored value = on).
  bool get fullResImages => _prefs.getBool(_kFullResImages) ?? true;
  Future<void> setFullResImages(bool v) => _prefs.setBool(_kFullResImages, v);

  /// A custom user agent for streams (Power User Tools); null = the app's own.
  /// 'auto' (default) | 'on' | 'off'. See docs/design/tunneling-passthrough.md.
  String get audioPassthrough => _prefs.getString(_kAudioPassthrough) ?? 'auto';
  Future<void> setAudioPassthrough(String v) =>
      _prefs.setString(_kAudioPassthrough, v);
  String get tunneledPlayback => _prefs.getString(_kTunneledPlayback) ?? 'auto';
  Future<void> setTunneledPlayback(String v) =>
      _prefs.setString(_kTunneledPlayback, v);

  String? get userAgent => _prefs.getString(_kUserAgent);
  Future<void> setUserAgent(String? v) => v == null || v.isEmpty
      ? _prefs.remove(_kUserAgent)
      : _prefs.setString(_kUserAgent, v);

  /// Built-in VPN: send only OpenIPTV ('app', default) or the whole device
  /// ('device') through the tunnel; and whether to connect on app start.
  String get vpnRoute => _prefs.getString(_kVpnRoute) ?? 'app';
  Future<void> setVpnRoute(String v) => _prefs.setString(_kVpnRoute, v);
  bool get vpnAutoConnect => _prefs.getBool(_kVpnAutoConnect) ?? false;
  Future<void> setVpnAutoConnect(bool v) => _prefs.setBool(_kVpnAutoConnect, v);
  String get vpnKind => _prefs.getString(_kVpnKind) ?? 'wireguard';
  Future<void> setVpnKind(String v) => _prefs.setString(_kVpnKind, v);

  // Search: the last few queries that led somewhere, newest first.
  List<String> get recentSearches =>
      _prefs.getStringList(_kRecentSearches) ?? const [];
  Future<void> setRecentSearches(List<String> v) =>
      _prefs.setStringList(_kRecentSearches, v);

  bool get cleanNames => _prefs.getBool(_kCleanNames) ?? true;
  Future<void> setCleanNames(bool v) => _prefs.setBool(_kCleanNames, v);

  // Movies / Series home: genre poster rails or the compact genre list.
  String get homeLayoutMovies =>
      _prefs.getString(_kHomeLayoutMovies) ?? 'posters';
  Future<void> setHomeLayoutMovies(String v) =>
      _prefs.setString(_kHomeLayoutMovies, v);

  String get homeLayoutSeries =>
      _prefs.getString(_kHomeLayoutSeries) ?? 'posters';
  Future<void> setHomeLayoutSeries(String v) =>
      _prefs.setString(_kHomeLayoutSeries, v);

  // Sideload self-updater (see update_service.dart)
  bool get autoUpdateCheck => _prefs.getBool(_kAutoUpdateCheck) ?? true;
  Future<void> setAutoUpdateCheck(bool v) =>
      _prefs.setBool(_kAutoUpdateCheck, v);

  DateTime? get lastUpdateCheck {
    final ms = _prefs.getInt(_kLastUpdateCheckMs);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> setLastUpdateCheck(DateTime t) =>
      _prefs.setInt(_kLastUpdateCheckMs, t.millisecondsSinceEpoch);

  /// A release the user chose "Skip this version" for — not offered again
  /// automatically (a manual check still shows it).
  String? get skippedUpdateVersion => _prefs.getString(_kSkippedUpdateVersion);
  Future<void> setSkippedUpdateVersion(String? v) => v == null
      ? _prefs.remove(_kSkippedUpdateVersion)
      : _prefs.setString(_kSkippedUpdateVersion, v);
}
