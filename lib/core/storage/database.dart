import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/extensions/native.dart';
import 'package:flutter/foundation.dart';
import 'package:open_iptv/core/storage/db_encryption.dart';
import 'package:sqlite3/sqlite3.dart' show Database;
import 'package:open_iptv/core/models/channel.dart' as model;
import 'package:open_iptv/core/models/episode.dart' as model;
import 'package:open_iptv/core/models/movie.dart' as model;
import 'package:open_iptv/core/models/profile.dart' as model;
import 'package:open_iptv/core/models/programme.dart' as model;
import 'package:open_iptv/core/models/series.dart' as model;
import 'package:open_iptv/core/models/source.dart' as model;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';

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
  TextColumn get favoriteChannelIds =>
      text().withDefault(const Constant('[]'))();
  TextColumn get favoriteMovieIds => text().withDefault(const Constant('[]'))();
  TextColumn get favoriteSeriesIds =>
      text().withDefault(const Constant('[]'))();
  TextColumn get defaultCategory => text().withDefault(const Constant('All'))();
  TextColumn get channelSortOrder =>
      text().withDefault(const Constant('provider'))();
  TextColumn get defaultSubtitleLang =>
      text().withDefault(const Constant(''))();
  TextColumn get defaultAudioLang => text().withDefault(const Constant(''))();
  TextColumn get customChannelOrder =>
      text().withDefault(const Constant('{}'))();
  TextColumn get epgOverrides => text().withDefault(const Constant('{}'))();
  TextColumn get hiddenCategories => text().withDefault(const Constant('[]'))();
  BoolColumn get isKidsProfile =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get isAdmin => boolean().withDefault(const Constant(false))();
  TextColumn get accentColor => text().withDefault(const Constant('0A84FF'))();
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
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  /// For the background auto-refresh isolate: opens the encrypted database
  /// but never converts an unencrypted one (the app does that on launch).
  AppDatabase.background() : super(_openConnection(migrate: false));

  @override
  int get schemaVersion => 13;

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
            final hasCol =
                tableInfo.any((r) => r.data['name'] == 'last_watched_at');
            if (!hasCol) {
              await m.addColumn(channels, channels.lastWatchedAt);
            }
          }
          if (from < 4) {
            final tableInfo =
                await customSelect('PRAGMA table_info(profiles)').get();
            final hasCol =
                tableInfo.any((r) => r.data['name'] == 'is_kids_profile');
            if (!hasCol) {
              await m.addColumn(profiles, profiles.isKidsProfile);
            }
          }
          if (from < 5) {
            final tableInfo =
                await customSelect('PRAGMA table_info(profiles)').get();
            final hasCol = tableInfo.any((r) => r.data['name'] == 'is_admin');
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
          if (from < 9) await _createSearchIndexes();
          if (from < 10) await _createSourceIndexes();
          if (from < 11) await _migrateM3uContentIds();
          if (from < 12) {
            final tableInfo =
                await customSelect('PRAGMA table_info(profiles)').get();
            final hasCol =
                tableInfo.any((r) => r.data['name'] == 'accent_color');
            if (!hasCol) {
              await m.addColumn(profiles, profiles.accentColor);
            }
          }
          if (from < 13) await _createCoveringIndexes();
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
          await customStatement('PRAGMA journal_mode = WAL');
        },
      );

  /// After a big write (a playlist swap, a guide import): hands freed space
  /// back to the device and empties the write-ahead log. Never throws.
  Future<void> compact() async {
    try {
      await customStatement('PRAGMA incremental_vacuum');
      await customSelect('PRAGMA wal_checkpoint(TRUNCATE)').get();
    } catch (e) {
      debugPrint('[OTV-storage] compact failed: $e');
    }
  }

  /// One-time clean-up for databases made before [compact] existed: they
  /// can't hand space back until rebuilt once (VACUUM). The rebuild needs
  /// room for a copy of the data actually in use (plus its log), not of
  /// the whole file. On a device too full even for that, the TV guide —
  /// the biggest table, and downloaded again on the next refresh — is
  /// cleared first. Returns true when it did that, so the caller can fetch
  /// the guide again. Never throws.
  Future<bool> compactIfBloated({required int freeDiskBytes}) async {
    try {
      Future<int> one(String sql) async => int.parse(
          '${(await customSelect(sql).getSingle()).data.values.first}');
      if (await one('PRAGMA auto_vacuum') == 2) {
        await compact();
        return false;
      }
      final pageSize = await one('PRAGMA page_size');
      Future<int> inUse() async =>
          (await one('PRAGMA page_count') -
              await one('PRAGMA freelist_count')) *
          pageSize;
      final size = await one('PRAGMA page_count') * pageSize;
      bool roomFor(int bytes) => freeDiskBytes > bytes * 2.5 + (32 << 20);
      var guideCleared = false;
      if (!roomFor(await inUse())) {
        debugPrint('[OTV-storage] not enough room to tidy up: clearing the '
            'TV guide first (it downloads again)');
        await customStatement('DELETE FROM programmes');
        guideCleared = true;
        if (!roomFor(await inUse())) {
          debugPrint('[OTV-storage] still not enough room — skipped');
          return guideCleared;
        }
      }
      debugPrint('[OTV-storage] rebuilding the database once '
          '(${size >> 20} MB, ${(await inUse()) >> 20} MB in use)');
      final sw = Stopwatch()..start();
      await customStatement('VACUUM');
      await customSelect('PRAGMA wal_checkpoint(TRUNCATE)').get();
      debugPrint('[OTV-storage] rebuilt in ${sw.elapsedMilliseconds} ms: '
          '${(await one('PRAGMA page_count') * pageSize) >> 20} MB');
      return guideCleared;
    } catch (e) {
      debugPrint('[OTV-storage] rebuild failed: $e');
      return false;
    }
  }

  /// Pages used vs free and the big tables' row counts, for
  /// `adb logcat | grep OTV-storage`.
  Future<void> logStorageStats() async {
    try {
      Future<int> one(String sql) async => int.parse(
          '${(await customSelect(sql).getSingle()).data.values.first}');
      final pageSize = await one('PRAGMA page_size');
      final pages = await one('PRAGMA page_count');
      final free = await one('PRAGMA freelist_count');
      final counts = <String>[];
      for (final t in [
        'channels',
        'movies',
        'series_entries',
        'episodes',
        'programmes',
      ]) {
        counts.add('$t ${await one('SELECT COUNT(*) FROM $t')}');
      }
      debugPrint('[OTV-storage] db: '
          '${(pages * pageSize / (1 << 20)).toStringAsFixed(1)} MB, '
          'free pages ${(free * pageSize / (1 << 20)).toStringAsFixed(1)} MB; '
          '${counts.join(', ')}');
      // Rows per playlist, by nickname; "(gone)" = rows whose playlist no
      // longer exists.
      for (final t in ['channels', 'movies', 'series_entries']) {
        final rows = await customSelect(
          "SELECT COALESCE(s.nickname, '(gone)') AS n, COUNT(*) AS c "
          'FROM $t x LEFT JOIN sources s ON s.id = x.source_id '
          'GROUP BY x.source_id',
        ).get();
        final parts = rows.map((r) => '${r.data['n']} ${r.data['c']}');
        debugPrint('[OTV-storage] $t by playlist: ${parts.join(', ')}');
      }
    } catch (e) {
      debugPrint('[OTV-storage] db stats failed: $e');
    }
  }

  Future<void> _createIndexes() async {
    // channels.tvg_id: guide lookups by XMLTV id.
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
    await _createSearchIndexes();
    await _createSourceIndexes();
    await _createCoveringIndexes();
  }

  // Covering indexes for hot read paths (#126/#128): include the columns that
  // queries read alongside the key columns so SQLite can satisfy them from the
  // index alone without a row lookup. Biggest wins on programmes (TV guide)
  // and watch_progress (playback seeking).
  Future<void> _createCoveringIndexes() async {
    // watch_progress: profile-scoped progress lookups read content_id + position.
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_watch_progress_covering '
      'ON watch_progress (profile_id, content_type, content_id, watched_duration_seconds)',
    );
    // programmes: guide queries read title/description alongside time range.
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_programmes_covering '
      'ON programmes (channel_id, start, end, title)',
    );
    // channels: list view reads name/logo/number alongside source.
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_channels_covering '
      'ON channels (source_id, sort_order, name, logo_url)',
    );
  }
  // catalog table. Without these, every delete scanned the whole table:
  // ~10 s on a TV for a 2-title playlist, holding the write lock throughout.
  Future<void> _createSourceIndexes() async {
    for (final table in ['channels', 'movies', 'series_entries', 'episodes']) {
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_${table}_source ON $table (source_id)',
      );
    }
  }

  /// Schema 11 migration: re-key M3U-sourced content IDs from the unstable
  /// `String.hashCode` to a deterministic SHA-256, preserving watch history
  /// and favorites by updating every cross-table reference.
  ///
  /// Matches `M3uParser._generateId` — if that method changes, update here.
  String _sha256Id(String sourceId, String key) {
    final hash = sha256.convert(utf8.encode('$sourceId:$key')).toString();
    return '${sourceId}_${hash.substring(0, 16)}';
  }

  Future<void> _migrateM3uContentIds() async {
    final m3uSources = await customSelect(
      "SELECT id FROM sources WHERE type = 'm3u'",
    ).get();

    for (final src in m3uSources) {
      final sourceId = src.data['id'] as String;

      await transaction(() async {
        // --- Channels: ID = sha256(sourceId:streamUrl) ---
        final channelMap = await _rekeyTable(
          'channels',
          'stream_url',
          sourceId,
        );
        await _applyIdMap('channels', 'id', channelMap);
        await _applyIdMap('programmes', 'channel_id', channelMap);

        // --- Movies: ID = sha256(sourceId:streamUrl) ---
        final movieMap = await _rekeyTable(
          'movies',
          'stream_url',
          sourceId,
        );
        await _applyIdMap('movies', 'id', movieMap);

        // --- Series: ID = sha256(sourceId:title) ---
        final seriesMap = await _rekeyTable(
          'series_entries',
          'title',
          sourceId,
        );
        await _applyIdMap('series_entries', 'id', seriesMap);
        // Episodes reference the series they belong to.
        await _applyIdMap('episodes', 'series_id', seriesMap);

        // --- Episodes: ID = sha256(sourceId:streamUrl) ---
        final episodeMap = await _rekeyTable(
          'episodes',
          'stream_url',
          sourceId,
        );
        await _applyIdMap('episodes', 'id', episodeMap);

        // --- Watch progress: content_id references all content types ---
        final allMaps = {
          ...channelMap,
          ...movieMap,
          ...seriesMap,
          ...episodeMap
        };
        for (final entry in allMaps.entries) {
          await customStatement(
            'UPDATE watch_progress SET content_id = ? WHERE content_id = ?',
            [entry.value, entry.key],
          );
        }

        // --- Profile favorites: JSON arrays storing content IDs ---
        final profiles = await customSelect(
          'SELECT id, favorite_channel_ids, favorite_movie_ids, '
          'favorite_series_ids FROM profiles',
        ).get();

        for (final row in profiles) {
          final profileId = row.data['id'] as String;
          final favChannels = _remapJsonList(
            row.data['favorite_channel_ids'] as String,
            channelMap,
          );
          final favMovies = _remapJsonList(
            row.data['favorite_movie_ids'] as String,
            movieMap,
          );
          final favSeries = _remapJsonList(
            row.data['favorite_series_ids'] as String,
            seriesMap,
          );
          await customStatement(
            'UPDATE profiles SET favorite_channel_ids = ?, '
            'favorite_movie_ids = ?, favorite_series_ids = ? WHERE id = ?',
            [favChannels, favMovies, favSeries, profileId],
          );
        }
      });
    }
  }

  /// Reads all rows from [table] for [sourceId], computes new SHA-256-based
  /// IDs from [keyColumn], and returns a map of {oldId: newId} for rows that
  /// actually changed.
  Future<Map<String, String>> _rekeyTable(
    String table,
    String keyColumn,
    String sourceId,
  ) async {
    final rows = await customSelect(
      'SELECT id, $keyColumn FROM $table WHERE source_id = ?',
      variables: [Variable<String>(sourceId)],
    ).get();

    final map = <String, String>{};
    for (final row in rows) {
      final oldId = row.data['id'] as String;
      final key = row.data[keyColumn] as String;
      final newId = _sha256Id(sourceId, key);
      if (newId != oldId) {
        map[oldId] = newId;
      }
    }
    return map;
  }

  /// Applies an ID remapping to a column that references content IDs.
  Future<void> _applyIdMap(
    String table,
    String column,
    Map<String, String> idMap,
  ) async {
    for (final entry in idMap.entries) {
      await customStatement(
        'UPDATE $table SET $column = ? WHERE $column = ?',
        [entry.value, entry.key],
      );
    }
  }

  /// Re-maps content IDs inside a JSON-encoded string array stored in a
  /// profile's favorites column.
  String _remapJsonList(String json, Map<String, String> idMap) {
    if (idMap.isEmpty) return json;
    final list = jsonDecode(json) as List<dynamic>;
    final remapped = list.map((e) {
      final id = e as String;
      return idMap[id] ?? id;
    }).toList();
    return jsonEncode(remapped);
  }

  // Search scans these narrow indexes instead of whole rows (#38): reading
  // every movie's description or every programme off an encrypted database
  // took seconds per query on a TV. A "contains" can't seek an index, but
  // a covering index is far less to read than the table.
  Future<void> _createSearchIndexes() async {
    // Currently-airing programme search: range on start, rest covered.
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_programmes_airing '
      'ON programmes (start, "end", title, channel_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_channels_name ON channels (name)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_movies_title ON movies (title)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_series_title ON series_entries (title)',
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
              w.profileId.equals(profileId) &
              w.contentType.equals(contentType)))
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

  model.Episode _applyEpisodeProgress(
      model.Episode episode, WatchProgressRow? p) {
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

  model.Channel _applyChannelProgress(
      model.Channel channel, WatchProgressRow? p) {
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

  /// Writes [items] in 500-row chunks, one batch per chunk.
  Future<void> _batchInChunks<T>(
    List<T> items,
    void Function(Batch b, List<T> chunk) fill,
  ) async {
    for (var i = 0; i < items.length; i += 500) {
      final chunk = items.sublist(i, (i + 500).clamp(0, items.length));
      await batch((b) => fill(b, chunk));
    }
  }

  Future<void> _clearProgress(
      String profileId, String contentType, String id) async {
    await (delete(watchProgress)
          ..where((w) =>
              w.profileId.equals(profileId) &
              w.contentType.equals(contentType) &
              w.contentId.equals(id)))
        .go();
  }

  // ---------------------------------------------------------------------------
  // Source DAOs
  // ---------------------------------------------------------------------------

  Future<List<model.Source>> getAllSources() async {
    final rows = await select(sources).get();
    return rows.map(_sourceFromRow).toList();
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

  /// The guide rows of [sourceId]'s channels (their ids start with
  /// "<sourceId>_ch_"). Without this a removed playlist's guide stayed until
  /// it had aired — days of catch-up history for some providers.
  Future<void> deleteProgrammesForSource(String sourceId) async {
    final prefix = '${sourceId}_ch_';
    await customStatement(
      'DELETE FROM programmes WHERE substr(channel_id, 1, ?) = ?',
      [prefix.length, prefix],
    );
  }

  Future<void> updateSourceRefreshTime(String id, DateTime time) async {
    await (update(sources)..where((t) => t.id.equals(id))).write(
      SourcesCompanion(lastRefreshed: Value(time)),
    );
  }

  // ---------------------------------------------------------------------------
  // Channel DAOs
  // ---------------------------------------------------------------------------

  Stream<List<model.Channel>> watchChannelsForSource(String sourceId,
      {String? profileId}) {
    return (select(channels)
          ..where((t) => t.sourceId.equals(sourceId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch()
        .asyncMap((rows) => _withChannelProgress(
            rows.map(_channelFromRow).toList(), profileId));
  }

  Future<void> upsertChannels(List<model.Channel> channelList) async {
    await _batchInChunks(channelList.map(_channelToCompanion).toList(),
        (b, chunk) => b.insertAllOnConflictUpdate(channels, chunk));
  }

  /// A few stream links from [sourceId] (every playlist when null) for the
  /// speed test (Power User Tools): movies first — a file downloads at full
  /// speed — then live channels. Bounded, index-backed queries; never the
  /// whole catalog.
  Future<List<({bool movie, String url})>> speedTestCandidates(String? sourceId,
      {int each = 3}) async {
    final m = selectOnly(movies)..addColumns([movies.streamUrl]);
    final c = selectOnly(channels)..addColumns([channels.streamUrl]);
    if (sourceId != null) {
      m.where(movies.sourceId.equals(sourceId));
      c.where(channels.sourceId.equals(sourceId));
    }
    m.limit(each);
    c.limit(each);
    return [
      for (final r in await m.get())
        (movie: true, url: r.read(movies.streamUrl)!),
      for (final r in await c.get())
        (movie: false, url: r.read(channels.streamUrl)!),
    ];
  }

  Future<void> deleteChannelsForSource(String sourceId) async {
    await (delete(channels)..where((t) => t.sourceId.equals(sourceId))).go();
  }

  /// Swaps a playlist's channels for a freshly downloaded list in one
  /// transaction, so the list is never seen empty or half-saved. The
  /// `replace*ForSource` methods below do the same for the other tables.
  Future<void> replaceChannelsForSource(
      String sourceId, List<model.Channel> channelList) {
    return transaction(() async {
      await deleteChannelsForSource(sourceId);
      await upsertChannels(channelList);
    });
  }

  Future<List<model.Channel>> getAllChannels({String? profileId}) async {
    final rows = await select(channels).get();
    return _withChannelProgress(rows.map(_channelFromRow).toList(), profileId);
  }

  /// Search, run inside the database isolate so only the matches cross over
  /// — loading the whole catalog to filter it in Dart froze the UI for
  /// ~10 s on a TV with large playlists (#38). Matching is a strict,
  /// case-insensitive "contains" (see [_textContains]); each table is
  /// scanned through its small name/title index, not its full rows.
  ///
  /// Channels match by name, or — ranked after those — by what's airing on
  /// them: [airingChannelIds] comes from a capped programme search.
  Future<
      ({
        List<model.Channel> channels,
        List<model.Movie> movies,
        List<model.Series> series,
      })> searchCatalog(
    String query, {
    String? sourceId,
    Set<String> airingChannelIds = const {},
  }) async {
    Expression<bool> inSource(GeneratedColumn<String> column) =>
        sourceId == null ? const Constant(true) : column.equals(sourceId);
    // Row ids from a scan of the (narrow) title index only; the full rows
    // — descriptions and all — are read just for the matches.
    Expression<bool> matching(
      TableInfo<Table, dynamic> table,
      GeneratedColumn<String> title,
    ) =>
        table.rowId.isInQuery(selectOnly(table)
          ..addColumns([table.rowId])
          ..where(_textContains(title, query)));

    final (byName, byAiring, movieRows, seriesRows) = await (
      (select(channels)
            ..where((t) => matching(channels, t.name) & inSource(t.sourceId)))
          .get(),
      airingChannelIds.isEmpty
          ? Future.value(<ChannelRow>[])
          : (select(channels)
                ..where((t) =>
                    t.id.isIn(airingChannelIds) &
                    _textContains(t.name, query).not() &
                    inSource(t.sourceId)))
              .get(),
      (select(movies)
            ..where((t) => matching(movies, t.title) & inSource(t.sourceId)))
          .get(),
      (select(seriesEntries)
            ..where(
                (t) => matching(seriesEntries, t.title) & inSource(t.sourceId)))
          .get(),
    ).wait;
    return (
      channels: [...byName, ...byAiring].map(_channelFromRow).toList(),
      movies: movieRows.map(_movieFromRow).toList(),
      series: seriesRows.map(_seriesFromRow).toList(),
    );
  }

  /// Case-insensitive "contains", matching Dart's
  /// `text.toLowerCase().contains(query.toLowerCase())`. Plain-ASCII
  /// queries use SQLite's own LIKE (case-folds ASCII; `%`/`_` escaped) —
  /// a Dart callback per row is ~2× slower on a TV. Anything else (é, Ж…)
  /// goes through drift's Dart-side `containsCase`, since LIKE only folds
  /// ASCII.
  static Expression<bool> _textContains(Expression<String> text, String query) {
    final ascii = query.codeUnits.every((c) => c < 0x80);
    if (!ascii) return text.containsCase(query);
    final escaped =
        query.replaceAllMapped(RegExp(r'[\\%_]'), (m) => '\\${m[0]}');
    return text.like('%$escaped%', escapeChar: '\\');
  }

  Stream<List<model.Channel>> watchAllChannels({String? profileId}) {
    return select(channels).watch().asyncMap((rows) =>
        _withChannelProgress(rows.map(_channelFromRow).toList(), profileId));
  }

  Future<model.Channel?> getChannelById(String id) async {
    final row = await (select(channels)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _channelFromRow(row);
  }

  // ---------------------------------------------------------------------------
  // Programme DAOs
  // ---------------------------------------------------------------------------

  Future<void> upsertProgrammes(List<model.Programme> programmes) async {
    await _batchInChunks(programmes.map(_programmeToCompanion).toList(),
        (b, chunk) {
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

  /// XMLTV channel id (`tvg-id`) → the app's channel id, for storing a
  /// guide under the channels it belongs to. Channels of [preferSourceId]
  /// (the playlist whose guide this is) win when several playlists share
  /// an id; otherwise the first one found, as before.
  Future<Map<String, String>> channelIdsByTvgId(String preferSourceId) async {
    final rows = await (selectOnly(channels)
          ..addColumns([channels.id, channels.tvgId, channels.sourceId])
          ..where(channels.tvgId.isNotNull() & channels.tvgId.equals('').not()))
        .get();
    final map = <String, String>{};
    for (final own in [true, false]) {
      for (final r in rows) {
        if ((r.read(channels.sourceId) == preferSourceId) != own) continue;
        map.putIfAbsent(r.read(channels.tvgId)!, () => r.read(channels.id)!);
      }
    }
    return map;
  }

  /// Channels without catch-up keep only a short grace window (so "now" EPG
  /// lookups have a little slack); catch-up-enabled channels keep their own
  /// provider-advertised [Channel.catchupDays] of history instead, so the
  /// guide can be browsed back far enough to actually use it.
  Future<void> deleteOldProgrammes() async {
    final now = DateTime.now();
    final defaultCutoff = now.subtract(const Duration(hours: 1));

    // Subqueries rather than id lists: binding every catch-up channel id
    // (thousands on some Xtream providers) exceeds SQLite's bound-parameter
    // limit, and a DELETE per channel held the DB connection for ages.
    BaseSelectStatement catchupIdsWhere(Expression<bool> filter) =>
        selectOnly(channels)
          ..addColumns([channels.id])
          ..where(filter);

    // Programmes for channels that don't exist (stored under their XMLTV
    // id by versions before 0.12.1, or left by a removed playlist) are
    // never shown: drop them whatever their time.
    await (delete(programmes)
          ..where((t) => t.channelId
              .isNotInQuery(selectOnly(channels)..addColumns([channels.id]))))
        .go();

    // Non-catch-up channels keep only the last hour.
    await (delete(programmes)
          ..where((t) =>
              t.end.isSmallerThanValue(defaultCutoff) &
              t.channelId.isNotInQuery(
                  catchupIdsWhere(channels.catchupDays.isBiggerThanValue(0)))))
        .go();

    // Catch-up channels keep their advertised window — one DELETE per
    // distinct window length (usually a handful), not per channel.
    final windows = await (selectOnly(channels, distinct: true)
          ..addColumns([channels.catchupDays])
          ..where(channels.catchupDays.isBiggerThanValue(0)))
        .map((r) => r.read(channels.catchupDays)!)
        .get();
    for (final days in windows) {
      final cutoff = now.subtract(Duration(days: days));
      await (delete(programmes)
            ..where((t) =>
                t.end.isSmallerThanValue(cutoff) &
                t.channelId.isInQuery(
                    catchupIdsWhere(channels.catchupDays.equals(days)))))
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

  /// One channel's programmes overlapping [rangeStart, rangeEnd), for a row
  /// of the TV guide. Rows load on their own as they scroll into view: a
  /// whole category (or every channel) at once would read the full time
  /// window of the table. Served by idx_programmes_channel_time.
  Future<List<model.Programme>> getProgrammesForChannelInRange(
    String channelId,
    DateTime rangeStart,
    DateTime rangeEnd,
  ) async {
    final rows = await (select(programmes)
          ..where((t) =>
              t.channelId.equals(channelId) &
              t.start.isSmallerThanValue(rangeEnd) &
              t.end.isBiggerThanValue(rangeStart))
          ..orderBy([(t) => OrderingTerm.asc(t.start)]))
        .get();
    return rows.map(_programmeFromRow).toList();
  }

  Future<List<model.Programme>> searchProgrammes(String query) async {
    final escaped = query.toLowerCase().replaceAllMapped(
        RegExp(r'[\\%_]'), (m) => '\\${m[0]}');
    final q = '%$escaped%';
    final rows = await (select(programmes)
          ..where((t) => t.title.lower().like(q, escapeChar: '\\'))
          ..orderBy([(t) => OrderingTerm.asc(t.start)])
          ..limit(50))
        .get();
    return rows.map(_programmeFromRow).toList();
  }

  /// Returns programmes currently airing whose title contains [query]
  /// (see [_textContains]). Used to surface channels in search results via
  /// EPG title matching, so only channel, times and title are read — all
  /// from idx_programmes_airing, never the full rows (a full scan of a big
  /// guide took ~14 s on a TV).
  Future<List<model.Programme>> searchCurrentProgrammes(String query) async {
    final now = DateTime.now();
    final rows = await (selectOnly(programmes)
          ..addColumns([
            programmes.channelId,
            programmes.start,
            programmes.end,
            programmes.title,
          ])
          ..where(programmes.start.isSmallerOrEqualValue(now) &
              programmes.end.isBiggerThanValue(now) &
              _textContains(programmes.title, query))
          ..limit(100))
        .get();
    return [
      for (final r in rows)
        model.Programme(
          channelId: r.read(programmes.channelId)!,
          start: r.read(programmes.start)!,
          end: r.read(programmes.end)!,
          title: r.read(programmes.title)!,
        ),
    ];
  }

  // ---------------------------------------------------------------------------
  // Movie DAOs
  // ---------------------------------------------------------------------------

  Future<List<model.Movie>> getAllMovies({String? profileId}) async {
    final rows = await select(movies).get();
    return _withMovieProgress(rows.map(_movieFromRow).toList(), profileId);
  }

  Stream<List<model.Movie>> watchAllMovies({String? profileId}) {
    return select(movies).watch().asyncMap((rows) =>
        _withMovieProgress(rows.map(_movieFromRow).toList(), profileId));
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
    return _watchWithProgress(movies, () async {
      final row = await (select(movies)..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      if (row == null) return null;
      final merged = await _withMovieProgress([_movieFromRow(row)], profileId);
      return merged.first;
    });
  }

  /// Up to [limit] movies from [sourceId] whose genre text contains [genre]
  /// (callers match the split genre names exactly), excluding [excludeId] —
  /// the "More like this" row. Bounded by [limit] so it stays cheap on
  /// huge catalogs.
  Future<List<model.Movie>> getMoviesInGenre(
    String sourceId,
    String genre, {
    required String excludeId,
    int limit = 60,
    String? profileId,
  }) async {
    final escapedGenre = genre.replaceAllMapped(
        RegExp(r'[\\%_]'), (m) => '\\${m[0]}');
    final rows = await (select(movies)
          ..where((t) =>
              t.sourceId.equals(sourceId) &
              t.genre.like('%$escapedGenre%', escapeChar: '\\') &
              t.id.equals(excludeId).not())
          ..limit(limit))
        .get();
    return _withMovieProgress(rows.map(_movieFromRow).toList(), profileId);
  }

  /// Re-runs [load] now and whenever [content] or the watch-progress table
  /// changes. A plain `select(content).watch()` misses progress saves (a
  /// separate table), leaving Resume / watched markers stale until the
  /// screen is rebuilt. Only for small per-item queries: every channel
  /// start also writes watch progress, so a whole-catalog list here would
  /// re-query on every zap.
  Stream<T> _watchWithProgress<T>(
      TableInfo content, Future<T> Function() load) async* {
    yield await load();
    await for (final _ in tableUpdates(
        TableUpdateQuery.onAllTables([content, watchProgress]))) {
      yield await load();
    }
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
      // Chunk to avoid SQLite 999-variable limit.
      final allMovieRows = <MovieRow>[];
      for (var i = 0; i < ids.length; i += 900) {
        final chunk = ids.sublist(i, (i + 900).clamp(0, ids.length));
        final rows = await (select(movies)..where((t) => t.id.isIn(chunk))).get();
        allMovieRows.addAll(rows);
      }
      final byId = {for (final r in allMovieRows) r.id: r};
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

  Future<void> clearMovieProgress(String profileId, String id) =>
      _clearProgress(profileId, 'movie', id);

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

  Future<void> clearChannelLastWatched(String profileId, String id) =>
      _clearProgress(profileId, 'channel', id);

  /// Most recently watched channels, newest first. With [sourceId], only
  /// that playlist's channels — the history row should follow the active
  /// playlist like every other list.
  Stream<List<model.Channel>> watchRecentChannels(String profileId,
      {int limit = 20, String? sourceId}) {
    return (select(watchProgress)
          ..where((w) =>
              w.profileId.equals(profileId) &
              w.contentType.equals('channel') &
              w.lastWatchedAt.isNotNull())
          ..orderBy([(w) => OrderingTerm.desc(w.lastWatchedAt)])
          // Headroom so filtering to one playlist can still fill [limit].
          ..limit(sourceId == null ? limit : limit * 5))
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
          .where((r) => sourceId == null || r.sourceId == sourceId)
          .take(limit)
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
      // Chunk to avoid SQLite 999-variable limit.
      final allEpisodeRows = <EpisodeRow>[];
      for (var i = 0; i < ids.length; i += 900) {
        final chunk = ids.sublist(i, (i + 900).clamp(0, ids.length));
        final rows = await (select(episodes)..where((t) => t.id.isIn(chunk))).get();
        allEpisodeRows.addAll(rows);
      }
      final byId = {for (final r in allEpisodeRows) r.id: r};
      final progressById = {for (final p in progressRows) p.contentId: p};
      return ids
          .map((id) => byId[id])
          .whereType<EpisodeRow>()
          .map((row) =>
              _applyEpisodeProgress(_episodeFromRow(row), progressById[row.id]))
          .where((e) => e.isInProgress)
          .toList();
    });
  }

  Future<void> clearEpisodeProgress(String profileId, String id) =>
      _clearProgress(profileId, 'episode', id);

  Future<void> upsertMovies(List<model.Movie> movieList) async {
    await _batchInChunks(movieList.map(_movieToCompanion).toList(),
        (b, chunk) => b.insertAllOnConflictUpdate(movies, chunk));
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

  Future<void> replaceMoviesForSource(
      String sourceId, List<model.Movie> movieList) {
    return transaction(() async {
      await deleteMoviesForSource(sourceId);
      await upsertMovies(movieList);
    });
  }

  // ---------------------------------------------------------------------------
  // Series DAOs
  // ---------------------------------------------------------------------------

  Future<List<model.Series>> getAllSeries() async {
    final rows = await select(seriesEntries).get();
    return rows.map(_seriesFromRow).toList();
  }

  Stream<List<model.Series>> watchAllSeries() {
    return select(seriesEntries)
        .watch()
        .map((rows) => rows.map(_seriesFromRow).toList());
  }

  Future<model.Series?> getSeriesById(String id) async {
    final row = await (select(seriesEntries)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _seriesFromRow(row);
  }

  /// Series counterpart of [getMoviesInGenre].
  Future<List<model.Series>> getSeriesInGenre(
    String sourceId,
    String genre, {
    required String excludeId,
    int limit = 60,
  }) async {
    final escapedGenre = genre.replaceAllMapped(
        RegExp(r'[\\%_]'), (m) => '\\${m[0]}');
    final rows = await (select(seriesEntries)
          ..where((t) =>
              t.sourceId.equals(sourceId) &
              t.genre.like('%$escapedGenre%', escapeChar: '\\') &
              t.id.equals(excludeId).not())
          ..limit(limit))
        .get();
    return rows.map(_seriesFromRow).toList();
  }

  Stream<List<model.Series>> watchSeriesForSource(String sourceId) {
    return (select(seriesEntries)
          ..where((t) => t.sourceId.equals(sourceId))
          ..orderBy([(t) => OrderingTerm.asc(t.title)]))
        .watch()
        .map((rows) => rows.map(_seriesFromRow).toList());
  }

  Future<void> upsertSeries(List<model.Series> seriesList) async {
    await _batchInChunks(seriesList.map(_seriesToCompanion).toList(),
        (b, chunk) => b.insertAllOnConflictUpdate(seriesEntries, chunk));
  }

  Future<void> deleteSeriesForSource(String sourceId) async {
    await (delete(seriesEntries)..where((t) => t.sourceId.equals(sourceId)))
        .go();
  }

  Future<void> replaceSeriesForSource(
      String sourceId, List<model.Series> seriesList) {
    return transaction(() async {
      await deleteSeriesForSource(sourceId);
      await upsertSeries(seriesList);
    });
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
    final row = await (select(episodes)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _episodeFromRow(row);
  }

  Stream<List<model.Episode>> watchEpisodesForSeries(String seriesId,
      {String? profileId}) {
    return _watchWithProgress(episodes, () async {
      final rows = await (select(episodes)
            ..where((t) => t.seriesId.equals(seriesId))
            ..orderBy([
              (t) => OrderingTerm.asc(t.season),
              (t) => OrderingTerm.asc(t.episode),
            ]))
          .get();
      return _withEpisodeProgress(
          rows.map(_episodeFromRow).toList(), profileId);
    });
  }

  Future<void> upsertEpisodes(List<model.Episode> episodeList) async {
    await _batchInChunks(episodeList.map(_episodeToCompanion).toList(),
        (b, chunk) => b.insertAllOnConflictUpdate(episodes, chunk));
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

  Future<void> replaceEpisodesForSource(
      String sourceId, List<model.Episode> episodeList) {
    return transaction(() async {
      await deleteEpisodesForSource(sourceId);
      await upsertEpisodes(episodeList);
    });
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
        type: row.type == 'xtream'
            ? model.SourceType.xtream
            : model.SourceType.m3u,
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
        customChannelOrder:
            Map<String, int>.from(jsonDecode(row.customChannelOrder) as Map),
        epgOverrides:
            Map<String, String>.from(jsonDecode(row.epgOverrides) as Map),
        hiddenCategories:
            List<String>.from(jsonDecode(row.hiddenCategories) as List),
        isKidsProfile: row.isKidsProfile,
        isAdmin: row.isAdmin,
        accentColor: row.accentColor,
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
        accentColor: Value(p.accentColor),
        createdAt: Value(p.createdAt),
        updatedAt: Value(p.updatedAt),
      );
}

// Top-level so Isolate.spawn can send it across isolate boundaries.
void _dbSetup(Database db) {
  // Wait for another connection's write before failing with SQLITE_BUSY:
  // the background auto-refresh swaps a playlist's list in one transaction
  // (~10 s for 76k movies on a phone, longer on a TV), and the app's
  // progress saves must queue behind it, not fail. Reads never wait (WAL).
  // Must be set before migrations run.
  db.execute('PRAGMA busy_timeout = 60000;');
  // The write-ahead log grows to the size of the biggest write (a playlist
  // swap, a guide import) and SQLite never shrinks it on its own — on a TV
  // it reached over a gigabyte. Cap what it keeps after each checkpoint.
  db.execute('PRAGMA journal_size_limit = 33554432;');
  // Space freed by a refresh can be handed back to the device ([compact]).
  // Takes effect on a new database right away; an existing one switches
  // over once, in [compactIfBloated].
  db.execute('PRAGMA auto_vacuum = INCREMENTAL;');
}

/// The app database, encrypted on disk (see db_encryption.dart). The
/// background auto-refresh isolate passes `migrate: false` so it never
/// races the app converting an older unencrypted database.
QueryExecutor _openConnection({bool migrate = true}) {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'open_iptv.db'));
    final (executor, state) = await openEncryptedDatabase(
      file,
      keys: DbKeyStore(),
      setup: _dbSetup,
      migrate: migrate,
    );
    debugPrint('[OTV-db] opened (${state.name})');
    if (migrate) unawaited(_logStorage(dbFolder));
    return executor;
  });
}

/// Logs every file over 1 MB in the app's folders (sizes only), so storage
/// growth on a device can be traced with `adb logcat | grep OTV-storage`.
Future<void> _logStorage(Directory documents) async {
  try {
    final dirs = <Directory>{
      documents,
      await getApplicationSupportDirectory(),
      await getTemporaryDirectory(),
    };
    for (final dir in dirs) {
      var total = 0;
      final big = <String>[];
      await for (final e in dir.list(recursive: true, followLinks: false)) {
        if (e is! File) continue;
        final size = await e.length();
        total += size;
        if (size > 1 << 20) {
          big.add('${p.relative(e.path, from: dir.path)} '
              '${(size / (1 << 20)).toStringAsFixed(1)} MB');
        }
      }
      debugPrint('[OTV-storage] ${p.basename(dir.path)}: '
          '${(total / (1 << 20)).toStringAsFixed(1)} MB'
          '${big.isEmpty ? '' : ' — ${big.join(', ')}'}');
    }
  } catch (e) {
    debugPrint('[OTV-storage] report failed: $e');
  }
}
