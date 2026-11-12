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
  GuideAssignmentService({required this.db, this.tempDir});

  final AppDatabase db;

  /// Where zipped guides are unpacked (tests point it somewhere harmless).
  final Future<String> Function()? tempDir;

  static Future<GuideSyncResult>? _running;

  /// Runs a sync; a second call while one is running joins it.
  Future<GuideSyncResult> sync({
    void Function(String)? onProgress,
    bool refreshLists = true,
  }) {
    return _running ??= _sync(onProgress, refreshLists).whenComplete(() {
      _running = null;
    });
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

  /// A matcher over every stored guide channel, with each guide's name, for
  /// the Change Guide picker. Guides in priority order.
  Future<GuidePicker> loadPicker() async {
    final guides = await _guides();
    final order = {for (final (i, g) in guides.indexed) g.ref: i};
    final rows = [
      for (final r in await db.getGuideChannels())
        if (order.containsKey(r.guideRef)) r,
    ]..sort((a, b) => order[a.guideRef]!.compareTo(order[b.guideRef]!));
    return GuidePicker(
      GuideMatcher([
        for (final r in rows)
          GuideChannel(
            guideId: r.guideRef,
            xmltvId: r.xmltvId,
            name: r.name.isEmpty ? nameFromGuideId(r.xmltvId) : r.name,
          ),
      ]),
      {for (final g in guides) g.ref: g.name},
    );
  }

  Future<GuideSyncResult> _sync(
      void Function(String)? onProgress, bool refreshLists) async {
    final sw = Stopwatch()..start();
    final errors = <String>[];
    final prefs = AppPreferences(await SharedPreferences.getInstance());
    final tmp = tempDir != null
        ? await tempDir!()
        : (await getTemporaryDirectory()).path;
    final guides = await _guides();
    final hasExtras = guides.any((g) => g.extraId != null);
    final manual = await db.manualLinkedChannelIds();

    // 1. Channel lists of every guide.
    if (refreshLists) {
      for (final g in guides) {
        onProgress?.call('Reading ${g.name}…');
        try {
          final list = await fetchGuideChannels(g.url, tmp);
          await db.replaceGuideChannels(g.ref, list);
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

    // 2. Smart assignment.
    final order = {for (final (i, g) in guides.indexed) g.ref: i};
    final rows = [
      for (final r in await db.getGuideChannels())
        if (order.containsKey(r.guideRef)) r,
    ]..sort((a, b) => order[a.guideRef]!.compareTo(order[b.guideRef]!));
    final briefs = await db.channelBriefs();

    var auto = const <GuideLinksCompanionArgs>[];
    if (prefs.smartGuideAssign && rows.isNotEmpty) {
      onProgress?.call('Matching channels to guides…');
      // Channels the playlist's own guide lists keep it.
      final ownIds = {
        for (final r in rows)
          if (r.guideRef.startsWith('src:')) r.xmltvId,
      };
      final candidates = [
        for (final c in briefs)
          if (!manual.contains(c.id) &&
              !(c.tvgId != null &&
                  c.tvgId!.isNotEmpty &&
                  ownIds.contains(c.tvgId)))
            (c.id, c.name, c.tvgId, c.tvgName),
      ];
      final guideRows = [
        for (final r in rows) (r.guideRef, r.xmltvId, r.name),
      ];
      final found = await Isolate.run(() => _matchAll(guideRows, candidates));
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
    await db.replaceAutoLinks(auto);

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
    final maxCatchup = await _maxCatchupDays();
    var imported = 0;
    for (final g in guides) {
      final wanted = byGuide[g.ref];
      if (wanted == null || wanted.isEmpty) continue;
      onProgress?.call('Loading ${g.name} (${wanted.length} channels)…');
      try {
        final ps = await fetchGuideProgrammes(
          g.url,
          tmp,
          wanted.keys.toSet(),
          pastWindow: maxCatchup > 0
              ? Duration(days: maxCatchup)
              : const Duration(hours: 1),
          daysAhead: days,
          keepDescriptions: keepDesc,
        );
        if (ps.isEmpty) {
          errors.add('${g.name}: no programmes for the linked channels');
          continue;
        }
        imported += await _store(ps, wanted);
      } catch (e) {
        debugPrint('[Guides] ${g.name}: ${redactUrl('$e')}');
        errors.add('${g.name}: ${friendlyGuideError(e)}');
      }
    }
    await db.deleteOldProgrammes();
    await db.deleteProgrammesStartingAfter(
        DateTime.now().add(Duration(days: days)));
    await db.compact();
    debugPrint('[Guides] sync: ${guides.length} guides, ${auto.length} auto '
        'links, ${manual.length} manual, $imported programmes, '
        '${errors.length} problems, ${sw.elapsedMilliseconds} ms');
    return GuideSyncResult(
      guides: guides.length,
      linked: auto.length + manual.length,
      programmes: imported,
      errors: errors,
    );
  }

  Future<int> _maxCatchupDays() async {
    var most = 0;
    for (final s in await db.getAllSources()) {
      final d = await db.getMaxCatchupDaysForSource(s.id);
      if (d > most) most = d;
    }
    return most;
  }

  Future<int> _store(
      List<Programme> ps, Map<String, List<String>> wanted) async {
    final out = <Programme>[
      for (final p in ps)
        for (final id in wanted[p.channelId] ?? const <String>[])
          Programme(
            channelId: id,
            start: p.start,
            end: p.end,
            title: p.title,
            description: p.description,
            category: p.category,
            episodeNum: p.episodeNum,
          ),
    ];
    const batch = 5000;
    for (var i = 0; i < out.length; i += batch) {
      await db.upsertProgrammes(out.sublist(i, (i + batch).clamp(0, out.length)));
    }
    return out.length;
  }

  /// Links [channelId] to one guide channel by the user's choice. Run [sync]
  /// (with `refreshLists: false`) afterwards to load its programmes.
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

/// What the Change Guide screen searches.
class GuidePicker {
  const GuidePicker(this.matcher, this.guideNames);
  final GuideMatcher matcher;

  /// Guide reference (`src:…` / `ext:…`) → the name the user knows it by.
  final Map<String, String> guideNames;
  bool get isEmpty => matcher.length == 0;
}

/// Bumped whenever guide data changed under the screens (a sync finished, a
/// link was edited), so guide rows and now/next lines load again.
final guideRevisionProvider = StateProvider<int>((ref) => 0);

/// Matching of every candidate in one pass; runs in an isolate.
List<(String, String, String, double)> _matchAll(
  List<(String, String, String)> guideRows,
  List<(String, String, String?, String?)> candidates,
) {
  final matcher = GuideMatcher([
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
