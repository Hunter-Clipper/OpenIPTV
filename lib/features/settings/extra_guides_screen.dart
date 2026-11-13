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
import 'package:open_iptv/l10n/gen/app_localizations.dart';
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

  final _scroll = ScrollController();
  bool _wasBusy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    // Any update counts, including one started elsewhere (after a playlist
    // refresh, say): hold the buttons while it runs, release them at the end.
    GuideAssignmentService.busy.addListener(_onBusyChanged);
    if (GuideAssignmentService.busy.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _onBusyChanged());
    }
  }

  @override
  void dispose() {
    GuideAssignmentService.busy.removeListener(_onBusyChanged);
    _scroll.dispose();
    super.dispose();
  }

  bool get _busy => _status != null || GuideAssignmentService.busy.value;

  void _onBusyChanged() {
    if (!mounted) return;
    final running = GuideAssignmentService.busy.value;
    if (running && !_wasBusy) {
      _wasBusy = true;
      setState(() {});
      _announceWork();
    } else if (!running && _wasBusy) {
      _wasBusy = false;
      // Never stay stuck on a leftover progress message.
      setState(() => _status = null);
      unawaited(_load());
    }
  }

  /// Makes it plain something is happening: back to the top of the page,
  /// where the progress line is, and a message.
  void _announceWork() {
    if (_scroll.hasClients) {
      _scroll.animateTo(0,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
    showSnackBarMessage(
        context, AppLocalizations.of(context).extraGuidesWorkingToast);
  }

  Widget _dim(Widget child) => DimWhen(dimmed: _busy, child: child);

  Future<void> _load() async {
    // Also called when an update finishes, which may be after leaving.
    if (!mounted) return;
    final prefs = await ref.read(appPreferencesProvider.future);
    if (!mounted) return;
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

  static List<(String, String, String)> _modes(AppLocalizations l10n) => [
        (
          'explicit',
          l10n.extraGuidesModeExplicit,
          l10n.extraGuidesModeExplicitDesc,
        ),
        (
          'standard',
          l10n.extraGuidesModeStandard,
          l10n.extraGuidesModeStandardDesc,
        ),
        (
          'optimistic',
          l10n.extraGuidesModeOptimistic,
          l10n.extraGuidesModeOptimisticDesc,
        ),
      ];

  String _modeTitle(AppLocalizations l10n, String mode) {
    final modes = _modes(l10n);
    return modes.firstWhere((m) => m.$1 == mode, orElse: () => modes[1]).$2;
  }

  Future<void> _pickMode(AppPreferences prefs) async {
    final current = prefs.guideMatchMode;
    final modes = _modes(AppLocalizations.of(context));
    final title = AppLocalizations.of(context).extraGuidesMatchingModeTitle;
    final chosen = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final m in modes)
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
    final l10n = AppLocalizations.of(context);
    if (_status != null) {
      // An update is on screen: this change is applied by one more run right
      // after it (the service queues it), not dropped.
      unawaited(ref
          .read(guideAssignmentProvider)
          .sync(refreshLists: refreshLists, force: force));
      showSnackBarMessage(context, l10n.extraGuidesQueued);
      return;
    }
    setState(() => _status = l10n.extraGuidesStarting);
    try {
      final r = await ref.read(guideAssignmentProvider).sync(
            refreshLists: refreshLists,
            force: force,
            onProgress: (m) {
              if (mounted && GuideAssignmentService.busy.value) {
                setState(() => _status = m);
              }
            },
          );
      ref.read(guideRevisionProvider.notifier).state++;
      if (mounted) {
        showSnackBarMessage(
            context,
            r.errors.isEmpty
                ? l10n.extraGuidesUpdated(r.linked)
                : r.errors.first);
      }
    } catch (_) {
      if (mounted) showSnackBarMessage(context, l10n.extraGuidesUpdateFailed);
    } finally {
      if (mounted) setState(() => _status = null);
      unawaited(_load());
    }
  }

  Future<void> _add() async {
    final l10n = AppLocalizations.of(context);
    final entry = await showDialog<({String name, String url})>(
      context: context,
      useRootNavigator: true,
      builder: (_) => const _AddGuideDialog(),
    );
    if (entry == null || !mounted) return;
    setState(() => _status = l10n.extraGuidesChecking);
    final db = ref.read(appDatabaseProvider);
    try {
      final existing = await db.getExtraGuides();
      if (existing.any((g) => g.url.trim() == entry.url.trim())) {
        if (!mounted) return;
        setState(() => _status = null);
        showSnackBarMessage(context, l10n.extraGuidesAlreadyAdded);
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
      showSnackBarMessage(
          context, l10n.extraGuidesAdded(entry.name, list.length));
      await _update(refreshLists: false, force: false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = null);
      showSnackBarMessage(context, friendlyGuideError(e));
    }
  }

  /// Changes a guide's name and/or address. A new address is read first (so
  /// a typo is caught before it replaces a working guide), then the guide is
  /// re-read and the channels re-matched.
  Future<void> _edit(ExtraGuideRow g) async {
    final l10n = AppLocalizations.of(context);
    final entry = await showDialog<({String name, String url})>(
      context: context,
      useRootNavigator: true,
      builder: (_) => _AddGuideDialog(initialName: g.name, initialUrl: g.url),
    );
    if (entry == null || !mounted) return;
    final db = ref.read(appDatabaseProvider);
    final addressChanged = entry.url.trim() != g.url.trim();
    if (!addressChanged && entry.name == g.name) return;
    try {
      if (!addressChanged) {
        await db.upsertExtraGuide(ExtraGuidesCompanion(
            id: Value(g.id), name: Value(entry.name), url: Value(g.url)));
        if (mounted) showSnackBarMessage(context, l10n.extraGuidesEdited(entry.name));
        return;
      }
      final others = await db.getExtraGuides();
      if (others.any((o) => o.id != g.id && o.url.trim() == entry.url.trim())) {
        if (mounted) showSnackBarMessage(context, l10n.extraGuidesAlreadyAdded);
        return;
      }
      setState(() => _status = l10n.extraGuidesChecking);
      final tmp = (await getTemporaryDirectory()).path;
      final list = await fetchGuideChannels(entry.url, tmp);
      await db.upsertExtraGuide(ExtraGuidesCompanion(
          id: Value(g.id), name: Value(entry.name), url: Value(entry.url)));
      await db.replaceGuideChannels('ext:${g.id}', list);
      await db.setExtraGuideStatus(g.id,
          updated: DateTime.now(), count: list.length);
      if (!mounted) return;
      setState(() => _status = null);
      showSnackBarMessage(context, l10n.extraGuidesEdited(entry.name));
      // The channels this guide covers have changed: match again.
      await _update(refreshLists: false, force: true);
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
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (c) => AlertDialog(
        title: Text(l10n.extraGuidesRemoveTitle(g.name)),
        content: Text(l10n.extraGuidesRemoveBody),
        actions: [
          TvActivatable(
            autofocus: true,
            onTap: () => Navigator.of(c).pop(false),
            builder: (t) =>
                TextButton(onPressed: t, child: Text(l10n.commonCancel)),
          ),
          TvActivatable(
            onTap: () => Navigator.of(c).pop(true),
            builder: (t) =>
                FilledButton(onPressed: t, child: Text(l10n.extraGuidesRemove)),
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
    final l10n = AppLocalizations.of(context);
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
              title: Text(l10n.extraGuidesUpdateNow),
              onTap: () {
                Navigator.of(sheet).pop();
                unawaited(_update());
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(l10n.extraGuidesEditTitle),
              onTap: () {
                Navigator.of(sheet).pop();
                unawaited(_edit(g));
              },
            ),
            ListTile(
              leading: Icon(g.enabled
                  ? Icons.pause_circle_outline
                  : Icons.play_circle_outline),
              title: Text(
                  g.enabled ? l10n.extraGuidesTurnOff : l10n.extraGuidesTurnOn),
              onTap: () {
                Navigator.of(sheet).pop();
                unawaited(_toggle(g));
              },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_upward_rounded),
              title: Text(l10n.extraGuidesMoveUp),
              onTap: () {
                Navigator.of(sheet).pop();
                unawaited(_move(g, -1));
              },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_downward_rounded),
              title: Text(l10n.extraGuidesMoveDown),
              onTap: () {
                Navigator.of(sheet).pop();
                unawaited(_move(g, 1));
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error),
              title: Text(l10n.extraGuidesRemove),
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

  static String _ago(AppLocalizations l10n, DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return l10n.guideDataAgoJustNow;
    if (d.inMinutes < 60) return l10n.guideDataAgoMinutes(d.inMinutes);
    if (d.inHours < 24) return l10n.guideDataAgoHours(d.inHours);
    return l10n.guideDataAgoDays(d.inDays);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final prefs = _prefs;
    final guides = ref.watch(_extraGuidesProvider).valueOrNull ?? const [];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.extraGuidesTitle)),
      body: prefs == null
          ? const Center(child: CircularProgressIndicator())
          : TvFollowFocus(
              focusFirst: true,
              child: SingleChildScrollView(
                controller: _scroll,
                padding: EdgeInsets.only(
                    bottom: 32 + MediaQuery.paddingOf(context).bottom),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_busy)
                      ListTile(
                        leading: const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 3)),
                        title: Text(_status ?? l10n.extraGuidesStarting),
                      ),
                    SettingsGroup(
                      title: l10n.extraGuidesFillTitle,
                      description: l10n.extraGuidesFillDescription,
                      children: const [],
                    ),
                    SettingsGroup(
                      title: l10n.extraGuidesYourGuides,
                      description: guides.isEmpty
                          ? l10n.extraGuidesListHintEmpty
                          : l10n.extraGuidesListHint,
                      children: [
                        for (final g in guides) _guideTile(g, theme),
                        _dim(TvActivatable(
                          onTap: _busy ? null : _add,
                          builder: (tap) => ListTile(
                            enabled: !_busy,
                            leading: const IconBadge(icon: Icons.add_rounded),
                            title: Text(l10n.extraGuidesAddTitle),
                            subtitle: Text(l10n.extraGuidesAddSubtitle,
                                style: theme.textTheme.bodySmall),
                            onTap: tap,
                          ),
                        )),
                      ],
                    ),
                    SettingsGroup(
                      title: l10n.extraGuidesMatchingGroup,
                      children: [
                        _dim(TvActivatable(
                          onTap: _busy
                              ? null
                              : () async {
                                  await prefs.setSmartGuideAssign(
                                      !prefs.smartGuideAssign);
                                  await _update(
                                      refreshLists: false, force: false);
                                },
                          builder: (tap) => SwitchListTile(
                            secondary: const IconBadge(
                                icon: Icons.auto_fix_high_rounded),
                            title: Text(l10n.extraGuidesAutoMatchTitle),
                            subtitle: Text(l10n.extraGuidesAutoMatchSubtitle,
                                style: theme.textTheme.bodySmall),
                            value: prefs.smartGuideAssign,
                            onChanged: tap == null ? null : (_) => tap(),
                          ),
                        )),
                        _dim(TvActivatable(
                          onTap: _busy ? null : () => _pickMode(prefs),
                          builder: (tap) => ListTile(
                            enabled: !_busy,
                            leading: const IconBadge(icon: Icons.tune_rounded),
                            title: Text(l10n.extraGuidesMatchingModeTitle),
                            subtitle: Text(
                                _modeTitle(l10n, prefs.guideMatchMode),
                                style: theme.textTheme.bodySmall),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: tap,
                          ),
                        )),
                        _dim(TvActivatable(
                          onTap: _busy ? null : () => _update(),
                          builder: (tap) => ListTile(
                            enabled: !_busy,
                            leading: const IconBadge(icon: Icons.sync_rounded),
                            title: Text(l10n.extraGuidesMatchAndUpdate),
                            onTap: tap,
                          ),
                        )),
                        TvActivatable(
                          onTap: () async {
                            await Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                    builder: (_) => const _GuideLinksScreen()));
                            unawaited(_load());
                          },
                          builder: (tap) => ListTile(
                            leading: const IconBadge(icon: Icons.link_rounded),
                            title: Text(l10n.extraGuidesReviewMatchesTitle),
                            subtitle: Text(_linkSummary(l10n),
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

  String _linkSummary(AppLocalizations l10n) {
    var auto = 0, manual = 0;
    for (final (a, m) in _links.values) {
      auto += a;
      manual += m;
    }
    if (auto == 0 && manual == 0) return l10n.extraGuidesNoMatchesYet;
    return l10n.extraGuidesMatchSummary(auto, manual);
  }

  Widget _guideTile(ExtraGuideRow g, ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    final (auto, manual) = _links['ext:${g.id}'] ?? (0, 0);
    final String line;
    if (g.lastError != null) {
      line = g.lastUpdated == null
          ? g.lastError!
          : l10n.extraGuidesLastError(g.lastError!, _ago(l10n, g.lastUpdated!));
    } else if (g.lastUpdated == null) {
      line = l10n.extraGuidesNotRead;
    } else {
      final when = _ago(l10n, g.lastUpdated!);
      line = g.enabled
          ? l10n.extraGuidesTileLine(g.channelCount, auto + manual, when)
          : l10n.extraGuidesTileLineOff(g.channelCount, auto + manual, when);
    }
    return _dim(TvActivatable(
      onTap: _busy ? null : () => _options(g),
      builder: (tap) => ListTile(
        enabled: !_busy,
        leading: g.lastError != null
            ? Icon(Icons.error_outline, color: theme.colorScheme.error)
            : IconBadge(
                icon: g.enabled
                    ? Icons.event_note_outlined
                    : Icons.pause_rounded),
        title: Text(g.name),
        subtitle: Text(line, style: theme.textTheme.bodySmall),
        onTap: tap,
      ),
    ));
  }
}

final _extraGuidesProvider = StreamProvider.autoDispose<List<ExtraGuideRow>>(
    (ref) => ref.watch(appDatabaseProvider).watchExtraGuides());

class _AddGuideDialog extends StatefulWidget {
  const _AddGuideDialog({this.initialName, this.initialUrl});

  /// Set when editing an existing guide.
  final String? initialName;
  final String? initialUrl;

  @override
  State<_AddGuideDialog> createState() => _AddGuideDialogState();
}

class _AddGuideDialogState extends State<_AddGuideDialog> {
  late final _name = TextEditingController(text: widget.initialName);
  late final _url = TextEditingController(text: widget.initialUrl);
  String? _problem;
  bool get _editing => widget.initialUrl != null;

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    super.dispose();
  }

  void _add() {
    final url = _url.text.trim();
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !(uri.isScheme('http') || uri.isScheme('https')) ||
        uri.host.isEmpty) {
      setState(() =>
          _problem = AppLocalizations.of(context).extraGuidesAddressInvalid);
      return;
    }
    final name = _name.text.trim().isEmpty ? uri.host : _name.text.trim();
    Navigator.of(context).pop((name: name, url: url));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(_editing ? l10n.extraGuidesEditTitle : l10n.extraGuidesAddTitle),
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
              decoration: InputDecoration(labelText: l10n.extraGuidesNameLabel),
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
                  labelText: l10n.extraGuidesAddressLabel, errorText: _problem),
              onSubmitted: (_) => _add(),
            ),
          ),
        ],
      ),
      actions: [
        TvActivatable(
          onTap: () => Navigator.of(context).pop(),
          builder: (t) =>
              TextButton(onPressed: t, child: Text(l10n.commonCancel)),
        ),
        TvActivatable(
          onTap: _add,
          builder: (t) => FilledButton(
              onPressed: t,
              child: Text(_editing
                  ? l10n.extraGuidesSaveButton
                  : l10n.extraGuidesAddButton)),
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
    final picker =
        await ref.read(guideAssignmentProvider).loadPicker(withMatcher: false);
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
    final l10n = AppLocalizations.of(context);
    final links = _links;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.extraGuidesLinksTitle)),
      body: links == null
          ? const Center(child: CircularProgressIndicator())
          : links.isEmpty
              ? Center(
                  child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(l10n.extraGuidesLinksEmpty,
                      textAlign: TextAlign.center),
                ))
              : TvFollowFocus(
                  focusFirst: true,
                  child: ListView.builder(
                    padding: EdgeInsets.only(
                        bottom: 32 + MediaQuery.paddingOf(context).bottom),
                    itemCount: links.length,
                    itemBuilder: (context, i) {
                      final l = links[i];
                      final name = _names[l.channelId] ?? l.channelId;
                      final guideName = _guideNames[l.guideRef] ??
                          l10n.extraGuidesGuideFallback;
                      final what = l.xmltvId == null
                          ? l10n.extraGuidesLinkNone
                          : l.kind == 'manual'
                              ? l10n.extraGuidesLinkManual(
                                  l.xmltvId!, guideName)
                              : l10n.extraGuidesLinkAuto(l.xmltvId!, guideName);
                      return TvActivatable(
                        onTap: () async {
                          await Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                  builder: (_) => ChangeGuideScreen(
                                      channelId: l.channelId,
                                      channelName: name)));
                          unawaited(_load());
                        },
                        builder: (tap) => ListTile(
                          leading: Icon(
                              l.kind == 'manual'
                                  ? Icons.person_outline
                                  : Icons.auto_fix_high_rounded,
                              color: theme.colorScheme.primary),
                          title: Text(name),
                          subtitle:
                              Text(what, style: theme.textTheme.bodySmall),
                          onTap: tap,
                        ),
                      );
                    },
                  )),
    );
  }
}
