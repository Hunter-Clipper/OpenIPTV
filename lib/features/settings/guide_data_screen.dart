import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_iptv/core/models/source.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/core/services/source_manager.dart';
import 'package:open_iptv/core/storage/preferences.dart';
import 'package:open_iptv/l10n/gen/app_localizations.dart';
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
        showSnackBarMessage(
            context, AppLocalizations.of(context).guideDataDescriptionsBack);
      }
    }
  }

  Future<void> _clear() async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.guideDataClearTitle),
        content: Text(l10n.guideDataClearBody),
        actions: [
          // Cancel takes the focus first, so a stray OK press cancels.
          TvActivatable(
            autofocus: true,
            onTap: () => Navigator.of(dialogContext).pop(false),
            builder: (onTap) =>
                TextButton(onPressed: onTap, child: Text(l10n.commonCancel)),
          ),
          TvActivatable(
            onTap: () => Navigator.of(dialogContext).pop(true),
            builder: (onTap) =>
                FilledButton(onPressed: onTap, child: Text(l10n.guideDataClearButton)),
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
      showSnackBarMessage(context, l10n.guideDataCleared);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
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
      appBar: AppBar(title: Text(l10n.guideDataTitle)),
      body: prefs == null
          ? const Center(child: CircularProgressIndicator())
          : TvFollowFocus(
              child: SingleChildScrollView(
              padding: EdgeInsets.only(
                  bottom: 32 + MediaQuery.paddingOf(context).bottom),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SettingsGroup(
                    title: l10n.guideDataDaysTitle,
                    description: l10n.guideDataDaysDescription,
                    children: [
                      for (final d in _dayChoices)
                        TvActivatable(
                          // The remote starts on the current choice.
                          autofocus: d == prefs.guideDaysAhead,
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
                            title: Text(d == 5
                                ? l10n.guideDataDaysDefault(d)
                                : l10n.guideDataDays(d)),
                            onTap: tap,
                          ),
                        ),
                    ],
                  ),
                  SettingsGroup(
                    title: l10n.guideDataDetailsTitle,
                    description: l10n.guideDataDetailsDescription,
                    children: [
                      TvActivatable(
                        onTap: () => _setDescriptions(!prefs.guideDescriptions),
                        builder: (tap) => SwitchListTile(
                          secondary: const IconBadge(icon: Icons.notes_rounded),
                          title: Text(l10n.guideDataStoreDescriptions),
                          value: prefs.guideDescriptions,
                          onChanged: tap == null ? null : (_) => tap(),
                        ),
                      ),
                    ],
                  ),
                  SettingsGroup(
                    title: l10n.guideDataLastUpdate,
                    description:
                        withGuide.isEmpty ? l10n.guideDataNoGuides : null,
                    children: [
                      for (final s in withGuide) _statusTile(s, prefs, theme),
                      const RefreshAllTiles(),
                    ],
                  ),
                  SettingsGroup(
                    title: l10n.guideDataClearGroup,
                    children: [
                      TvActivatable(
                        onTap: _busy ? null : _clear,
                        builder: (tap) => ListTile(
                          leading: const IconBadge(
                              icon: Icons.delete_sweep_outlined),
                          title: Text(l10n.guideDataClearRowTitle),
                          subtitle: Text(
                            _busy
                                ? l10n.guideDataClearing
                                : l10n.guideDataClearRowSubtitle,
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
    final l10n = AppLocalizations.of(context);
    final ms = prefs.guideUpdatedMs(s.id);
    final err = prefs.guideError(s.id);
    final count = _counts[s.id] ?? 0;
    final String line;
    if (err != null && (ms == null || err.isNotEmpty)) {
      line = ms == null
          ? err
          : l10n.guideDataLastLoaded(err, _ago(l10n, ms), count);
    } else if (ms != null) {
      line = l10n.guideDataUpdated(_ago(l10n, ms), count);
    } else if (count > 0) {
      line = l10n.guideDataStored(count);
    } else {
      line = l10n.guideDataNotLoaded;
    }
    return ListTile(
      leading: err != null
          ? Icon(Icons.error_outline, color: theme.colorScheme.error)
          : const IconBadge(icon: Icons.event_note_outlined),
      title: Text(s.nickname),
      subtitle: Text(line, style: theme.textTheme.bodySmall),
    );
  }

  static String _ago(AppLocalizations l10n, int ms) {
    final d =
        DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms));
    if (d.inMinutes < 1) return l10n.guideDataAgoJustNow;
    if (d.inMinutes < 60) return l10n.guideDataAgoMinutes(d.inMinutes);
    if (d.inHours < 24) return l10n.guideDataAgoHours(d.inHours);
    return l10n.guideDataAgoDays(d.inDays);
  }
}
