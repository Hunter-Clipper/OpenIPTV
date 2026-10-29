import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:open_iptv/core/models/channel.dart';
import 'package:open_iptv/core/models/episode.dart';
import 'package:open_iptv/core/models/movie.dart';
import 'package:open_iptv/core/models/profile.dart';
import 'package:open_iptv/core/models/series.dart';
import 'package:open_iptv/core/services/parental_service.dart';
import 'package:open_iptv/core/storage/database.dart';
import 'package:open_iptv/core/storage/preferences.dart';
import 'package:open_iptv/shared/utils/display_name.dart';

/// Something playable picked in the car: what to open and how.
@immutable
class CarPlayable {
  const CarPlayable({
    required this.mediaId,
    required this.title,
    required this.streamUrl,
    required this.kind,
    required this.contentId,
    this.subtitle,
    this.artUri,
    this.resumeAt,
  });

  final String mediaId;
  final String title;
  final String? subtitle;
  final Uri? artUri;
  final String streamUrl;

  /// 'channel', 'movie' or 'episode'.
  final String kind;
  final String contentId;
  final Duration? resumeAt;

  bool get isLive => kind == 'channel';
}

/// The Android Auto browse tree (#33), built from the same data and rules
/// as the phone app: the active profile and playlist, hidden categories,
/// parental locks (locked categories are simply left out — there's no PIN
/// entry in the car) and Kids profiles (no adult content).
///
/// Media ids:
///   root → `live`, `movies`, `series` (the car's tabs)
///   `live` → `live/fav`, `live/recent`, `live/cat|<name>` → `ch|<id>`
///   `movies` → `mov/cw`, `mov/fav`, `mov/genre|<g>` → `mv|<id>`
///   `series` → `ser/cw` (→ `ep|<seriesId>|<id>`), `ser/fav`,
///   `ser/genre|<g>` → `sr|<id>` → `ep|<seriesId>|<id>`
class CarLibrary {
  CarLibrary({
    required this.db,
    required this.loadPrefs,
    required this.loadProfile,
    this.fetchEpisodes,
    this.nowOn,
  });

  final AppDatabase db;
  final Future<AppPreferences> Function() loadPrefs;
  final Future<Profile?> Function() loadProfile;

  /// Xtream series load their episodes on first open.
  final Future<void> Function(String seriesId, String sourceId)? fetchEpisodes;

  /// What's on a channel right now (its TV guide), for the subtitle.
  final Future<String?> Function(String channelId)? nowOn;

  /// Car lists are kept short — long lists are hard to use while driving.
  static const maxItems = 100;

  static const live = 'live';
  static const movies = 'movies';
  static const series = 'series';

  static final _grid = {
    AndroidContentStyle.playableHintKey: AndroidContentStyle.gridItemHintValue,
  };
  static final _list = {
    AndroidContentStyle.browsableHintKey: AndroidContentStyle.listItemHintValue,
    AndroidContentStyle.playableHintKey: AndroidContentStyle.listItemHintValue,
  };

  Future<_Ctx?> _ctx() async {
    final profile = await loadProfile();
    if (profile == null) return null;
    return _Ctx(profile, await loadPrefs());
  }

  /// Children of [parentId]; a single "get started" message when the app
  /// hasn't been set up on the phone yet.
  Future<List<MediaItem>> children(String parentId) async {
    final c = await _ctx();
    if (c == null) {
      return const [
        MediaItem(
          id: 'setup',
          title: 'Open OpenIPTV on your phone to get started',
          playable: false,
        ),
      ];
    }
    final parts = parentId.split('|');
    switch (parts.first) {
      case AudioService.browsableRootId:
        return [
          _folder(live, 'Live TV'),
          _folder(movies, 'Movies'),
          _folder(series, 'Series'),
        ];
      case live:
        return [
          _folder('live/fav', 'Favorites'),
          _folder('live/recent', 'Recently Watched'),
          for (final cat in await _channelCategories(c))
            _folder('live/cat|$cat', c.name(cat)),
        ];
      case 'live/fav':
        final fav = c.profile.favoriteChannelIds.toSet();
        return _channelItems(c, (await _channels(c))
            .where((ch) => fav.contains(ch.id)));
      case 'live/recent':
        final recent = await db
            .watchRecentChannels(c.profile.id, sourceId: c.sourceId)
            .first;
        return _channelItems(c, recent.where((ch) => c.allowChannel(ch)));
      case 'live/cat':
        final cat = parts.sublist(1).join('|');
        return _channelItems(c, (await _channels(c))
            .where((ch) => ch.categories.contains(cat)));
      case movies:
        return [
          _folder('mov/cw', 'Continue Watching'),
          _folder('mov/fav', 'Favorites'),
          for (final g in _genres(c, (await _movies(c)).map((m) => m.genre)))
            _folder('mov/genre|$g', c.name(g)),
        ];
      case 'mov/cw':
        final inProgress =
            await db.watchMoviesInProgress(c.profile.id).first;
        return _movieItems(c, inProgress.where(
            (m) => c.inSource(m.sourceId) && c.allowGenre(m.genre)));
      case 'mov/fav':
        final fav = c.profile.favoriteMovieIds.toSet();
        return _movieItems(c, 
            (await _movies(c)).where((m) => fav.contains(m.id)));
      case 'mov/genre':
        final g = parts.sublist(1).join('|').toLowerCase();
        return _movieItems(c, (await _movies(c)).where(
            (m) => splitGenres(m.genre).any((x) => x.toLowerCase() == g)));
      case series:
        return [
          _folder('ser/cw', 'Continue Watching'),
          _folder('ser/fav', 'Favorites'),
          for (final g in _genres(c, (await _series(c)).map((s) => s.genre)))
            _folder('ser/genre|$g', c.name(g)),
        ];
      case 'ser/cw':
        final eps = await db.watchEpisodesInProgress(c.profile.id).first;
        final shows = {for (final s in await _series(c)) s.id: s};
        return [
          for (final e in eps)
            if (shows.containsKey(e.seriesId))
              _episodeItem(c, e, shows[e.seriesId]),
        ].take(maxItems).toList();
      case 'ser/fav':
        final fav = c.profile.favoriteSeriesIds.toSet();
        return _seriesItems(c, 
            (await _series(c)).where((s) => fav.contains(s.id)));
      case 'ser/genre':
        final g = parts.sublist(1).join('|').toLowerCase();
        return _seriesItems(c, (await _series(c)).where(
            (s) => splitGenres(s.genre).any((x) => x.toLowerCase() == g)));
      case 'sr':
        final show = await db.getSeriesById(parts[1]);
        if (show == null || !c.allowGenre(show.genre)) return const [];
        var eps =
            await db.getEpisodesForSeries(show.id, profileId: c.profile.id);
        if (eps.isEmpty && fetchEpisodes != null) {
          await fetchEpisodes!(show.id, show.sourceId);
          eps = await db.getEpisodesForSeries(show.id,
              profileId: c.profile.id);
        }
        return [for (final e in eps) _episodeItem(c, e, show)]
            .take(maxItems * 3)
            .toList();
    }
    return const [];
  }

  /// Search for the car's search box and voice ("play … on OpenIPTV"):
  /// channels first, then movies and series.
  Future<List<MediaItem>> search(String query) async {
    final c = await _ctx();
    final q = query.trim().toLowerCase();
    if (c == null || q.length < 2) return const [];
    bool hit(String name) => name.toLowerCase().contains(q);
    return [
      ..._channelItems(c, (await _channels(c)).where((ch) => hit(ch.name)))
          .take(20),
      ..._movieItems(c, (await _movies(c)).where((m) => hit(m.title))).take(20),
      ..._seriesItems(c, (await _series(c)).where((s) => hit(s.title))).take(20),
    ];
  }

  /// What a playable media id points at, re-checked against the current
  /// profile's rules.
  Future<CarPlayable?> resolve(String mediaId) async {
    final c = await _ctx();
    if (c == null) return null;
    final parts = mediaId.split('|');
    switch (parts.first) {
      case 'ch':
        final ch = await db.getChannelById(parts[1]);
        if (ch == null || !c.allowChannel(ch)) return null;
        return CarPlayable(
          mediaId: mediaId,
          title: c.name(ch.name),
          subtitle: await nowOn?.call(ch.id),
          streamUrl: ch.streamUrl,
          kind: 'channel',
          contentId: ch.id,
          artUri: _uri(ch.logoUrl),
        );
      case 'mv':
        final m =
            await db.watchMovieById(parts[1], profileId: c.profile.id).first;
        if (m == null || !c.allowGenre(m.genre)) return null;
        return CarPlayable(
          mediaId: mediaId,
          title: c.name(m.title),
          subtitle: m.year?.toString(),
          streamUrl: m.streamUrl,
          kind: 'movie',
          contentId: m.id,
          artUri: _uri(m.posterUrl),
          resumeAt: m.isInProgress ? m.watchedDuration : null,
        );
      case 'ep':
        final show = await db.getSeriesById(parts[1]);
        if (show == null || !c.allowGenre(show.genre)) return null;
        final eps =
            await db.getEpisodesForSeries(show.id, profileId: c.profile.id);
        final e = eps.where((x) => x.id == parts[2]).firstOrNull;
        if (e == null) return null;
        return CarPlayable(
          mediaId: mediaId,
          title: e.displayTitle,
          subtitle: '${e.episodeLabel} · ${c.name(show.title)}',
          streamUrl: e.streamUrl,
          kind: 'episode',
          contentId: e.id,
          artUri: _uri(e.stillUrl ?? show.posterUrl),
          resumeAt: e.isInProgress ? e.watchedDuration : null,
        );
    }
    return null;
  }

  // ---------------------------------------------------------------------------

  Future<List<Channel>> _channels(_Ctx c) async {
    final all = c.sourceId != null
        ? await db
            .watchChannelsForSource(c.sourceId!, profileId: c.profile.id)
            .first
        : await db.getAllChannels(profileId: c.profile.id);
    return all.where(c.allowChannel).toList();
  }

  Future<List<String>> _channelCategories(_Ctx c) async {
    final seen = <String>{};
    final cats = <String>[];
    for (final ch in await _channels(c)) {
      for (final cat in ch.categories) {
        if (c.allowCategory(cat) && seen.add(cat)) cats.add(cat);
      }
    }
    if (c.prefs.contentSort == 'az') cats.sort();
    return cats;
  }

  Future<List<Movie>> _movies(_Ctx c) async =>
      (await db.getAllMovies(profileId: c.profile.id))
          .where((m) => c.inSource(m.sourceId) && c.allowGenre(m.genre))
          .toList();

  Future<List<Series>> _series(_Ctx c) async => (await db.getAllSeries())
      .where((s) => c.inSource(s.sourceId) && c.allowGenre(s.genre))
      .toList();

  List<String> _genres(_Ctx c, Iterable<String?> raw) {
    final seen = <String>{};
    final out = <String>[];
    for (final genre in raw) {
      for (final g in splitGenres(genre)) {
        if (g.isNotEmpty && c.allowCategory(g) && seen.add(g)) out.add(g);
      }
    }
    if (c.prefs.contentSort == 'az') out.sort();
    return out;
  }

  MediaItem _folder(String id, String title) =>
      MediaItem(id: id, title: title, playable: false, extras: _list);

  List<MediaItem> _channelItems(_Ctx c, Iterable<Channel> channels) => [
        for (final ch in channels.take(maxItems))
          MediaItem(
            id: 'ch|${ch.id}',
            title: c.name(ch.name),
            artUri: _uri(ch.logoUrl),
            playable: true,
            extras: _list,
          ),
      ];

  List<MediaItem> _movieItems(_Ctx c, Iterable<Movie> movies) => [
        for (final m in movies.take(maxItems))
          MediaItem(
            id: 'mv|${m.id}',
            title: c.name(m.title),
            artist: m.year?.toString(),
            artUri: _uri(m.posterUrl),
            playable: true,
            extras: _grid,
          ),
      ];

  List<MediaItem> _seriesItems(_Ctx c, Iterable<Series> shows) => [
        for (final s in shows.take(maxItems))
          MediaItem(
            id: 'sr|${s.id}',
            title: c.name(s.title),
            artUri: _uri(s.posterUrl),
            playable: false,
            extras: _grid,
          ),
      ];

  MediaItem _episodeItem(_Ctx c, Episode e, Series? show) => MediaItem(
        id: 'ep|${e.seriesId}|${e.id}',
        title: e.displayTitle,
        // Episode code first: car screens cut long lines short.
        artist: show == null
            ? e.episodeLabel
            : '${e.episodeLabel} · ${c.name(show.title)}',
        artUri: _uri(e.stillUrl ?? show?.posterUrl),
        playable: true,
        extras: _list,
      );

  static Uri? _uri(String? s) =>
      s == null || s.isEmpty ? null : Uri.tryParse(s);
}

/// The profile, playlist and parental rules a car request is answered with.
class _Ctx {
  _Ctx(this.profile, this.prefs) : sourceId = prefs.activeSourceId;

  final Profile profile;
  final AppPreferences prefs;
  final String? sourceId;

  late final Set<String> _hidden = profile.hiddenCategories.toSet();

  bool inSource(String id) => sourceId == null || id == sourceId;

  /// Tidied for display, per the user's "Clean Up Names" setting.
  String name(String raw) => prefs.cleanNames ? cleanDisplayName(raw) : raw;

  /// Visible here: not hidden, not parental-locked, not adult on Kids.
  bool allowCategory(String name) =>
      !_hidden.contains(name) &&
      !isCategoryLocked(name, prefs, const {}) &&
      !(profile.isKidsProfile && isAdultCategory(name));

  bool allowChannel(Channel ch) =>
      inSource(ch.sourceId) && ch.categories.every(allowCategory);

  bool allowGenre(String? genre) => splitGenres(genre).every(allowCategory);
}
