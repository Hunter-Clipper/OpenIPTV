import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:open_iptv/core/models/channel.dart' as model;
import 'package:open_iptv/core/models/episode.dart' as model;
import 'package:open_iptv/core/models/movie.dart' as model;
import 'package:open_iptv/core/models/profile.dart' as model;
import 'package:open_iptv/core/models/programme.dart' as model;
import 'package:open_iptv/core/models/series.dart' as model;
import 'package:open_iptv/core/models/source.dart' as model;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

// ---------------------------------------------------------------------------
// Table definitions
// ---------------------------------------------------------------------------

@DataClassName('SourceRow')
class Sources extends Table {
  TextColumn get id => text()();
  TextColumn get nickname => text()();
  TextColumn get type => text()(); // 'm3u' | 'xtream'
  TextColumn get m3uUrl => text().nullable()();
  TextColumn get xtreamHost => text().nullable()();
  TextColumn get xtreamUsername => text().nullable()();
  TextColumn get xtreamPassword => text().nullable()();
  TextColumn get epgUrl => text().nullable()();
  DateTimeColumn get lastRefreshed => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ChannelRow')
class Channels extends Table {
  TextColumn get id => text()();
  TextColumn get sourceId => text().references(Sources, #id)();
  TextColumn get name => text()();
  TextColumn get logoUrl => text().nullable()();
  TextColumn get streamUrl => text()();
  TextColumn get groupTitle => text().nullable()();
  TextColumn get tvgId => text().nullable()();
  TextColumn get tvgName => text().nullable()();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastWatchedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ProgrammeRow')
class Programmes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get channelId => text()();
  DateTimeColumn get start => dateTime()();
  DateTimeColumn get end => dateTime()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get category => text().nullable()();
  TextColumn get episodeNum => text().nullable()();
}

@DataClassName('MovieRow')
class Movies extends Table {
  TextColumn get id => text()();
  TextColumn get sourceId => text().references(Sources, #id)();
  TextColumn get title => text()();
  TextColumn get posterUrl => text().nullable()();
  TextColumn get streamUrl => text()();
  TextColumn get genre => text().nullable()();
  TextColumn get year => text().nullable()();
  TextColumn get rating => text().nullable()();
  TextColumn get description => text().nullable()();
  IntColumn get watchedDurationSeconds => integer().nullable()();
  IntColumn get totalDurationSeconds => integer().nullable()();
  DateTimeColumn get lastWatchedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SeriesRow')
class SeriesEntries extends Table {
  TextColumn get id => text()();
  TextColumn get sourceId => text().references(Sources, #id)();
  TextColumn get title => text()();
  TextColumn get posterUrl => text().nullable()();
  TextColumn get genre => text().nullable()();
  TextColumn get year => text().nullable()();
  TextColumn get description => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('EpisodeRow')
class Episodes extends Table {
  TextColumn get id => text()();
  TextColumn get seriesId => text()();
  TextColumn get sourceId => text().references(Sources, #id)();
  IntColumn get season => integer()();
  IntColumn get episode => integer()();
  TextColumn get title => text()();
  TextColumn get streamUrl => text()();
  TextColumn get stillUrl => text().nullable()();
  IntColumn get watchedDurationSeconds => integer().nullable()();
  IntColumn get totalDurationSeconds => integer().nullable()();
  DateTimeColumn get lastWatchedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ProfileRow')
class Profiles extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get avatarEmoji => text()();
  TextColumn get pinHash => text().nullable()();
  TextColumn get sourceIds => text().withDefault(const Constant('[]'))();
  TextColumn get favoriteChannelIds => text().withDefault(const Constant('[]'))();
  TextColumn get favoriteMovieIds => text().withDefault(const Constant('[]'))();
  TextColumn get favoriteSeriesIds => text().withDefault(const Constant('[]'))();
  TextColumn get defaultCategory => text().withDefault(const Constant('All'))();
  TextColumn get channelSortOrder => text().withDefault(const Constant('provider'))();
  TextColumn get defaultSubtitleLang => text().withDefault(const Constant(''))();
  TextColumn get defaultAudioLang => text().withDefault(const Constant(''))();
  TextColumn get customChannelOrder => text().withDefault(const Constant('{}'))();
  TextColumn get epgOverrides => text().withDefault(const Constant('{}'))();
  TextColumn get hiddenCategories => text().withDefault(const Constant('[]'))();
  BoolColumn get isKidsProfile =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

// ---------------------------------------------------------------------------
// Database
// ---------------------------------------------------------------------------

@DriftDatabase(tables: [
  Sources,
  Channels,
  Programmes,
  Movies,
  SeriesEntries,
  Episodes,
  Profiles,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          await _createIndexes();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 2) await _createIndexes();
          if (from < 3) {
            final tableInfo =
                await customSelect('PRAGMA table_info(channels)').get();
            final hasCol = tableInfo
                .any((r) => r.data['name'] == 'last_watched_at');
            if (!hasCol) {
              await m.addColumn(channels, channels.lastWatchedAt);
            }
          }
          if (from < 4) {
            final tableInfo =
                await customSelect('PRAGMA table_info(profiles)').get();
            final hasCol = tableInfo
                .any((r) => r.data['name'] == 'is_kids_profile');
            if (!hasCol) {
              await m.addColumn(profiles, profiles.isKidsProfile);
            }
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
          await customStatement('PRAGMA journal_mode = WAL');
        },
      );

  Future<void> _createIndexes() async {
    // channels.tvg_id: makes remapProgrammeChannelIds() go from O(n²) → O(n log m)
    // Without this index the remap of 147k programmes against 18k channels takes ~37s
    // and holds the write lock the entire time, blocking any concurrent DB writes.
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_channels_tvg_id ON channels (tvg_id)',
    );
    // programmes.channel_id: used in getCurrentProgramme, getNextProgramme, etc.
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_programmes_channel_id ON programmes (channel_id)',
    );
    // programmes.(channel_id, start, end): composite for the time-range EPG queries
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_programmes_channel_time '
      'ON programmes (channel_id, start, end)',
    );
    // episodes.series_id: used in getEpisodesForSeries
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_episodes_series_id ON episodes (series_id)',
    );
  }

  // ---------------------------------------------------------------------------
  // Source DAOs
  // ---------------------------------------------------------------------------

  Future<List<model.Source>> getAllSources() async {
    final rows = await select(sources).get();
    return rows.map(_sourceFromRow).toList();
  }

  Stream<List<model.Source>> watchAllSources() {
    return select(sources).watch().map(
          (rows) => rows.map(_sourceFromRow).toList(),
        );
  }

  Future<model.Source?> getSourceById(String id) async {
    final row = await (select(sources)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _sourceFromRow(row);
  }

  Future<void> upsertSource(model.Source source) async {
    await into(sources).insertOnConflictUpdate(_sourceToCompanion(source));
  }

  Future<void> deleteSource(String id) async {
    await (delete(sources)..where((t) => t.id.equals(id))).go();
  }

  Future<void> updateSourceRefreshTime(String id, DateTime time) async {
    await (update(sources)..where((t) => t.id.equals(id))).write(
      SourcesCompanion(lastRefreshed: Value(time)),
    );
  }

  // ---------------------------------------------------------------------------
  // Channel DAOs
  // ---------------------------------------------------------------------------

  Future<List<model.Channel>> getChannelsForSource(String sourceId) async {
    final rows = await (select(channels)
          ..where((t) => t.sourceId.equals(sourceId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
    return rows.map(_channelFromRow).toList();
  }

  Stream<List<model.Channel>> watchChannelsForSource(String sourceId) {
    return (select(channels)
          ..where((t) => t.sourceId.equals(sourceId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch()
        .map((rows) => rows.map(_channelFromRow).toList());
  }

  Future<void> upsertChannels(List<model.Channel> channelList) async {
    final companions = channelList.map(_channelToCompanion).toList();
    for (var i = 0; i < companions.length; i += 500) {
      final chunk = companions.sublist(i, (i + 500).clamp(0, companions.length));
      await batch((b) => b.insertAllOnConflictUpdate(channels, chunk));
    }
  }

  Future<void> deleteChannelsForSource(String sourceId) async {
    await (delete(channels)..where((t) => t.sourceId.equals(sourceId))).go();
  }

  Future<void> setChannelFavorite(String id, bool favorite) async {
    await (update(channels)..where((t) => t.id.equals(id))).write(
      ChannelsCompanion(isFavorite: Value(favorite)),
    );
  }

  Future<List<model.Channel>> getAllChannels() async {
    final rows = await select(channels).get();
    return rows.map(_channelFromRow).toList();
  }

  // ---------------------------------------------------------------------------
  // Programme DAOs
  // ---------------------------------------------------------------------------

  Future<void> upsertProgrammes(List<model.Programme> programmes) async {
    final companions = programmes.map(_programmeToCompanion).toList();
    for (var i = 0; i < companions.length; i += 500) {
      final chunk = companions.sublist(i, (i + 500).clamp(0, companions.length));
      await batch((b) => b.insertAllOnConflictUpdate(this.programmes, chunk));
    }
  }

  /// Remaps programme channelId values from XMLTV IDs (e.g. 'BBC1.uk') to the
  /// app's internal channel IDs (e.g. '{sourceId}_ch_30581') by joining on
  /// channels.tvg_id. Must be called after EPG import.
  Future<void> remapProgrammeChannelIds() async {
    await customStatement(
      'UPDATE programmes '
      'SET channel_id = ('
      '  SELECT id FROM channels WHERE tvg_id = programmes.channel_id LIMIT 1'
      ') '
      'WHERE channel_id IN ('
      '  SELECT tvg_id FROM channels WHERE tvg_id IS NOT NULL'
      ')',
    );
  }

  Future<void> deleteOldProgrammes() async {
    final cutoff = DateTime.now().subtract(const Duration(hours: 1));
    await (delete(programmes)..where((t) => t.end.isSmallerThanValue(cutoff)))
        .go();
  }

  Future<void> deleteProgrammesForChannel(String channelId) async {
    await (delete(programmes)
          ..where((t) => t.channelId.equals(channelId)))
        .go();
  }

  Future<model.Programme?> getCurrentProgramme(String channelId) async {
    final now = DateTime.now();
    final row = await (select(programmes)
          ..where((t) =>
              t.channelId.equals(channelId) &
              t.start.isSmallerOrEqualValue(now) &
              t.end.isBiggerThanValue(now))
          ..limit(1))
        .getSingleOrNull();
    return row == null ? null : _programmeFromRow(row);
  }

  Future<model.Programme?> getNextProgramme(String channelId) async {
    final now = DateTime.now();
    final row = await (select(programmes)
          ..where((t) =>
              t.channelId.equals(channelId) & t.start.isBiggerThanValue(now))
          ..orderBy([(t) => OrderingTerm.asc(t.start)])
          ..limit(1))
        .getSingleOrNull();
    return row == null ? null : _programmeFromRow(row);
  }

  Future<List<model.Programme>> getProgrammesForChannelOnDate(
    String channelId,
    DateTime date,
  ) async {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final rows = await (select(programmes)
          ..where((t) =>
              t.channelId.equals(channelId) &
              t.start.isBiggerOrEqualValue(dayStart) &
              t.start.isSmallerThanValue(dayEnd))
          ..orderBy([(t) => OrderingTerm.asc(t.start)]))
        .get();
    return rows.map(_programmeFromRow).toList();
  }

  Future<List<model.Programme>> searchProgrammes(String query) async {
    final q = '%${query.toLowerCase()}%';
    final rows = await (select(programmes)
          ..where((t) => t.title.lower().like(q))
          ..orderBy([(t) => OrderingTerm.asc(t.start)])
          ..limit(50))
        .get();
    return rows.map(_programmeFromRow).toList();
  }

  /// Returns programmes currently airing whose title contains [query].
  /// Used to surface channels in search results via EPG title matching.
  Future<List<model.Programme>> searchCurrentProgrammes(String query) async {
    final now = DateTime.now();
    final q = '%${query.toLowerCase()}%';
    final rows = await (select(programmes)
          ..where((t) =>
              t.title.lower().like(q) &
              t.start.isSmallerOrEqualValue(now) &
              t.end.isBiggerThanValue(now))
          ..limit(100))
        .get();
    return rows.map(_programmeFromRow).toList();
  }

  // ---------------------------------------------------------------------------
  // Movie DAOs
  // ---------------------------------------------------------------------------

  Future<List<model.Movie>> getMoviesForSource(String sourceId) async {
    final rows = await (select(movies)
          ..where((t) => t.sourceId.equals(sourceId))
          ..orderBy([(t) => OrderingTerm.asc(t.title)]))
        .get();
    return rows.map(_movieFromRow).toList();
  }

  Future<List<model.Movie>> getAllMovies() async {
    final rows = await (select(movies)
          ..orderBy([(t) => OrderingTerm.asc(t.title)]))
        .get();
    return rows.map(_movieFromRow).toList();
  }

  Stream<model.Movie?> watchMovieById(String id) {
    return (select(movies)..where((t) => t.id.equals(id)))
        .watchSingleOrNull()
        .map((row) => row == null ? null : _movieFromRow(row));
  }

  Future<List<model.Movie>> getMoviesInProgress() async {
    final rows = await (select(movies)
          ..where((t) =>
              t.watchedDurationSeconds.isNotNull() &
              t.watchedDurationSeconds.isBiggerThanValue(0) &
              t.totalDurationSeconds.isNotNull())
          ..orderBy([(t) => OrderingTerm.desc(t.lastWatchedAt)]))
        .get();
    return rows
        .map(_movieFromRow)
        .where((m) => m.isInProgress)
        .toList();
  }

  Stream<List<model.Movie>> watchMoviesInProgress() {
    return (select(movies)
          ..where((t) =>
              t.watchedDurationSeconds.isNotNull() &
              t.watchedDurationSeconds.isBiggerThanValue(0) &
              t.totalDurationSeconds.isNotNull())
          ..orderBy([(t) => OrderingTerm.desc(t.lastWatchedAt)]))
        .watch()
        .map((rows) => rows
            .map(_movieFromRow)
            .where((m) => m.isInProgress)
            .toList());
  }

  Future<void> clearMovieProgress(String id) async {
    await (update(movies)..where((t) => t.id.equals(id))).write(
      const MoviesCompanion(
        watchedDurationSeconds: Value(0),
        totalDurationSeconds: Value(0),
        lastWatchedAt: Value.absent(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Channel recently-watched
  // ---------------------------------------------------------------------------

  Future<void> updateChannelLastWatched(String id) async {
    await (update(channels)..where((t) => t.id.equals(id))).write(
      ChannelsCompanion(lastWatchedAt: Value(DateTime.now())),
    );
  }

  Future<void> clearChannelLastWatched(String id) async {
    await (update(channels)..where((t) => t.id.equals(id))).write(
      const ChannelsCompanion(lastWatchedAt: Value(null)),
    );
  }

  Stream<List<model.Channel>> watchRecentChannels({int limit = 20}) {
    return (select(channels)
          ..where((t) => t.lastWatchedAt.isNotNull())
          ..orderBy([(t) => OrderingTerm.desc(t.lastWatchedAt)])
          ..limit(limit))
        .watch()
        .map((rows) => rows.map(_channelFromRow).toList());
  }

  // ---------------------------------------------------------------------------
  // Episode continue-watching stream
  // ---------------------------------------------------------------------------

  Stream<List<model.Episode>> watchEpisodesInProgress() {
    return (select(episodes)
          ..where((t) =>
              t.watchedDurationSeconds.isNotNull() &
              t.watchedDurationSeconds.isBiggerThanValue(0) &
              t.totalDurationSeconds.isNotNull())
          ..orderBy([(t) => OrderingTerm.desc(t.lastWatchedAt)]))
        .watch()
        .map((rows) => rows
            .map(_episodeFromRow)
            .where((e) => e.isInProgress)
            .toList());
  }

  Future<void> clearEpisodeProgress(String id) async {
    await (update(episodes)..where((t) => t.id.equals(id))).write(
      const EpisodesCompanion(
        watchedDurationSeconds: Value(0),
        totalDurationSeconds: Value(0),
        lastWatchedAt: Value.absent(),
      ),
    );
  }

  Future<void> upsertMovies(List<model.Movie> movieList) async {
    final companions = movieList.map(_movieToCompanion).toList();
    for (var i = 0; i < companions.length; i += 500) {
      final chunk = companions.sublist(i, (i + 500).clamp(0, companions.length));
      await batch((b) => b.insertAllOnConflictUpdate(movies, chunk));
    }
  }

  Future<void> updateMovieProgress(
    String id,
    Duration watched,
    Duration total,
  ) async {
    await (update(movies)..where((t) => t.id.equals(id))).write(
      MoviesCompanion(
        watchedDurationSeconds: Value(watched.inSeconds),
        totalDurationSeconds: Value(total.inSeconds),
        lastWatchedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteMoviesForSource(String sourceId) async {
    await (delete(movies)..where((t) => t.sourceId.equals(sourceId))).go();
  }

  // ---------------------------------------------------------------------------
  // Series DAOs
  // ---------------------------------------------------------------------------

  Future<List<model.Series>> getSeriesForSource(String sourceId) async {
    final rows = await (select(seriesEntries)
          ..where((t) => t.sourceId.equals(sourceId))
          ..orderBy([(t) => OrderingTerm.asc(t.title)]))
        .get();
    return rows.map(_seriesFromRow).toList();
  }

  Future<List<model.Series>> getAllSeries() async {
    final rows = await (select(seriesEntries)
          ..orderBy([(t) => OrderingTerm.asc(t.title)]))
        .get();
    return rows.map(_seriesFromRow).toList();
  }

  Future<void> upsertSeries(List<model.Series> seriesList) async {
    final companions = seriesList.map(_seriesToCompanion).toList();
    for (var i = 0; i < companions.length; i += 500) {
      final chunk = companions.sublist(i, (i + 500).clamp(0, companions.length));
      await batch((b) => b.insertAllOnConflictUpdate(seriesEntries, chunk));
    }
  }

  Future<void> deleteSeriesForSource(String sourceId) async {
    await (delete(seriesEntries)
          ..where((t) => t.sourceId.equals(sourceId)))
        .go();
  }

  // ---------------------------------------------------------------------------
  // Episode DAOs
  // ---------------------------------------------------------------------------

  Future<List<model.Episode>> getEpisodesForSeries(String seriesId) async {
    final rows = await (select(episodes)
          ..where((t) => t.seriesId.equals(seriesId))
          ..orderBy([
            (t) => OrderingTerm.asc(t.season),
            (t) => OrderingTerm.asc(t.episode),
          ]))
        .get();
    return rows.map(_episodeFromRow).toList();
  }

  Future<List<model.Episode>> getEpisodesInProgress() async {
    final rows = await (select(episodes)
          ..where((t) =>
              t.watchedDurationSeconds.isNotNull() &
              t.watchedDurationSeconds.isBiggerThanValue(0) &
              t.totalDurationSeconds.isNotNull())
          ..orderBy([(t) => OrderingTerm.desc(t.lastWatchedAt)]))
        .get();
    return rows
        .map(_episodeFromRow)
        .where((e) => e.isInProgress)
        .toList();
  }

  Future<void> upsertEpisodes(List<model.Episode> episodeList) async {
    final companions = episodeList.map(_episodeToCompanion).toList();
    for (var i = 0; i < companions.length; i += 500) {
      final chunk = companions.sublist(i, (i + 500).clamp(0, companions.length));
      await batch((b) => b.insertAllOnConflictUpdate(episodes, chunk));
    }
  }

  Future<void> updateEpisodeProgress(
    String id,
    Duration watched,
    Duration total,
  ) async {
    await (update(episodes)..where((t) => t.id.equals(id))).write(
      EpisodesCompanion(
        watchedDurationSeconds: Value(watched.inSeconds),
        totalDurationSeconds: Value(total.inSeconds),
        lastWatchedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteEpisodesForSource(String sourceId) async {
    await (delete(episodes)..where((t) => t.sourceId.equals(sourceId))).go();
  }

  // ---------------------------------------------------------------------------
  // Profile DAOs
  // ---------------------------------------------------------------------------

  Future<List<model.Profile>> getAllProfiles() async {
    final rows = await select(profiles).get();
    return rows.map(_profileFromRow).toList();
  }

  Stream<List<model.Profile>> watchAllProfiles() {
    return select(profiles)
        .watch()
        .map((rows) => rows.map(_profileFromRow).toList());
  }

  Future<model.Profile?> getProfileById(String id) async {
    final row = await (select(profiles)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _profileFromRow(row);
  }

  Future<void> upsertProfile(model.Profile profile) async {
    await into(profiles).insertOnConflictUpdate(_profileToCompanion(profile));
  }

  Future<void> deleteProfile(String id) async {
    await (delete(profiles)..where((t) => t.id.equals(id))).go();
  }

  // ---------------------------------------------------------------------------
  // Mapping helpers — Row → model
  // ---------------------------------------------------------------------------

  model.Source _sourceFromRow(SourceRow row) => model.Source(
        id: row.id,
        nickname: row.nickname,
        type: row.type == 'xtream' ? model.SourceType.xtream : model.SourceType.m3u,
        m3uUrl: row.m3uUrl,
        xtreamHost: row.xtreamHost,
        xtreamUsername: row.xtreamUsername,
        xtreamPassword: row.xtreamPassword,
        epgUrl: row.epgUrl,
        lastRefreshed: row.lastRefreshed,
      );

  model.Channel _channelFromRow(ChannelRow row) => model.Channel(
        id: row.id,
        sourceId: row.sourceId,
        name: row.name,
        logoUrl: row.logoUrl,
        streamUrl: row.streamUrl,
        groupTitle: row.groupTitle,
        tvgId: row.tvgId,
        tvgName: row.tvgName,
        isFavorite: row.isFavorite,
        sortOrder: row.sortOrder,
        lastWatchedAt: row.lastWatchedAt,
      );

  model.Programme _programmeFromRow(ProgrammeRow row) => model.Programme(
        channelId: row.channelId,
        start: row.start,
        end: row.end,
        title: row.title,
        description: row.description,
        category: row.category,
        episodeNum: row.episodeNum,
      );

  model.Movie _movieFromRow(MovieRow row) => model.Movie(
        id: row.id,
        sourceId: row.sourceId,
        title: row.title,
        posterUrl: row.posterUrl,
        streamUrl: row.streamUrl,
        genre: row.genre,
        year: row.year,
        rating: row.rating,
        description: row.description,
        watchedDuration: row.watchedDurationSeconds != null
            ? Duration(seconds: row.watchedDurationSeconds!)
            : null,
        totalDuration: row.totalDurationSeconds != null
            ? Duration(seconds: row.totalDurationSeconds!)
            : null,
      );

  model.Series _seriesFromRow(SeriesRow row) => model.Series(
        id: row.id,
        sourceId: row.sourceId,
        title: row.title,
        posterUrl: row.posterUrl,
        genre: row.genre,
        year: row.year,
        description: row.description,
      );

  model.Episode _episodeFromRow(EpisodeRow row) => model.Episode(
        id: row.id,
        seriesId: row.seriesId,
        sourceId: row.sourceId,
        season: row.season,
        episode: row.episode,
        title: row.title,
        streamUrl: row.streamUrl,
        stillUrl: row.stillUrl,
        watchedDuration: row.watchedDurationSeconds != null
            ? Duration(seconds: row.watchedDurationSeconds!)
            : null,
        totalDuration: row.totalDurationSeconds != null
            ? Duration(seconds: row.totalDurationSeconds!)
            : null,
      );

  model.Profile _profileFromRow(ProfileRow row) => model.Profile(
        id: row.id,
        name: row.name,
        avatarEmoji: row.avatarEmoji,
        pinHash: row.pinHash,
        sourceIds: List<String>.from(jsonDecode(row.sourceIds) as List),
        favoriteChannelIds:
            List<String>.from(jsonDecode(row.favoriteChannelIds) as List),
        favoriteMovieIds:
            List<String>.from(jsonDecode(row.favoriteMovieIds) as List),
        favoriteSeriesIds:
            List<String>.from(jsonDecode(row.favoriteSeriesIds) as List),
        defaultCategory: row.defaultCategory,
        channelSortOrder: row.channelSortOrder,
        defaultSubtitleLang: row.defaultSubtitleLang,
        defaultAudioLang: row.defaultAudioLang,
        customChannelOrder: Map<String, int>.from(
            jsonDecode(row.customChannelOrder) as Map),
        epgOverrides: Map<String, String>.from(
            jsonDecode(row.epgOverrides) as Map),
        hiddenCategories:
            List<String>.from(jsonDecode(row.hiddenCategories) as List),
        isKidsProfile: row.isKidsProfile,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
      );

  // ---------------------------------------------------------------------------
  // Mapping helpers — model → Companion
  // ---------------------------------------------------------------------------

  SourcesCompanion _sourceToCompanion(model.Source s) => SourcesCompanion(
        id: Value(s.id),
        nickname: Value(s.nickname),
        type: Value(s.type == model.SourceType.xtream ? 'xtream' : 'm3u'),
        m3uUrl: Value(s.m3uUrl),
        xtreamHost: Value(s.xtreamHost),
        xtreamUsername: Value(s.xtreamUsername),
        xtreamPassword: Value(s.xtreamPassword),
        epgUrl: Value(s.epgUrl),
        lastRefreshed: Value(s.lastRefreshed),
      );

  ChannelsCompanion _channelToCompanion(model.Channel c) => ChannelsCompanion(
        id: Value(c.id),
        sourceId: Value(c.sourceId),
        name: Value(c.name),
        logoUrl: Value(c.logoUrl),
        streamUrl: Value(c.streamUrl),
        groupTitle: Value(c.groupTitle),
        tvgId: Value(c.tvgId),
        tvgName: Value(c.tvgName),
        isFavorite: Value(c.isFavorite),
        sortOrder: Value(c.sortOrder),
      );

  ProgrammesCompanion _programmeToCompanion(model.Programme p) =>
      ProgrammesCompanion(
        channelId: Value(p.channelId),
        start: Value(p.start),
        end: Value(p.end),
        title: Value(p.title),
        description: Value(p.description),
        category: Value(p.category),
        episodeNum: Value(p.episodeNum),
      );

  MoviesCompanion _movieToCompanion(model.Movie m) => MoviesCompanion(
        id: Value(m.id),
        sourceId: Value(m.sourceId),
        title: Value(m.title),
        posterUrl: Value(m.posterUrl),
        streamUrl: Value(m.streamUrl),
        genre: Value(m.genre),
        year: Value(m.year),
        rating: Value(m.rating),
        description: Value(m.description),
        watchedDurationSeconds: Value(m.watchedDuration?.inSeconds),
        totalDurationSeconds: Value(m.totalDuration?.inSeconds),
      );

  SeriesEntriesCompanion _seriesToCompanion(model.Series s) =>
      SeriesEntriesCompanion(
        id: Value(s.id),
        sourceId: Value(s.sourceId),
        title: Value(s.title),
        posterUrl: Value(s.posterUrl),
        genre: Value(s.genre),
        year: Value(s.year),
        description: Value(s.description),
      );

  EpisodesCompanion _episodeToCompanion(model.Episode e) => EpisodesCompanion(
        id: Value(e.id),
        seriesId: Value(e.seriesId),
        sourceId: Value(e.sourceId),
        season: Value(e.season),
        episode: Value(e.episode),
        title: Value(e.title),
        streamUrl: Value(e.streamUrl),
        stillUrl: Value(e.stillUrl),
        watchedDurationSeconds: Value(e.watchedDuration?.inSeconds),
        totalDurationSeconds: Value(e.totalDuration?.inSeconds),
      );

  ProfilesCompanion _profileToCompanion(model.Profile p) => ProfilesCompanion(
        id: Value(p.id),
        name: Value(p.name),
        avatarEmoji: Value(p.avatarEmoji),
        pinHash: Value(p.pinHash),
        sourceIds: Value(jsonEncode(p.sourceIds)),
        favoriteChannelIds: Value(jsonEncode(p.favoriteChannelIds)),
        favoriteMovieIds: Value(jsonEncode(p.favoriteMovieIds)),
        favoriteSeriesIds: Value(jsonEncode(p.favoriteSeriesIds)),
        defaultCategory: Value(p.defaultCategory),
        channelSortOrder: Value(p.channelSortOrder),
        defaultSubtitleLang: Value(p.defaultSubtitleLang),
        defaultAudioLang: Value(p.defaultAudioLang),
        customChannelOrder: Value(jsonEncode(p.customChannelOrder)),
        epgOverrides: Value(jsonEncode(p.epgOverrides)),
        hiddenCategories: Value(jsonEncode(p.hiddenCategories)),
        isKidsProfile: Value(p.isKidsProfile),
        createdAt: Value(p.createdAt),
        updatedAt: Value(p.updatedAt),
      );
}

// Top-level so Isolate.spawn can send it across isolate boundaries.
void _dbSetup(dynamic db) {
  // Wait up to 5s for any transient external lock (OS backup, WAL recovery)
  // before failing with SQLITE_BUSY. Must be set before migrations run.
  db.execute('PRAGMA busy_timeout = 5000;');
}

QueryExecutor _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'open_iptv.db'));
    return NativeDatabase.createInBackground(file, setup: _dbSetup);
  });
}
