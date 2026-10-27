import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:open_iptv/core/models/channel.dart' as model;
import 'package:open_iptv/core/models/episode.dart' as model;
import 'package:open_iptv/core/models/movie.dart' as model;
import 'package:open_iptv/core/models/profile.dart' as model;
import 'package:open_iptv/core/models/programme.dart' as model;
import 'package:open_iptv/core/models/series.dart' as model;
import 'package:open_iptv/core/models/source.dart' as model;

class AppDatabase {
  AppDatabase();
  Future<void> close() async {}
  static AppDatabase background() => AppDatabase();

  // In-memory storage for web (persisted via shared_preferences).
  static final List<model.Profile> _profiles = [];
  static final List<model.Source> _sources = [];
  static bool _profilesLoaded = false;
  static bool _sourcesLoaded = false;
  static const _kProfilesKey = 'iptv_profiles';
  static const _kSourcesKey = 'iptv_sources';

  static Future<void> _ensureProfilesLoaded() async {
    if (_profilesLoaded) return;
    _profilesLoaded = true;
    if (_profiles.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kProfilesKey);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        _profiles.addAll(list
            .map((e) => model.Profile.fromJson(e as Map<String, dynamic>)));
      }
    }
  }

  static Future<void> _persistProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _kProfilesKey, jsonEncode(_profiles.map((p) => p.toJson()).toList()));
  }

  static Future<void> _ensureSourcesLoaded() async {
    if (_sourcesLoaded) return;
    _sourcesLoaded = true;
    if (_sources.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kSourcesKey);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        _sources.addAll(
            list.map((e) => model.Source.fromJson(e as Map<String, dynamic>)));
      }
    }
  }

  static Future<void> _persistSources() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _kSourcesKey, jsonEncode(_sources.map((s) => s.toJson()).toList()));
  }

  Future<List<model.Profile>> getAllProfiles() async {
    await _ensureProfilesLoaded();
    return List.of(_profiles);
  }
  Future<model.Profile?> getProfileById(String id) async {
    await _ensureProfilesLoaded();
    try { return _profiles.firstWhere((p) => p.id == id); } catch (_) { return null; }
  }

  Future<List<model.Source>> getAllSources() async {
    await _ensureSourcesLoaded();
    return List.of(_sources);
  }
  Future<model.Source?> getSourceById(String id) async {
    await _ensureSourcesLoaded();
    try { return _sources.firstWhere((s) => s.id == id); } catch (_) { return null; }
  }

  Future<void> upsertProfile(model.Profile profile) async {
    await _ensureProfilesLoaded();
    _profiles.removeWhere((p) => p.id == profile.id);
    _profiles.add(profile);
    await _persistProfiles();
  }
  Future<void> deleteProfile(String id) async {
    await _ensureProfilesLoaded();
    _profiles.removeWhere((p) => p.id == id);
    await _persistProfiles();
  }
  Future<void> upsertSource(model.Source source) async {
    await _ensureSourcesLoaded();
    _sources.removeWhere((s) => s.id == source.id);
    _sources.add(source);
    await _persistSources();
  }
  Future<void> deleteSource(String id) async {
    await _ensureSourcesLoaded();
    _sources.removeWhere((s) => s.id == id);
    await _persistSources();
  }

  Future<void> updateSourceRefreshTime(String id, DateTime time) async {
    await _ensureSourcesLoaded();
    final idx = _sources.indexWhere((s) => s.id == id);
    if (idx >= 0) {
      _sources[idx] = _sources[idx].copyWith(lastRefreshed: time);
      await _persistSources();
    }
  }

  Stream<List<model.Channel>> watchChannelsForSource(String sourceId, {String? profileId}) => Stream.value([]);
  Future<void> upsertChannels(List<model.Channel> channelList) async {}
  Future<void> deleteChannelsForSource(String sourceId) async {}
  Future<List<model.Channel>> getAllChannels({String? profileId}) async => [];
  Stream<List<model.Channel>> watchAllChannels({String? profileId}) => Stream.value([]);
  Future<model.Channel?> getChannelById(String id) async => null;
  Future<void> updateChannelLastWatched(String profileId, String id) async {}
  Future<void> clearChannelLastWatched(String profileId, String id) async {}
  Stream<List<model.Channel>> watchRecentChannels(String profileId, {int limit = 20, String? sourceId}) => Stream.value([]);

  Future<void> upsertProgrammes(List<model.Programme> programmes) async {}
  Future<void> deleteOldProgrammes() async {}
  Future<int> getMaxCatchupDaysForSource(String sourceId) async => 0;
  Future<model.Programme?> getCurrentProgramme(String channelId) async => null;
  Future<model.Programme?> getNextProgramme(String channelId) async => null;
  Future<List<model.Programme>> getProgrammesForChannelOnDate(String channelId, DateTime date) async => [];
  Future<List<model.Programme>> getProgrammesForChannelsInRange(List<String> channelIds, DateTime rangeStart, DateTime rangeEnd) async => [];
  Future<List<model.Programme>> getProgrammesForChannelInRange(String channelId, DateTime rangeStart, DateTime rangeEnd) async => [];
  Future<List<model.Programme>> searchProgrammes(String query) async => [];
  Future<List<model.Programme>> searchCurrentProgrammes(String query) async => [];

  Future<List<model.Movie>> getAllMovies({String? profileId}) async => [];
  Stream<List<model.Movie>> watchAllMovies({String? profileId}) => Stream.value([]);
  Stream<List<model.Movie>> watchMoviesForSource(String sourceId, {String? profileId}) => Stream.value([]);
  Stream<model.Movie?> watchMovieById(String id, {String? profileId}) => Stream.value(null);
  Future<List<model.Movie>> getMoviesInGenre(String sourceId, String genre, {required String excludeId, int limit = 60, String? profileId}) async => [];
  Stream<List<model.Movie>> watchMoviesInProgress(String profileId) => Stream.value([]);
  Future<void> clearMovieProgress(String profileId, String id) async {}
  Future<void> clearEpisodeProgress(String profileId, String id) async {}
  Future<void> upsertMovies(List<model.Movie> movieList) async {}
  Future<void> updateMovieProgress(String profileId, String id, Duration watched, Duration total) async {}
  Future<void> deleteMoviesForSource(String sourceId) async {}

  Future<List<model.Series>> getAllSeries() async => [];
  Stream<List<model.Series>> watchAllSeries() => Stream.value([]);
  Future<model.Series?> getSeriesById(String id) async => null;
  Future<List<model.Series>> getSeriesInGenre(String sourceId, String genre, {required String excludeId, int limit = 60}) async => [];
  Stream<List<model.Series>> watchSeriesForSource(String sourceId) => Stream.value([]);
  Future<void> upsertSeries(List<model.Series> seriesList) async {}
  Future<void> deleteSeriesForSource(String sourceId) async {}

  Future<List<model.Episode>> getEpisodesForSeries(String seriesId, {String? profileId}) async => [];
  Future<model.Episode?> getEpisodeById(String id) async => null;
  Stream<List<model.Episode>> watchEpisodesForSeries(String seriesId, {String? profileId}) => Stream.value([]);
  Future<void> upsertEpisodes(List<model.Episode> episodeList) async {}
  Future<void> updateEpisodeProgress(String profileId, String id, Duration watched, Duration total) async {}
  Future<void> deleteEpisodesForSource(String sourceId) async {}
  Stream<List<model.Episode>> watchEpisodesInProgress(String profileId) => Stream.value([]);

  Stream<List<model.Profile>> watchAllProfiles() => Stream.value([]);

  Future<({List<model.Channel> channels, List<model.Movie> movies, List<model.Series> series})> searchCatalog(String query, {String? sourceId, Set<String> airingChannelIds = const {}}) async => (channels: <model.Channel>[], movies: <model.Movie>[], series: <model.Series>[]);

  Future<List<dynamic>> customSelect(String query) async => [];
  Future<void> logStorageStats() async {}
  Future<bool> compactIfBloated({required int freeDiskBytes}) async => false;
  Future<void> compact() async {}
  Future<Map<String, String>> channelIdsByTvgId(String preferSourceId) async => {};
  Future<List<({bool movie, String url})>> speedTestCandidates(String? sourceId, {int each = 3}) async => [];
  Future<void> remapProgrammeChannelIds() async {}
  Future<void> deleteProgrammesForSource(String sourceId) async {}
  Future<void> replaceChannelsForSource(String sourceId, List<model.Channel> channelList) async {}
  Future<void> replaceMoviesForSource(String sourceId, List<model.Movie> movieList) async {}
  Future<void> replaceSeriesForSource(String sourceId, List<model.Series> seriesList) async {}
  Future<void> replaceEpisodesForSource(String sourceId, List<model.Episode> episodeList) async {}
}
