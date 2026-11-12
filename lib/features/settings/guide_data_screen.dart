import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_iptv/core/models/source.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/core/services/source_manager.dart';
import 'package:open_iptv/core/storage/preferences.dart';
import 'package:open_iptv/features/settings/refresh_all.dart';
import 'package:open_iptv/shared/utils/snack_bar_utils.dart';
import 'package:open_iptv/shared/widgets/settings_group.dart';
import 'package:open_iptv/shared/widgets/tv_focusable.dart';

/// Settings → Advanced → Guide Data: how much TV guide is kept, whether
/// programme descriptions are stored, what the last update did, and a way
/// to clear it all.
class GuideDataScreen extends ConsumerStatefulWidget {
  const GuideDataScreen({super.key});

  @override
  ConsumerState<GuideDataScreen> createState() => _GuideDataScreenState();
}

class _GuideDataScreenState extends ConsumerState<GuideDataScreen> {
  static const _dayChoices = [1, 2, 3, 5, 7, 10, 14];

  AppPreferences? _prefs;
  // Programmes stored per playlist id (loaded from the database).
  Map<String, int> _counts = const {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await ref.read(appPreferencesProvider.future);
    final sources = await ref.read(allSourcesProvider.future);
    final db = ref.read(appDatabaseProvider);
    final counts = <String, int>{};
    for (final s in sources) {
      counts[s.id] = await db.countProgrammesForSource(s.id);
    }
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _counts = counts;
    });
  }

  Future<void> _setDays(int days) async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setGuideDaysAhead(days);
    // A shorter window takes effect now, not at the next refresh.
    final db = ref.read(appDatabaseProvider);
    await db.deleteProgrammesStartingAfter(
        DateTime.now().add(Duration(days: days)));
    await _load();
  }

  Future<void> _setDescriptions(bool keep) async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setGuideDescriptions(keep);
    if (!keep) {
      final db = ref.read(appDatabaseProvider);
      await db.clearProgrammeDescriptions();
      await db.compact();
    }
    if (mounted) {
      setState(() {});
      if (keep) {
        showSnackBarMessage(context,
            'Descriptions come back the next time the TV guide refreshes.');
      }
    }
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear Guide Data?'),
        content: const Text(
            'This removes the stored TV guide for every playlist. Your '
            'playlists and channels stay. Refresh the TV guides to load it '
            'again.'),
        actions: [
          // Cancel takes the focus first, so a stray OK press cancels.
          TvActivatable(
            autofocus: true,
            onTap: () => Navigator.of(dialogContext).pop(false),
            builder: (onTap) =>
                TextButton(onPressed: onTap, child: const Text('Cancel')),
          ),
          TvActivatable(
            onTap: () => Navigator.of(dialogContext).pop(true),
            builder: (onTap) =>
                FilledButton(onPressed: onTap, child: const Text('Clear')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final db = ref.read(appDatabaseProvider);
    await db.clearAllProgrammes();
    await db.compact();
    await _prefs?.clearGuideStatus();
    if (!mounted) return;
    setState(() => _busy = false);
    await _load();
    if (mounted) {
      showSnackBarMessage(context, 'Guide data cleared.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prefs = _prefs;
    // A refresh that ends while this page is open: show its new numbers.
    ref.listen(refreshAllProvider, (prev, next) {
      if (prev?.isRunning == true && !next.isRunning) _load();
    });
    final sources = ref.watch(allSourcesProvider).valueOrNull ?? const [];
    final withGuide = [
      for (final s in sources)
        if (_hasGuide(s)) s
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Guide Data')),
      body: prefs == null
          ? const Center(child: CircularProgressIndicator())
          : TvFollowFocus(child: SingleChildScrollView(
              padding: EdgeInsets.only(
                  bottom: 32 + MediaQuery.paddingOf(context).bottom),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SettingsGroup(
                    title: 'Days of guide to keep',
                    description: 'How far ahead the TV guide is stored. Fewer '
                        'days makes the guide smaller and quicker to refresh. '
                        'Catch-up history is kept as your provider offers it.',
                    children: [
                      for (final d in _dayChoices)
                        TvActivatable(
                          onTap: () => _setDays(d),
                          builder: (tap) => ListTile(
                            leading: Icon(
                              d == prefs.guideDaysAhead
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              color: d == prefs.guideDaysAhead
                                  ? theme.colorScheme.primary
                                  : null,
                            ),
                            title: Text(d == 1
                                ? '1 day'
                                : d == 5
                                    ? '5 days (default)'
                                    : '$d days'),
                            onTap: tap,
                          ),
                        ),
                    ],
                  ),
                  SettingsGroup(
                    title: 'Programme details',
                    description: 'Descriptions are most of the guide\'s size. '
                        'Turn them off to save space; titles and times stay. '
                        'Turning them off removes the stored ones now.',
                    children: [
                      TvActivatable(
                        onTap: () => _setDescriptions(!prefs.guideDescriptions),
                        builder: (tap) => SwitchListTile(
                          secondary: const IconBadge(icon: Icons.notes_rounded),
                          title: const Text('Store Programme Descriptions'),
                          value: prefs.guideDescriptions,
                          onChanged: tap == null ? null : (_) => tap(),
                        ),
                      ),
                    ],
                  ),
                  SettingsGroup(
                    title: 'Last update',
                    description: withGuide.isEmpty
                        ? 'None of your playlists has a TV guide.'
                        : null,
                    children: [
                      for (final s in withGuide) _statusTile(s, prefs, theme),
                      const RefreshAllTiles(),
                    ],
                  ),
                  SettingsGroup(
                    title: 'Clear',
                    children: [
                      TvActivatable(
                        onTap: _busy ? null : _clear,
                        builder: (tap) => ListTile(
                          leading: const IconBadge(icon: Icons.delete_sweep_outlined),
                          title: const Text('Clear Guide Data'),
                          subtitle: Text(
                            _busy
                                ? 'Clearing…'
                                : 'Removes the stored guide for every playlist',
                            style: theme.textTheme.bodySmall,
                          ),
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

  bool _hasGuide(Source s) => (s.epgUrl ?? '').isNotEmpty;

  Widget _statusTile(Source s, AppPreferences prefs, ThemeData theme) {
    final ms = prefs.guideUpdatedMs(s.id);
    final err = prefs.guideError(s.id);
    final count = _counts[s.id] ?? 0;
    final String line;
    if (err != null && (ms == null || err.isNotEmpty)) {
      line = ms == null
          ? err
          : '$err\nLast loaded ${_ago(ms)}, $count programmes kept.';
    } else if (ms != null) {
      line = 'Updated ${_ago(ms)} · ${_n(count)} programmes';
    } else if (count > 0) {
      line = '${_n(count)} programmes stored';
    } else {
      line = 'Not loaded yet';
    }
    return ListTile(
      leading: err != null
          ? Icon(Icons.error_outline, color: theme.colorScheme.error)
          : const IconBadge(icon: Icons.event_note_outlined),
      title: Text(s.nickname),
      subtitle: Text(line, style: theme.textTheme.bodySmall),
    );
  }

  static String _n(int v) => v
      .toString()
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

  static String _ago(int ms) {
    final d =
        DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms));
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    return '${d.inDays} d ago';
  }
}
