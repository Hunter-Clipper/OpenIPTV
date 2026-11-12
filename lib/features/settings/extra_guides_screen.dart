import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_iptv/core/services/guide_assignment_service.dart';
import 'package:open_iptv/core/services/guide_fetch.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/core/storage/database.dart';
import 'package:open_iptv/core/storage/preferences.dart';
import 'package:open_iptv/features/live_tv/change_guide_screen.dart';
import 'package:open_iptv/shared/utils/snack_bar_utils.dart';
import 'package:open_iptv/shared/widgets/settings_group.dart';
import 'package:open_iptv/shared/widgets/tv_focusable.dart';
import 'package:path_provider/path_provider.dart';

/// Settings → Playlists & Guides → Extra Guides (#40): TV guide files the user adds,
/// used for channels the playlist's own guide does not cover.
class ExtraGuidesScreen extends ConsumerStatefulWidget {
  const ExtraGuidesScreen({super.key});

  @override
  ConsumerState<ExtraGuidesScreen> createState() => _ExtraGuidesScreenState();
}

class _ExtraGuidesScreenState extends ConsumerState<ExtraGuidesScreen> {
  AppPreferences? _prefs;
  // Channels linked per guide reference: (automatic, by hand).
  Map<String, (int, int)> _links = const {};
  String? _status; // what a running update is doing

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final prefs = await ref.read(appPreferencesProvider.future);
    final links = await ref.read(appDatabaseProvider).getGuideLinks();
    final counts = <String, (int, int)>{};
    for (final l in links) {
      final ref = l.guideRef;
      if (ref == null) continue;
      final (a, m) = counts[ref] ?? (0, 0);
      counts[ref] = l.kind == 'auto' ? (a + 1, m) : (a, m + 1);
    }
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _links = counts;
    });
  }

  static const _modes = <(String, String, String)>[
    (
      'explicit',
      'Explicit',
      'Only when the channel\'s guide ID is exactly the same as the guide\'s. '
          'Safest; channels without an ID are left alone.'
    ),
    (
      'standard',
      'Standard',
      'The guide ID, or exactly the same channel name. US local stations '
          'are matched by call sign.'
    ),
    (
      'optimistic',
      'Optimistic',
      'Also channels whose names are only alike. Finds more, but some '
          'guesses will be wrong; you can fix any in Review Guide Matches.'
    ),
  ];

  String _modeTitle(String mode) =>
      _modes.firstWhere((m) => m.$1 == mode, orElse: () => _modes[1]).$2;

  Future<void> _pickMode(AppPreferences prefs) async {
    final current = prefs.guideMatchMode;
    final chosen = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Matching Mode'),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final m in _modes)
              TvActivatable(
                onTap: () => Navigator.of(ctx).pop(m.$1),
                builder: (tap) => ListTile(
                  leading: Icon(m.$1 == current
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded),
                  title: Text(m.$2),
                  subtitle: Text(m.$3),
                  onTap: tap,
                ),
              ),
          ],
        ),
      ),
    );
    if (chosen == null || chosen == current) return;
    await prefs.setGuideMatchMode(chosen);
    await _update(refreshLists: false, force: false);
  }

  Future<void> _update({bool refreshLists = true, bool force = true}) async {
    if (_status != null) {
      // An update is on screen: this change is applied by one more run right
      // after it (the service queues it), not dropped.
      unawaited(ref
          .read(guideAssignmentProvider)
          .sync(refreshLists: refreshLists, force: force));
      showSnackBarMessage(context, 'Will apply this as soon as the current update finishes.');
      return;
    }
    setState(() => _status = 'Starting…');
    try {
      final r = await ref.read(guideAssignmentProvider).sync(
            refreshLists: refreshLists,
            force: force,
            onProgress: (m) {
              if (mounted) setState(() => _status = m);
            },
          );
      ref.read(guideRevisionProvider.notifier).state++;
      if (mounted) {
        showSnackBarMessage(
            context,
            r.errors.isEmpty
                ? 'Guides updated: ${r.linked} channels linked.'
                : r.errors.first);
      }
    } catch (_) {
      if (mounted) showSnackBarMessage(context, "The guides couldn't be updated.");
    } finally {
      if (mounted) setState(() => _status = null);
      unawaited(_load());
    }
  }

  Future<void> _add() async {
    final entry = await showDialog<({String name, String url})>(
      context: context,
      useRootNavigator: true,
      builder: (_) => const _AddGuideDialog(),
    );
    if (entry == null || !mounted) return;
    setState(() => _status = 'Checking the guide…');
    final db = ref.read(appDatabaseProvider);
    try {
      final existing = await db.getExtraGuides();
      if (existing.any((g) => g.url.trim() == entry.url.trim())) {
        if (!mounted) return;
        setState(() => _status = null);
        showSnackBarMessage(context, 'That guide is already in your list.');
        return;
      }
      final tmp = (await getTemporaryDirectory()).path;
      final list = await fetchGuideChannels(entry.url, tmp);
      final id = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
      await db.upsertExtraGuide(ExtraGuidesCompanion.insert(
        id: id,
        name: entry.name,
        url: entry.url,
        sortOrder: Value(existing.length),
      ));
      await db.replaceGuideChannels('ext:$id', list);
      await db.setExtraGuideStatus(id,
          updated: DateTime.now(), count: list.length);
      if (!mounted) return;
      setState(() => _status = null);
      showSnackBarMessage(context,
          'Added "${entry.name}" with ${list.length} channels. Matching channels…');
      await _update(refreshLists: false, force: false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = null);
      showSnackBarMessage(context, friendlyGuideError(e));
    }
  }

  Future<void> _move(ExtraGuideRow g, int delta) async {
    final db = ref.read(appDatabaseProvider);
    final all = await db.getExtraGuides();
    final i = all.indexWhere((x) => x.id == g.id);
    final j = i + delta;
    if (i < 0 || j < 0 || j >= all.length) return;
    final order = [...all];
    order.insert(j, order.removeAt(i));
    for (final (k, e) in order.indexed) {
      await db.upsertExtraGuide(ExtraGuidesCompanion(
          id: Value(e.id),
          name: Value(e.name),
          url: Value(e.url),
          sortOrder: Value(k)));
    }
    await _update(refreshLists: false, force: false);
  }

  Future<void> _toggle(ExtraGuideRow g) async {
    await ref.read(appDatabaseProvider).upsertExtraGuide(ExtraGuidesCompanion(
        id: Value(g.id),
        name: Value(g.name),
        url: Value(g.url),
        enabled: Value(!g.enabled)));
    await _update(refreshLists: false, force: false);
  }

  Future<void> _remove(ExtraGuideRow g) async {
    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (c) => AlertDialog(
        title: Text('Remove "${g.name}"?'),
        content: const Text(
            'Channels that were matched to this guide lose its programmes. '
            'Your playlists are not affected.'),
        actions: [
          TvActivatable(
            autofocus: true,
            onTap: () => Navigator.of(c).pop(false),
            builder: (t) => TextButton(onPressed: t, child: const Text('Cancel')),
          ),
          TvActivatable(
            onTap: () => Navigator.of(c).pop(true),
            builder: (t) => FilledButton(onPressed: t, child: const Text('Remove')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(appDatabaseProvider).deleteExtraGuide(g.id);
    ref.read(guideRevisionProvider.notifier).state++;
    await _update(refreshLists: false, force: false);
  }

  void _options(ExtraGuideRow g) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              autofocus: true,
              leading: const Icon(Icons.sync_rounded),
              title: const Text('Update Now'),
              onTap: () {
                Navigator.of(sheet).pop();
                unawaited(_update());
              },
            ),
            ListTile(
              leading: Icon(g.enabled
                  ? Icons.pause_circle_outline
                  : Icons.play_circle_outline),
              title: Text(g.enabled ? 'Turn Off' : 'Turn On'),
              onTap: () {
                Navigator.of(sheet).pop();
                unawaited(_toggle(g));
              },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_upward_rounded),
              title: const Text('Move Up (Used First)'),
              onTap: () {
                Navigator.of(sheet).pop();
                unawaited(_move(g, -1));
              },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_downward_rounded),
              title: const Text('Move Down'),
              onTap: () {
                Navigator.of(sheet).pop();
                unawaited(_move(g, 1));
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error),
              title: const Text('Remove'),
              onTap: () {
                Navigator.of(sheet).pop();
                unawaited(_remove(g));
              },
            ),
          ],
        ),
      ),
    );
  }

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    return '${d.inDays} d ago';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prefs = _prefs;
    final guides = ref.watch(_extraGuidesProvider).valueOrNull ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('Extra Guides')),
      body: prefs == null
          ? const Center(child: CircularProgressIndicator())
          : TvFollowFocus(focusFirst: true, child: SingleChildScrollView(
              padding: EdgeInsets.only(
                  bottom: 32 + MediaQuery.paddingOf(context).bottom),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_status != null)
                    ListTile(
                      leading: const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 3)),
                      title: Text(_status!),
                    ),
                  SettingsGroup(
                    title: 'Fill in missing guides',
                    description:
                        "Your playlist's own TV guide is always used first. "
                        'A channel it does not cover is matched by name to the '
                        'guides you add here. You can also pick a guide for any '
                        'channel yourself: hold OK (or long-press) a channel → '
                        'Change Guide.\n\n'
                        'Works with .xml, .xml.gz and zipped guides, as long as '
                        'they unpack to XML. OpenIPTV does not provide guides, '
                        'but community sites publish them: a web search for '
                        '"XMLTV EPG" is a good place to start. 😉',
                    children: const [],
                  ),
                  SettingsGroup(
                    title: 'Your Guides',
                    description: guides.isEmpty
                        ? 'None yet. Guides higher in the list are used first.'
                        : 'Guides higher in the list are used first.',
                    children: [
                      for (final g in guides) _guideTile(g, theme),
                      TvActivatable(
                        onTap: _status == null ? _add : null,
                        builder: (tap) => ListTile(
                          leading: const IconBadge(icon: Icons.add_rounded),
                          title: const Text('Add a Guide'),
                          subtitle: Text('A web address ending in .xml, .xml.gz or .zip',
                              style: theme.textTheme.bodySmall),
                          onTap: tap,
                        ),
                      ),
                    ],
                  ),
                  SettingsGroup(
                    title: 'Matching',
                    children: [
                      TvActivatable(
                        onTap: () async {
                          await prefs.setSmartGuideAssign(!prefs.smartGuideAssign);
                          await _update(refreshLists: false, force: false);
                        },
                        builder: (tap) => SwitchListTile(
                          secondary: const IconBadge(icon: Icons.auto_fix_high_rounded),
                          title: const Text('Match Channels Automatically'),
                          subtitle: Text(
                              'Channels without a guide are matched to the '
                              'guides above. Never changes a channel that '
                              'already has a guide.',
                              style: theme.textTheme.bodySmall),
                          value: prefs.smartGuideAssign,
                          onChanged: tap == null ? null : (_) => tap(),
                        ),
                      ),
                      TvActivatable(
                        onTap: () => _pickMode(prefs),
                        builder: (tap) => ListTile(
                          leading: const IconBadge(icon: Icons.tune_rounded),
                          title: const Text('Matching Mode'),
                          subtitle: Text(_modeTitle(prefs.guideMatchMode),
                              style: theme.textTheme.bodySmall),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: tap,
                        ),
                      ),
                      TvActivatable(
                        onTap: _status == null ? () => _update() : null,
                        builder: (tap) => ListTile(
                          leading: const IconBadge(icon: Icons.sync_rounded),
                          title: const Text('Match and Update Now'),
                          onTap: tap,
                        ),
                      ),
                      TvActivatable(
                        onTap: () async {
                          await Navigator.of(context).push(MaterialPageRoute<void>(
                              builder: (_) => const _GuideLinksScreen()));
                          unawaited(_load());
                        },
                        builder: (tap) => ListTile(
                          leading: const IconBadge(icon: Icons.link_rounded),
                          title: const Text('Review Guide Matches'),
                          subtitle: Text(_linkSummary(),
                              style: theme.textTheme.bodySmall),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: tap,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )),
    );
  }

  String _linkSummary() {
    var auto = 0, manual = 0;
    for (final (a, m) in _links.values) {
      auto += a;
      manual += m;
    }
    if (auto == 0 && manual == 0) return 'No channels matched yet';
    return '$auto matched automatically · $manual chosen by you';
  }

  Widget _guideTile(ExtraGuideRow g, ThemeData theme) {
    final (auto, manual) = _links['ext:${g.id}'] ?? (0, 0);
    final String line;
    if (g.lastError != null) {
      line = g.lastUpdated == null
          ? g.lastError!
          : '${g.lastError}\nLast read ${_ago(g.lastUpdated!)}.';
    } else if (g.lastUpdated == null) {
      line = 'Not read yet';
    } else {
      line = '${g.channelCount} channels · ${auto + manual} used · '
          'read ${_ago(g.lastUpdated!)}${g.enabled ? '' : ' · off'}';
    }
    return TvActivatable(
      onTap: () => _options(g),
      builder: (tap) => ListTile(
        leading: g.lastError != null
            ? Icon(Icons.error_outline, color: theme.colorScheme.error)
            : IconBadge(
                icon: g.enabled ? Icons.event_note_outlined : Icons.pause_rounded),
        title: Text(g.name),
        subtitle: Text(line, style: theme.textTheme.bodySmall),
        onTap: tap,
      ),
    );
  }
}

final _extraGuidesProvider = StreamProvider.autoDispose<List<ExtraGuideRow>>(
    (ref) => ref.watch(appDatabaseProvider).watchExtraGuides());

class _AddGuideDialog extends StatefulWidget {
  const _AddGuideDialog();

  @override
  State<_AddGuideDialog> createState() => _AddGuideDialogState();
}

class _AddGuideDialogState extends State<_AddGuideDialog> {
  final _name = TextEditingController();
  final _url = TextEditingController();
  String? _problem;

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    super.dispose();
  }

  void _add() {
    final url = _url.text.trim();
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https')) || uri.host.isEmpty) {
      setState(() => _problem = 'Enter the guide address, starting with http:// or https://');
      return;
    }
    final name = _name.text.trim().isEmpty ? uri.host : _name.text.trim();
    Navigator.of(context).pop((name: name, url: url));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add a Guide'),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TvTextFieldGate(
            autofocus: true,
            builder: (context, node) => TextField(
              focusNode: node,
              controller: _name,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Name (optional)'),
            ),
          ),
          const SizedBox(height: 12),
          TvTextFieldGate(
            builder: (context, node) => TextField(
              focusNode: node,
              controller: _url,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                  labelText: 'Guide address', errorText: _problem),
              onSubmitted: (_) => _add(),
            ),
          ),
        ],
      ),
      actions: [
        TvActivatable(
          onTap: () => Navigator.of(context).pop(),
          builder: (t) => TextButton(onPressed: t, child: const Text('Cancel')),
        ),
        TvActivatable(
          onTap: _add,
          builder: (t) => FilledButton(onPressed: t, child: const Text('Add')),
        ),
      ],
    );
  }
}

/// Every channel with a smart or manual guide, so a wrong match is easy to
/// find and fix.
class _GuideLinksScreen extends ConsumerStatefulWidget {
  const _GuideLinksScreen();

  @override
  ConsumerState<_GuideLinksScreen> createState() => _GuideLinksScreenState();
}

class _GuideLinksScreenState extends ConsumerState<_GuideLinksScreen> {
  List<GuideLinkRow>? _links;
  Map<String, String> _names = const {};
  Map<String, String> _guideNames = const {};

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final db = ref.read(appDatabaseProvider);
    final links = await db.getGuideLinks();
    final names = {for (final c in await db.channelBriefs()) c.id: c.name};
    final picker = await ref
        .read(guideAssignmentProvider)
        .loadPicker(withMatcher: false);
    links.sort((a, b) => (names[a.channelId] ?? '')
        .toLowerCase()
        .compareTo((names[b.channelId] ?? '').toLowerCase()));
    if (!mounted) return;
    setState(() {
      _links = links;
      _names = names;
      _guideNames = picker.guideNames;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final links = _links;
    return Scaffold(
      appBar: AppBar(title: const Text('Guide Matches')),
      body: links == null
          ? const Center(child: CircularProgressIndicator())
          : links.isEmpty
              ? const Center(
                  child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                      'No channels are matched to an extra guide yet. Pick one '
                      'for a channel with hold OK → Change Guide, or add a '
                      'guide and let OpenIPTV match channels for you.',
                      textAlign: TextAlign.center),
                ))
              : TvFollowFocus(focusFirst: true, child: ListView.builder(
                  padding: EdgeInsets.only(
                      bottom: 32 + MediaQuery.paddingOf(context).bottom),
                  itemCount: links.length,
                  itemBuilder: (context, i) {
                    final l = links[i];
                    final name = _names[l.channelId] ?? l.channelId;
                    final what = l.xmltvId == null
                        ? 'No guide (your choice)'
                        : '${l.xmltvId} · ${_guideNames[l.guideRef] ?? 'guide'}'
                            ' · ${l.kind == 'manual' ? 'your choice' : 'automatic'}';
                    return TvActivatable(
                      onTap: () async {
                        await Navigator.of(context).push(MaterialPageRoute<void>(
                            builder: (_) => ChangeGuideScreen(
                                channelId: l.channelId, channelName: name)));
                        unawaited(_load());
                      },
                      builder: (tap) => ListTile(
                        leading: Icon(
                            l.kind == 'manual'
                                ? Icons.person_outline
                                : Icons.auto_fix_high_rounded,
                            color: theme.colorScheme.primary),
                        title: Text(name),
                        subtitle: Text(what, style: theme.textTheme.bodySmall),
                        onTap: tap,
                      ),
                    );
                  },
                )),
    );
  }
}
