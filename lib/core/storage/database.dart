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
  BoolColumn get hasCatchup => boolean().withDefault(const Constant(false))();
  IntColumn get catchupDays => integer().withDefault(const Constant(0))();
  TextColumn get streamId => text().nullable()();

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
  BoolColumn get isAdmin =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Per-profile watch progress, decoupled from the shared content catalog
/// (Movies/Episodes/Channels) so each profile tracks its own resume position,
/// completion state, and recently-watched history independently.
@DataClassName('WatchProgressRow')
class WatchProgress extends Table {
  TextColumn get profileId => text()();
  TextColumn get contentId => text()();
  TextColumn get contentType => text()(); // 'movie' | 'episode' | 'channel'
  IntColumn get watchedDurationSeconds => integer().nullable()();
  IntColumn get totalDurationSeconds => integer().nullable()();
  DateTimeColumn get lastWatchedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {profileId, contentId, contentType};
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
  WatchProgress,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 8;

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
          if (from < 5) {
            final tableInfo =
                await customSelect('PRAGMA table_info(profiles)').get();
            final hasCol = tableInfo
                .any((r) => r.data['name'] == 'is_admin');
            if (!hasCol) {
              await m.addColumn(profiles, profiles.isAdmin);
            }
          }
          if (from < 6) {
            final tables = await customSelect(
                    "SELECT name FROM sqlite_master WHERE type='table' AND name='watch_progress'")
                .get();
            if (tables.isEmpty) {
              await m.createTable(watchProgress);
              await customStatement(
                'CREATE INDEX IF NOT EXISTS idx_watch_progress_profile '
                'ON watch_progress (profile_id, content_type)',
              );
            }
            // Pre-existing watch/resume data predates per-profile tracking and
            // has no profile to attribute it to — it's dropped, not migrated.
            // Content catalog rows (title, poster, etc.) are unaffected.
          }
          if (from < 7) {
            // upsertProgrammes() never had a working conflict target, so every
            // EPG refresh re-inserted every programme as a new row instead of
            // overwriting it — dedupe what's already accumulated before the
            // new unique index (which requires the data to already be clean).
            await customStatement('''
              DELETE FROM programmes
              WHERE id NOT IN (
                SELECT MIN(id) FROM programmes GROUP BY channel_id, start
              )
            ''');
            await customStatement(
              'CREATE UNIQUE INDEX IF NOT EXISTS idx_programmes_unique '
              'ON programmes (channel_id, start)',
            );
          }
          if (from < 8) {
            final tableInfo =
                await customSelect('PRAGMA table_info(channels)').get();
            final columnNames =
                tableInfo.map((r) => r.data['name'] as String).toSet();
            if (!columnNames.contains('has_catchup')) {
              await m.addColumn(channels, channels.hasCatchup);
            }
            if (!columnNames.contains('catchup_days')) {
              await m.addColumn(channels, channels.catchupDays);
            }
            if (!columnNames.contains('stream_id')) {
              await m.addColumn(channels, channels.streamId);
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
    // programmes.(channel_id, start): unique — this is the conflict target
    // upsertProgrammes() writes against, so a repeat EPG refresh overwrites
    // an existing programme instead of inserting a duplicate row.
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_programmes_unique '
      'ON programmes (channel_id, start)',
    );
    // episodes.series_id: used in getEpisodesForSeries
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_episodes_series_id ON episodes (series_id)',
    );
    // watch_progress.(profile_id, content_type): used by every profile-scoped
    // progress lookup and the continue-watching/recently-watched queries.
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_watch_progress_profile '
      'ON watch_progress (profile_id, content_type)',
    );
  }

  // ---------------------------------------------------------------------------
  // Watch progress helpers — merge per-profile progress onto catalog models.
  // ---------------------------------------------------------------------------

  // Filters by (profileId, contentType) only, not by id list — a catalog can
  // have thousands of rows, which would blow past SQLite's bound-parameter
  // limit if we did `contentId.isIn(ids)`. A single profile's watch history
  // is always small, so fetching it unfiltered and matching in Dart is both
  // safe and cheap.
  Future<Map<String, WatchProgressRow>> _progressMap(
      String? profileId, String contentType, Iterable<String> ids) async {
    if (profileId == null) return {};
    final idSet = ids.toSet();
    if (idSet.isEmpty) return {};
    final rows = await (select(watchProgress)
          ..where((w) =>
              w.profileId.equals(profileId) & w.contentType.equals(contentType)))
        .get();
    return {
      for (final r in rows)
        if (idSet.contains(r.contentId)) r.contentId: r,
    };
  }

  model.Movie _applyMovieProgress(model.Movie movie, WatchProgressRow? p) {
    if (p == null) return movie;
    return movie.copyWith(
      watchedDuration: p.watchedDurationSeconds != null
          ? Duration(seconds: p.watchedDurationSeconds!)
          : null,
      totalDuration: p.totalDurationSeconds != null
          ? Duration(seconds: p.totalDurationSeconds!)
          : null,
    );
  }

  model.Episode _applyEpisodeProgress(model.Episode episode, WatchProgressRow? p) {
    if (p == null) return episode;
    return episode.copyWith(
      watchedDuration: p.watchedDurationSeconds != null
          ? Duration(seconds: p.watchedDurationSeconds!)
          : null,
      totalDuration: p.totalDurationSeconds != null
          ? Duration(seconds: p.totalDurationSeconds!)
          : null,
    );
  }

  model.Channel _applyChannelProgress(model.Channel channel, WatchProgressRow? p) {
    if (p == null) return channel;
    return channel.copyWith(lastWatchedAt: p.lastWatchedAt);
  }

  Future<List<model.Movie>> _withMovieProgress(
      List<model.Movie> items, String? profileId) async {
    final progress =
        await _progressMap(profileId, 'movie', items.map((m) => m.id));
    if (progress.isEmpty) return items;
    return items.map((m) => _applyMovieProgress(m, progress[m.id])).toList();
  }

  Future<List<model.Episode>> _withEpisodeProgress(
      List<model.Episode> items, String? profileId) async {
    final progress =
        await _progressMap(profileId, 'episode', items.map((e) => e.id));
    if (progress.isEmpty) return items;
    return items.map((e) => _applyEpisodeProgress(e, progress[e.id])).toList();
  }

  Future<List<model.Channel>> _withChannelProgress(
      List<model.Channel> items, String? profileId) async {
    final progress =
        await _progressMap(profileId, 'channel', items.map((c) => c.id));
    if (progress.isEmpty) return items;
    return items.map((c) => _applyChannelProgress(c, progress[c.id])).toList();
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

  Future<List<model.Channel>> getChannelsForSource(String sourceId,
      {String? profileId}) async {
    final rows = await (select(channels)
          ..where((t) => t.sourceId.equals(sourceId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
    return _withChannelProgress(rows.map(_channelFromRow).toList(), profileId);
  }

  Stream<List<model.Channel>> watchChannelsForSource(String sourceId,
      {String? profileId}) {
    return (select(channels)
          ..where((t) => t.sourceId.equals(sourceId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch()
        .asyncMap((rows) =>
            _withChannelProgress(rows.map(_channelFromRow).toList(), profileId));
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

  Future<List<model.Channel>> getAllChannels({String? profileId}) async {
    final rows = await select(channels).get();
    return _withChannelProgress(rows.map(_channelFromRow).toList(), profileId);
  }

  Stream<List<model.Channel>> watchAllChannels({String? profileId}) {
    return select(channels).watch().asyncMap(
        (rows) => _withChannelProgress(rows.map(_channelFromRow).toList(), profileId));
  }

  Future<model.Channel?> getChannelById(String id) async {
    final row =
        await (select(channels)..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _channelFromRow(row);
  }

  // ---------------------------------------------------------------------------
  // Programme DAOs
  // ---------------------------------------------------------------------------

  Future<void> upsertProgrammes(List<model.Programme> programmes) async {
    final companions = programmes.map(_programmeToCompanion).toList();
    for (var i = 0; i < companions.length; i += 500) {
      final chunk = companions.sublist(i, (i + 500).clamp(0, companions.length));
      await batch((b) {
        // Conflict target must be the (channel_id, start) unique index, not
        // the meaningless autoincrement id (which is never set here) — that
        // default target is why every refresh re-inserted every programme as
        // a brand-new row instead of overwriting the existing one.
        for (final c in chunk) {
          b.insert(
            this.programmes,
            c,
            onConflict: DoUpdate(
              (_) => c,
              target: [this.programmes.channelId, this.programmes.start],
            ),
          );
        }
      });
    }
  }

  /// Remaps programme channelId values from XMLTV IDs (e.g. 'BBC1.uk') to the
  /// app's internal channel IDs (e.g. '{sourceId}_ch_30581') by joining on
  /// channels.tvg_id. Must be called after EPG import.
  Future<void> remapProgrammeChannelIds() async {
    // OR REPLACE: if two different tvg_ids both resolve to the same internal
    // channel and happen to share a programme start time, this update would
    // otherwise violate idx_programmes_unique and abort the whole statement.
    // REPLACE keeps the row being written and drops the pre-existing one it
    // collided with — consistent with "last write wins" everywhere else here.
    await customStatement(
      'UPDATE OR REPLACE programmes '
      'SET channel_id = ('
      '  SELECT id FROM channels WHERE tvg_id = programmes.channel_id LIMIT 1'
      ') '
      'WHERE channel_id IN ('
      '  SELECT tvg_id FROM channels WHERE tvg_id IS NOT NULL'
      ')',
    );
  }

  /// Channels without catch-up keep only a short grace window (so "now" EPG
  /// lookups have a little slack); catch-up-enabled channels keep their own
  /// provider-advertised [Channel.catchupDays] of history instead, so the
  /// guide can be browsed back far enough to actually use it.
  Future<void> deleteOldProgrammes() async {
    final defaultCutoff = DateTime.now().subtract(const Duration(hours: 1));

    final catchupChannels = await (select(channels)
          ..where((t) => t.catchupDays.isBiggerThanValue(0)))
        .get();

    if (catchupChannels.isEmpty) {
      await (delete(programmes)
            ..where((t) => t.end.isSmallerThanValue(defaultCutoff)))
          .go();
      return;
    }

    final catchupIds = catchupChannels.map((c) => c.id).toList();
    await (delete(programmes)
          ..where((t) =>
              t.end.isSmallerThanValue(defaultCutoff) &
              t.channelId.isNotIn(catchupIds)))
        .go();

    for (final c in catchupChannels) {
      final cutoff = DateTime.now().subtract(Duration(days: c.catchupDays));
      await (delete(programmes)
            ..where((t) =>
                t.channelId.equals(c.id) & t.end.isSmallerThanValue(cutoff)))
          .go();
    }
  }

  /// The largest [Channel.catchupDays] among a source's channels — used to
  /// size how far back the EPG parser should keep history for that source's
  /// next refresh, so catch-up-enabled channels' guide data survives long
  /// enough for [deleteOldProgrammes] to actually have something to keep.
  Future<int> getMaxCatchupDaysForSource(String sourceId) async {
    final query = selectOnly(channels)
      ..addColumns([channels.catchupDays.max()])
      ..where(channels.sourceId.equals(sourceId));
    final row = await query.getSingleOrNull();
    return row?.read(channels.catchupDays.max()) ?? 0;
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

  Future<List<model.Movie>> getMoviesForSource(String sourceId,
      {String? profileId}) async {
    final rows = await (select(movies)
          ..where((t) => t.sourceId.equals(sourceId))
          ..orderBy([(t) => OrderingTerm.asc(t.title)]))
        .get();
    return _withMovieProgress(rows.map(_movieFromRow).toList(), profileId);
  }

  Future<List<model.Movie>> getAllMovies({String? profileId}) async {
    final rows = await select(movies).get();
    return _withMovieProgress(rows.map(_movieFromRow).toList(), profileId);
  }

  Stream<List<model.Movie>> watchAllMovies({String? profileId}) {
    return select(movies).watch().asyncMap(
        (rows) => _withMovieProgress(rows.map(_movieFromRow).toList(), profileId));
  }

  Stream<List<model.Movie>> watchMoviesForSource(String sourceId,
      {String? profileId}) {
    return (select(movies)
          ..where((t) => t.sourceId.equals(sourceId))
          ..orderBy([(t) => OrderingTerm.asc(t.title)]))
        .watch()
        .asyncMap((rows) =>
            _withMovieProgress(rows.map(_movieFromRow).toList(), profileId));
  }

  Stream<model.Movie?> watchMovieById(String id, {String? profileId}) {
    return (select(movies)..where((t) => t.id.equals(id)))
        .watchSingleOrNull()
        .asyncMap((row) async {
      if (row == null) return null;
      final merged =
          await _withMovieProgress([_movieFromRow(row)], profileId);
      return merged.first;
    });
  }

  /// Movies with in-progress playback for [profileId], most recently watched first.
  Stream<List<model.Movie>> watchMoviesInProgress(String profileId) {
    return (select(watchProgress)
          ..where((w) =>
              w.profileId.equals(profileId) &
              w.contentType.equals('movie') &
              w.watchedDurationSeconds.isBiggerThanValue(0))
          ..orderBy([(w) => OrderingTerm.desc(w.lastWatchedAt)]))
        .watch()
        .asyncMap((progressRows) async {
      final ids = progressRows.map((p) => p.contentId).toList();
      if (ids.isEmpty) return <model.Movie>[];
      final movieRows =
          await (select(movies)..where((t) => t.id.isIn(ids))).get();
      final byId = {for (final r in movieRows) r.id: r};
      final progressById = {for (final p in progressRows) p.contentId: p};
      return ids
          .map((id) => byId[id])
          .whereType<MovieRow>()
          .map((row) =>
              _applyMovieProgress(_movieFromRow(row), progressById[row.id]))
          .where((m) => m.isInProgress)
          .toList();
    });
  }

  Future<void> clearMovieProgress(String profileId, String id) async {
    await (delete(watchProgress)
          ..where((w) =>
              w.profileId.equals(profileId) &
              w.contentType.equals('movie') &
              w.contentId.equals(id)))
        .go();
  }

  // ---------------------------------------------------------------------------
  // Channel recently-watched
  // ---------------------------------------------------------------------------

  Future<void> updateChannelLastWatched(String profileId, String id) async {
    await into(watchProgress).insertOnConflictUpdate(
      WatchProgressCompanion.insert(
        profileId: profileId,
        contentId: id,
        contentType: 'channel',
        lastWatchedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> clearChannelLastWatched(String profileId, String id) async {
    await (delete(watchProgress)
          ..where((w) =>
              w.profileId.equals(profileId) &
              w.contentType.equals('channel') &
              w.contentId.equals(id)))
        .go();
  }

  Stream<List<model.Channel>> watchRecentChannels(String profileId,
      {int limit = 20}) {
    return (select(watchProgress)
          ..where((w) =>
              w.profileId.equals(profileId) &
              w.contentType.equals('channel') &
              w.lastWatchedAt.isNotNull())
          ..orderBy([(w) => OrderingTerm.desc(w.lastWatchedAt)])
          ..limit(limit))
        .watch()
        .asyncMap((progressRows) async {
      final ids = progressRows.map((p) => p.contentId).toList();
      if (ids.isEmpty) return <model.Channel>[];
      final channelRows =
          await (select(channels)..where((t) => t.id.isIn(ids))).get();
      final byId = {for (final r in channelRows) r.id: r};
      return ids
          .map((id) => byId[id])
          .whereType<ChannelRow>()
          .map(_channelFromRow)
          .toList();
    });
  }

  // ---------------------------------------------------------------------------
  // Episode continue-watching stream
  // ---------------------------------------------------------------------------

  Stream<List<model.Episode>> watchEpisodesInProgress(String profileId) {
    return (select(watchProgress)
          ..where((w) =>
              w.profileId.equals(profileId) &
              w.contentType.equals('episode') &
              w.watchedDurationSeconds.isBiggerThanValue(0))
          ..orderBy([(w) => OrderingTerm.desc(w.lastWatchedAt)]))
        .watch()
        .asyncMap((progressRows) async {
      final ids = progressRows.map((p) => p.contentId).toList();
      if (ids.isEmpty) return <model.Episode>[];
      final episodeRows =
          await (select(episodes)..where((t) => t.id.isIn(ids))).get();
      final byId = {for (final r in episodeRows) r.id: r};
      final progressById = {for (final p in progressRows) p.contentId: p};
      return ids
          .map((id) => byId[id])
          .whereType<EpisodeRow>()
          .map((row) => _applyEpisodeProgress(
              _episodeFromRow(row), progressById[row.id]))
          .where((e) => e.isInProgress)
          .toList();
    });
  }

  Future<void> clearEpisodeProgress(String profileId, String id) async {
    await (delete(watchProgress)
          ..where((w) =>
              w.profileId.equals(profileId) &
              w.contentType.equals('episode') &
              w.contentId.equals(id)))
        .go();
  }

  Future<void> upsertMovies(List<model.Movie> movieList) async {
    final companions = movieList.map(_movieToCompanion).toList();
    for (var i = 0; i < companions.length; i += 500) {
      final chunk = companions.sublist(i, (i + 500).clamp(0, companions.length));
      await batch((b) => b.insertAllOnConflictUpdate(movies, chunk));
    }
  }

  Future<void> updateMovieProgress(
    String profileId,
    String id,
    Duration watched,
    Duration total,
  ) async {
    await into(watchProgress).insertOnConflictUpdate(
      WatchProgressCompanion.insert(
        profileId: profileId,
        contentId: id,
        contentType: 'movie',
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
    final rows = await select(seriesEntries).get();
    return rows.map(_seriesFromRow).toList();
  }

  Stream<List<model.Series>> watchAllSeries() {
    return select(seriesEntries)
        .watch()
        .map((rows) => rows.map(_seriesFromRow).toList());
  }

  Stream<List<model.Series>> watchSeriesForSource(String sourceId) {
    return (select(seriesEntries)
          ..where((t) => t.sourceId.equals(sourceId))
          ..orderBy([(t) => OrderingTerm.asc(t.title)]))
        .watch()
        .map((rows) => rows.map(_seriesFromRow).toList());
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

  Future<List<model.Episode>> getEpisodesForSeries(String seriesId,
      {String? profileId}) async {
    final rows = await (select(episodes)
          ..where((t) => t.seriesId.equals(seriesId))
          ..orderBy([
            (t) => OrderingTerm.asc(t.season),
            (t) => OrderingTerm.asc(t.episode),
          ]))
        .get();
    return _withEpisodeProgress(rows.map(_episodeFromRow).toList(), profileId);
  }

  Future<model.Episode?> getEpisodeById(String id) async {
    final row =
        await (select(episodes)..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _episodeFromRow(row);
  }

  Stream<List<model.Episode>> watchEpisodesForSeries(String seriesId,
      {String? profileId}) {
    return (select(episodes)
          ..where((t) => t.seriesId.equals(seriesId))
          ..orderBy([
            (t) => OrderingTerm.asc(t.season),
            (t) => OrderingTerm.asc(t.episode),
          ]))
        .watch()
        .asyncMap((rows) =>
            _withEpisodeProgress(rows.map(_episodeFromRow).toList(), profileId));
  }

  Future<void> upsertEpisodes(List<model.Episode> episodeList) async {
    final companions = episodeList.map(_episodeToCompanion).toList();
    for (var i = 0; i < companions.length; i += 500) {
      final chunk = companions.sublist(i, (i + 500).clamp(0, companions.length));
      await batch((b) => b.insertAllOnConflictUpdate(episodes, chunk));
    }
  }

  Future<void> updateEpisodeProgress(
    String profileId,
    String id,
    Duration watched,
    Duration total,
  ) async {
    await into(watchProgress).insertOnConflictUpdate(
      WatchProgressCompanion.insert(
        profileId: profileId,
        contentId: id,
        contentType: 'episode',
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
        hasCatchup: row.hasCatchup,
        catchupDays: row.catchupDays,
        streamId: row.streamId,
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
        isAdmin: row.isAdmin,
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
        hasCatchup: Value(c.hasCatchup),
        catchupDays: Value(c.catchupDays),
        streamId: Value(c.streamId),
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
        isAdmin: Value(p.isAdmin),
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
