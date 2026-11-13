import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_iptv/core/epg/guide_matcher.dart';
import 'package:open_iptv/core/models/programme.dart';
import 'package:open_iptv/core/services/guide_fetch.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/core/storage/database.dart';
import 'package:open_iptv/core/storage/preferences.dart';
import 'package:open_iptv/shared/utils/friendly_error.dart';
import 'package:open_iptv/shared/utils/redact.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final guideAssignmentProvider = Provider<GuideAssignmentService>(
    (ref) => GuideAssignmentService(db: ref.watch(appDatabaseProvider)));

/// What one sync did, for the screen and the log.
class GuideSyncResult {
  const GuideSyncResult({
    this.guides = 0,
    this.linked = 0,
    this.programmes = 0,
    this.errors = const [],
  });
  final int guides;
  final int linked;
  final int programmes;
  final List<String> errors;
}

class _Guide {
  const _Guide(this.ref, this.url, this.name, this.extraId);
  final String ref;
  final String url;
  final String name;
  final String? extraId;
}

/// Extra guides, smart assignment and manual links (#40).
///
/// Priority, as the owner set it: a playlist's own guide always wins; smart
/// links only fill channels it does not cover (the playlist's own guide file
/// is searched first, then the extra guides in the user's order); a manual
/// link beats everything.
class GuideAssignmentService {
  GuideAssignmentService(
      {required this.db, this.tempDir, this.stallTimeout = const Duration(seconds: 60)});

  /// How long a guide download may go quiet before it is given up on.
  final Duration stallTimeout;

  final AppDatabase db;

  /// Where zipped guides are unpacked (tests point it somewhere harmless).
  final Future<String> Function()? tempDir;

  static Future<GuideSyncResult>? _running;
  /// Whether a sync is running now (started from anywhere, e.g. after a
  /// playlist refresh), so screens can hold their own triggers.
  static bool get isRunning => _running != null;

  /// Completes when the running sync ends (or at once if none runs).
  static Future<void> whenIdle() async {
    try {
      await _running;
    } catch (_) {}
  }

  static bool _again = false;
  static bool _againLists = false;
  static bool _againForce = false;

  /// Runs a sync. A call that arrives while one is running is not lost: the
  /// running one is followed by another that covers what the call asked for
  /// (the links and settings may have changed since the first one looked),
  /// and the caller gets the result of the last.
  ///
  /// [force] false skips re-downloading a guide whose linked channels
  /// already hold current programmes (toggling or reordering a guide, a mode
  /// change); the regular refresh and "Update Now" force a fresh read.
  Future<GuideSyncResult> sync({
    void Function(String)? onProgress,
    bool refreshLists = true,
    bool force = true,
  }) {
    final running = _running;
    if (running != null) {
      _again = true;
      _againLists = _againLists || refreshLists;
      _againForce = _againForce || force;
      return running;
    }
    return _running = _runQueued(onProgress, refreshLists, force)
        .whenComplete(() {
      _running = null;
    });
  }

  Future<GuideSyncResult> _runQueued(
      void Function(String)? onProgress, bool refreshLists, bool force) async {
    var result = await _sync(onProgress, refreshLists, force);
    while (_again) {
      final lists = _againLists;
      final f = _againForce;
      _again = false;
      _againLists = false;
      _againForce = false;
      result = await _sync(onProgress, lists, f);
    }
    return result;
  }

  Future<List<_Guide>> _guides() async {
    final sources = await db.getAllSources();
    final extras = (await db.getExtraGuides()).where((g) => g.enabled);
    return [
      for (final s in sources)
        if (s.epgUrl != null && s.epgUrl!.isNotEmpty)
          _Guide('src:${s.id}', s.epgUrl!, s.nickname, null),
      for (final e in extras) _Guide('ext:${e.id}', e.url, e.name, e.id),
    ];
  }

  // A guide that gave nothing is not asked again at once (the provider's
  // server rate-limits, and a retry every sync would only make it worse).
  static const _coolDown = Duration(hours: 6);

  /// True when [key] has not been tried within [_coolDown]; stamps it.
  Future<bool> _mayTry(SharedPreferences sp, String key,
      {Duration within = _coolDown}) async {
    final last = sp.getInt(key);
    final now = DateTime.now().millisecondsSinceEpoch;
    if (last != null && now - last < within.inMilliseconds) return false;
    await sp.setInt(key, now);
    return true;
  }

  /// A matcher over every stored guide channel, with each guide's name, for
  /// the Change Guide picker. Guides in priority order. [withMatcher] false
  /// gives just the guide names (cheap), for screens that only show names.
  Future<GuidePicker> loadPicker({bool withMatcher = true}) async {
    final guides = await _guides();
    final names = {for (final g in guides) g.ref: g.name};
    if (!withMatcher) return GuidePicker.namesOnly(names);
    final order = {for (final (i, g) in guides.indexed) g.ref: i};
    // Entries a guide lists but has nothing for are no use to pick.
    final rows = [
      for (final r in await db.getGuideChannels())
        if (order.containsKey(r.guideRef) && r.hasProgrammes != false) r,
    ]..sort((a, b) => order[a.guideRef]!.compareTo(order[b.guideRef]!));
    return GuidePicker.start(
      [
        for (final r in rows)
          GuideChannel(
            guideId: r.guideRef,
            xmltvId: r.xmltvId,
            name: r.name.isEmpty ? nameFromGuideId(r.xmltvId) : r.name,
          ),
      ],
      names,
    );
  }

  Future<GuideSyncResult> _sync(void Function(String)? onProgress,
      bool refreshLists, bool force,
      {int pass = 0}) async {
    final sw = Stopwatch()..start();
    final errors = <String>[];
    final sp = await SharedPreferences.getInstance();
    final prefs = AppPreferences(sp);
    final tmp = tempDir != null
        ? await tempDir!()
        : (await getTemporaryDirectory()).path;
    if (pass == 0) {
      await cleanGuideTemp(tmp);
      await db.deleteOrphanGuideData();
    }
    final guides = await _guides();
    final hasExtras = guides.any((g) => g.extraId != null);
    var manual = await db.manualLinkedChannelIds();

    // 1. Channel lists of every guide.
    if (refreshLists && pass == 0) {
      for (final g in guides) {
        // A playlist's own guide is read (and its channel list noted) by that
        // playlist's regular guide refresh; reading it again here would only
        // lean on the provider. Only a guide never seen is fetched, and one
        // that failed to read is not retried every sync.
        if (g.ref.startsWith('src:')) {
          if (await db.countGuideChannels(g.ref) > 0) continue;
          if (!await _mayTry(sp, 'guide_list_${g.ref}',
              within: const Duration(hours: 1))) {
            continue;
          }
        }
        onProgress?.call('Reading ${g.name}…');
        try {
          final list =
              await fetchGuideChannels(g.url, tmp, stall: stallTimeout);
          // An extra guide may have changed: what was known about which of
          // its entries have programmes starts again.
          await db.replaceGuideChannels(g.ref, list,
              keepFlags: g.extraId == null);
          if (g.extraId != null) {
            await db.setExtraGuideStatus(g.extraId!,
                updated: DateTime.now(), count: list.length);
          }
        } catch (e) {
          debugPrint('[Guides] ${g.name}: ${redactUrl('$e')}');
          errors.add('${g.name}: ${friendlyGuideError(e)}');
          if (g.extraId != null) {
            await db.setExtraGuideStatus(g.extraId!,
                error: friendlyGuideError(e));
          }
        }
      }
    }

    // Nothing more to do without an extra guide or a manual link. (The
    // channel lists above are still kept: the Change Guide picker offers
    // the playlists' own guide channels too.)
    if (!hasExtras && manual.isEmpty) {
      await db.replaceAutoLinks(const []);
      return GuideSyncResult(guides: guides.length, errors: errors);
    }

    debugPrint('[Guides] lists read: ${sw.elapsedMilliseconds} ms');
    // 2. Smart assignment.
    final order = {for (final (i, g) in guides.indexed) g.ref: i};
    // A guide entry known to have no programmes is of no use: it neither
    // covers a channel nor is worth matching to.
    final rows = [
      for (final r in await db.getGuideChannels())
        if (order.containsKey(r.guideRef) && r.hasProgrammes != false) r,
    ]..sort((a, b) => order[a.guideRef]!.compareTo(order[b.guideRef]!));
    final briefs = await db.channelBriefs();

    var auto = const <GuideLinksCompanionArgs>[];
    // Channels the playlist's own guide serves: their programmes are not ours
    // to delete when an old automatic link goes away.
    var covered = const <String>{};
    if (prefs.smartGuideAssign && rows.isNotEmpty) {
      onProgress?.call('Matching channels to guides…');
      // Channels the playlist's own guide lists keep it.
      final ownIds = {
        for (final r in rows)
          if (r.guideRef.startsWith('src:')) r.xmltvId,
      };
      // A playlist whose guide list we could not read at all: its channels
      // that carry a guide id are left alone (that guide may well have them).
      final listed = {
        for (final r in rows)
          if (r.guideRef.startsWith('src:')) r.guideRef,
      };
      final withGuideUrl = {
        for (final g in guides)
          if (g.ref.startsWith('src:')) g.ref.substring(4),
      };
      bool isCovered(ChannelBrief c) =>
          c.tvgId != null &&
          c.tvgId!.isNotEmpty &&
          (ownIds.contains(c.tvgId) ||
              (withGuideUrl.contains(c.sourceId) &&
                  !listed.contains('src:${c.sourceId}')));
      covered = {
        for (final c in briefs)
          if (isCovered(c)) c.id,
      };
      final candidates = [
        for (final c in briefs)
          if (!manual.contains(c.id) && !isCovered(c))
            (c.id, c.name, c.tvgId, c.tvgName),
      ];
      final guideRows = [
        for (final r in rows) (r.guideRef, r.xmltvId, r.name),
      ];
      final mode = GuideMatchMode.parse(prefs.guideMatchMode);
      final found =
          await Isolate.run(() => _matchAll(guideRows, candidates, mode));
      auto = [
        for (final f in found)
          GuideLinksCompanionArgs(
              channelId: f.$1,
              kind: 'auto',
              guideRef: f.$2,
              xmltvId: f.$3,
              score: f.$4),
      ];
    }
    debugPrint('[Guides] matched ${auto.length}: ${sw.elapsedMilliseconds} ms');
    final change = await db.replaceAutoLinks(auto);
    // Channels with no automatic link now have no replacement coming: their
    // old guide's programmes go (unless the playlist's own guide serves them).
    await db.deleteProgrammesForChannels(
        [for (final c in change.gone) if (!covered.contains(c)) c]);
    // A manual pick may have arrived while we were matching.
    manual = await db.manualLinkedChannelIds();

    // 3. Programmes for every linked channel, one pass per guide.
    final links = await db.getGuideLinks();
    final none = [
      for (final l in links)
        if (l.kind == 'manual' && l.xmltvId == null) l.channelId,
    ];
    await db.deleteProgrammesForChannels(none);

    final byGuide = <String, Map<String, List<String>>>{};
    for (final l in links) {
      if (l.guideRef == null || l.xmltvId == null) continue;
      ((byGuide[l.guideRef!] ??= {})[l.xmltvId!] ??= []).add(l.channelId);
    }
    final days = prefs.guideDaysAhead;
    final keepDesc = prefs.guideDescriptions;
    final maxCatchup = await db.getMaxCatchupDays();
    var imported = 0;
    var flagsChanged = false;
    final haveProgrammes = await db.channelIdsWithProgrammes();
    // Heal: a channel its own playlist's guide covers but that holds no
    // programmes (after "Use Automatic", or if they were lost) gets them from
    // that guide. Costs a download only when something is actually missing,
    // and not again for hours when the last try found nothing.
    final listedBy = <String, Set<String>>{};
    for (final r in rows) {
      if (r.guideRef.startsWith('src:')) {
        (listedBy[r.guideRef] ??= {}).add(r.xmltvId);
      }
    }
    final healed = <String, Set<String>>{}; // guide ref -> xmltv ids
    for (final c in briefs) {
      final id = c.tvgId;
      if (id == null ||
          id.isEmpty ||
          manual.contains(c.id) ||
          haveProgrammes.contains(c.id)) {
        continue;
      }
      final ref = 'src:${c.sourceId}';
      final triedAt = sp.getInt('guide_heal_$ref');
      final coolingDown = triedAt != null &&
          DateTime.now().millisecondsSinceEpoch - triedAt <
              _coolDown.inMilliseconds;
      if ((listedBy[ref]?.contains(id) ?? false) && !coolingDown) {
        ((byGuide[ref] ??= {})[id] ??= []).add(c.id);
        (healed[ref] ??= {}).add(id);
      }
    }
    final currentIds =
        force ? null : await db.channelIdsWithProgrammes(current: true);
    final replaceFor = {
      for (final c in change.changed)
        if (!covered.contains(c)) c,
    };
    for (final g in guides) {
      var wanted = byGuide[g.ref];
      if (wanted == null || wanted.isEmpty) continue;
      // A playlist's own guide is re-read by the playlist's regular guide
      // refresh, which also fills the channels linked to it. Here only the
      // newly linked ones (no programmes yet) are worth a download.
      if (g.ref.startsWith('src:')) {
        wanted = {
          for (final e in wanted.entries)
            if (e.value.any((c) => !haveProgrammes.contains(c))) e.key: e.value,
        };
        if (wanted.isEmpty) continue;
      } else if (currentIds != null &&
          wanted.values.every((cs) => cs.every(currentIds.contains))) {
        // Nothing new to fetch for this guide (a reorder, a mode change).
        continue;
      }
      onProgress?.call('Loading ${g.name} (${wanted.length} channels)…');
      try {
        final sent = <String>{};
        var stored = 0;
        // Only when every wanted channel already holds programmes may the
        // server say "unchanged" (a newly linked channel needs the file).
        final canSkip = !force ||
            wanted.values.every((cs) => cs.every(haveProgrammes.contains));
        final etagKey = 'guide_etag_${g.ref}';
        String? newEtag;
        var notModified = false;
        await for (final batch in streamGuideProgrammes(
          g.url,
          tmp,
          wanted.keys.toSet(),
          pastWindow: maxCatchup > 0
              ? Duration(days: maxCatchup)
              : const Duration(hours: 1),
          daysAhead: days,
          keepDescriptions: keepDesc,
          stall: stallTimeout,
          etag: canSkip && g.extraId != null ? sp.getString(etagKey) : null,
          onDone: (e, nm) {
            newEtag = e;
            notModified = nm;
          },
        )) {
          for (final p in batch) {
            sent.add(p.channelId);
          }
          stored += await _store(batch, wanted,
              ref: g.ref, replaceFor: replaceFor);
        }
        if (notModified) {
          debugPrint('[Guides] ${g.name}: not modified');
          continue;
        }
        if (g.extraId != null) {
          if (newEtag != null) {
            await sp.setString(etagKey, newEtag!);
          } else {
            await sp.remove(etagKey);
          }
        }
        imported += stored;
        if (sent.isEmpty && g.extraId == null) {
          // The playlist's own guide is covered by its regular refresh; just
          // do not ask again for hours.
          debugPrint('[Guides] ${g.name}: no programmes for '
              '${wanted.length} linked channels');
          if (healed[g.ref] != null) {
            await sp.setInt('guide_heal_${g.ref}',
                DateTime.now().millisecondsSinceEpoch);
          }
          continue;
        }
        if (g.extraId != null) {
          // Entries linked but with nothing current are of no use: the next
          // pass matches those channels to the next guide that has data.
          final wantedIds = wanted.keys.toSet();
          final missing = wantedIds.difference(sent);
          if (missing.isNotEmpty) {
            debugPrint('[Guides] ${g.name}: nothing for ${missing.length} '
                'of ${wantedIds.length} linked entries');
            await db.setGuideProgrammeFlags(g.ref,
                found: sent.intersection(wantedIds), missing: missing);
            flagsChanged = true;
          }
        }
      } catch (e) {
        debugPrint('[Guides] ${g.name}: ${redactUrl('$e')}');
        errors.add('${g.name}: ${friendlyGuideError(e)}');
        if (g.extraId == null && healed[g.ref] != null) {
          await sp.setInt(
              'guide_heal_${g.ref}', DateTime.now().millisecondsSinceEpoch);
        }
      }
    }
    await db.deleteOldProgrammes();
    await db.deleteProgrammesStartingAfter(
        DateTime.now().add(Duration(days: days)));
    await db.compact();
    debugPrint('[Guides] sync: ${guides.length} guides, ${auto.length} auto '
        'links, ${manual.length} manual, $imported programmes, '
        '${errors.length} problems, ${sw.elapsedMilliseconds} ms');
    // An entry found empty: match those channels again, to the next guide.
    if (flagsChanged && pass == 0) {
      // Only guides with newly linked, still empty channels need reading.
      final again = await _sync(onProgress, false, false, pass: 1);
      return GuideSyncResult(
        guides: guides.length,
        linked: again.linked,
        programmes: imported + again.programmes,
        errors: [...errors, ...again.errors],
      );
    }
    return GuideSyncResult(
      guides: guides.length,
      linked: auto.length + manual.length,
      programmes: imported,
      errors: errors,
    );
  }

  /// Stores one batch for the channels linked to its guide entries. A channel
  /// is only written if its link still says this guide (a pick made while we
  /// were downloading wins). Channels in [replaceFor] are being moved to this
  /// guide, so their old programmes go just before the new ones arrive.
  Future<int> _store(List<Programme> ps, Map<String, List<String>> wanted,
      {String? ref, Set<String> replaceFor = const {}}) async {
    final out = <Programme>[];
    final moving = <String>{};
    // Links as they are now, not as they were when the sync began.
    final now = ref == null
        ? const <String, GuideLinkRow>{}
        : await db.getGuideLinksFor({
            for (final p in ps) ...?wanted[p.channelId],
          });
    for (final p in ps) {
      for (final id in wanted[p.channelId] ?? const <String>[]) {
        final l = now[id];
        if (l != null && (l.guideRef != ref || l.xmltvId != p.channelId)) {
          continue;
        }
        if (replaceFor.contains(id)) moving.add(id);
        out.add(Programme(
          channelId: id,
          start: p.start,
          end: p.end,
          title: p.title,
          description: p.description,
          category: p.category,
          episodeNum: p.episodeNum,
        ));
      }
    }
    if (moving.isNotEmpty) await db.deleteProgrammesForChannels(moving);
    const batch = 5000;
    for (var i = 0; i < out.length; i += batch) {
      await db.upsertProgrammes(out.sublist(i, (i + batch).clamp(0, out.length)));
    }
    return out.length;
  }

  /// The user picked [xmltvId] of [guideRef] for [channelId]: reads that one
  /// entry from its one guide first and only then swaps the link and the
  /// programmes in. If the guide can not be read or has nothing for the
  /// entry, nothing changes and the problem is returned in plain English.
  Future<String?> setManualAndLoad(
      String channelId, String guideRef, String xmltvId) async {
    final guide = (await _guides()).where((g) => g.ref == guideRef).firstOrNull;
    if (guide == null) return 'That guide is no longer in your list.';
    final sw = Stopwatch()..start();
    try {
      final sp = await SharedPreferences.getInstance();
      final prefs = AppPreferences(sp);
      final tmp = tempDir != null
          ? await tempDir!()
          : (await getTemporaryDirectory()).path;
      final maxCatchup = await db.getMaxCatchupDays();
      final ps = <Programme>[];
      await for (final b in streamGuideProgrammes(
        guide.url,
        tmp,
        {xmltvId},
        pastWindow: maxCatchup > 0
            ? Duration(days: maxCatchup)
            : const Duration(hours: 1),
        daysAhead: prefs.guideDaysAhead,
        keepDescriptions: prefs.guideDescriptions,
        stall: stallTimeout,
      )) {
        ps.addAll(b);
      }
      if (ps.isEmpty) {
        return '${guide.name} has no programmes for that channel right now. '
            'Your guide choice was not changed.';
      }
      await db.deleteProgrammesForChannels([channelId]);
      await db.setGuideLink(GuideLinksCompanionArgs(
          channelId: channelId,
          kind: 'manual',
          guideRef: guideRef,
          xmltvId: xmltvId));
      final n = await _store(ps, {
        xmltvId: [channelId]
      });
      debugPrint('[Guides] loaded $n programmes for one channel: '
          '${sw.elapsedMilliseconds} ms');
      return null;
    } catch (e) {
      debugPrint('[Guides] ${guide.name}: ${redactUrl('$e')}');
      return '${guide.name}: ${friendlyGuideError(e)} '
          'Your guide choice was not changed.';
    }
  }

  /// Links [channelId] to one guide channel without loading anything (the
  /// programmes arrive with the next [sync]).
  Future<void> setManual(String channelId, String guideRef, String xmltvId) async {
    await db.deleteProgrammesForChannels([channelId]);
    await db.setGuideLink(GuideLinksCompanionArgs(
        channelId: channelId,
        kind: 'manual',
        guideRef: guideRef,
        xmltvId: xmltvId));
  }

  /// "No guide for this channel."
  Future<void> setNone(String channelId) async {
    await db.deleteProgrammesForChannels([channelId]);
    await db.setGuideLink(
        GuideLinksCompanionArgs(channelId: channelId, kind: 'manual'));
  }

  /// Back to automatic: the playlist's guide or a smart link.
  Future<void> resetLink(String channelId) => db.clearGuideLink(channelId);
}

/// What the Change Guide screen searches. The matcher lives in its own
/// isolate (building it over every guide's channels is heavy for a TV's UI
/// thread); [suggest] and [search] ask it. Call [close] when done.
class GuidePicker {
  GuidePicker._(this.guideNames, this._worker, this.length);

  /// Just the guide names (Review Matches needs nothing else).
  GuidePicker.namesOnly(this.guideNames)
      : _worker = null,
        length = 0;

  static Future<GuidePicker> start(
      List<GuideChannel> channels, Map<String, String> names) async {
    if (channels.isEmpty) return GuidePicker._(names, null, 0);
    return GuidePicker._(names, await _PickerWorker.start(channels), channels.length);
  }

  /// Guide reference (`src:…` / `ext:…`) → the name the user knows it by.
  final Map<String, String> guideNames;
  final _PickerWorker? _worker;
  final int length;

  bool get isEmpty => length == 0;

  Future<List<GuideChannel>> suggest(String name) =>
      _worker?.ask('suggest', name, null) ?? Future.value(const []);

  Future<List<GuideChannel>> search(String query, {String? like}) =>
      _worker?.ask('search', query, like) ?? Future.value(const []);

  void close() => _worker?.close();
}

class _PickerWorker {
  _PickerWorker._(this._isolate, this._commands);
  final Isolate _isolate;
  final SendPort _commands;

  static Future<_PickerWorker> start(List<GuideChannel> channels) async {
    final rx = ReceivePort();
    final isolate = await Isolate.spawn(_pickerMain, [rx.sendPort, channels]);
    final commands = await rx.first as SendPort;
    rx.close();
    return _PickerWorker._(isolate, commands);
  }

  Future<List<GuideChannel>> ask(String op, String a, String? b) async {
    final reply = ReceivePort();
    _commands.send([reply.sendPort, op, a, b]);
    final r = await reply.first as List;
    reply.close();
    return r.cast<GuideChannel>();
  }

  void close() => _isolate.kill(priority: Isolate.immediate);
}

void _pickerMain(List<Object?> a) {
  final matcher = GuideMatcher((a[1] as List).cast<GuideChannel>());
  final commands = ReceivePort();
  (a[0] as SendPort).send(commands.sendPort);
  commands.listen((m) {
    final msg = m as List;
    final reply = msg[0] as SendPort;
    final op = msg[1] as String;
    reply.send(op == 'suggest'
        ? matcher.suggest(msg[2] as String)
        : matcher.search(msg[2] as String, like: msg[3] as String?));
  });
}

/// Bumped whenever guide data changed under the screens (a sync finished, a
/// link was edited), so guide rows and now/next lines load again.
final guideRevisionProvider = StateProvider<int>((ref) => 0);

/// Matching of every candidate in one pass; runs in an isolate.
List<(String, String, String, double)> _matchAll(
  List<(String, String, String)> guideRows,
  List<(String, String, String?, String?)> candidates,
  GuideMatchMode mode,
) {
  final matcher = GuideMatcher(threshold: mode.threshold, idOnly: mode == GuideMatchMode.explicit, [
    for (final r in guideRows)
      GuideChannel(
        guideId: r.$1,
        xmltvId: r.$2,
        name: r.$3.isEmpty ? nameFromGuideId(r.$2) : r.$3,
      ),
  ]);
  final out = <(String, String, String, double)>[];
  for (final c in candidates) {
    final m = matcher.match(c.$2, tvgId: c.$3, tvgName: c.$4);
    if (m != null) out.add((c.$1, m.channel.guideId, m.channel.xmltvId, m.score));
  }
  return out;
}

/// Plain-English reason a guide could not be read.
String friendlyGuideError(Object e) {
  final msg = '$e';
  if (msg.contains('empty_guide')) {
    return 'That address did not give a TV guide (it was empty or not XML).';
  }
  if (msg.contains('zip_without_xml')) {
    return 'The zip file has no XML guide inside.';
  }
  return friendlyEpgErrorMessage(e);
}
