import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_iptv/core/providers/theme_providers.dart';
import 'package:open_iptv/core/storage/preferences.dart';
import 'package:open_iptv/l10n/gen/app_localizations.dart';
import 'package:open_iptv/shared/theme/app_theme.dart';
import 'package:open_iptv/shared/theme/retro_cable_theme.dart';
import 'package:open_iptv/shared/theme/theme_preset.dart';
import 'package:open_iptv/shared/widgets/tv_focusable.dart';

/// The preset's name as shown in Settings and the picker.
String themeName(AppLocalizations l10n, ThemePreset preset) => switch (preset) {
      ThemePreset.standard => l10n.themeStandardName,
      ThemePreset.trueBlack => l10n.themeTrueBlackName,
      ThemePreset.retroCable => l10n.themeRetroCableName,
    };

/// Dialog with a small preview of each look; the choice applies at once to
/// the active profile (#178).
Future<void> showThemePicker(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final current = ref.read(themePresetProvider);
  final accent = ref.read(accentColorProvider);
  final picked = await showDialog<ThemePreset>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.themeTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.themePickerHint,
                style: Theme.of(ctx).textTheme.bodySmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final p in ThemePreset.values)
                  _ThemeCard(
                    preset: p,
                    accent: accent,
                    selected: p == current,
                    onTap: () => Navigator.of(ctx).pop(p),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TvActivatable(
          onTap: () => Navigator.of(ctx).pop(),
          builder: (onTap) =>
              TextButton(onPressed: onTap, child: Text(l10n.commonCancel)),
        ),
      ],
    ),
  );
  if (picked == null || picked == current) return;
  final prefs = await ref.read(appPreferencesProvider.future);
  await setThemePreset(ref, picked, prefs);
}

/// A miniature guide drawn in the preset's own colours, with its name.
class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.preset,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final ThemePreset preset;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = _presetLook(preset, accent);
    final l10n = AppLocalizations.of(context);
    return TvActivatable(
      // The remote starts on the current look.
      autofocus: selected,
      onTap: onTap,
      builder: (onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 150,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? accent : AppTheme.outlineColor,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  height: 76,
                  color: theme.background,
                  padding: const EdgeInsets.all(5),
                  child: Column(children: [
                    Container(height: 10, color: theme.header),
                    const SizedBox(height: 4),
                    for (var i = 0; i < 3; i++) ...[
                      Expanded(
                        child: Row(children: [
                          Container(width: 22, color: theme.channel),
                          const SizedBox(width: 3),
                          Expanded(
                            flex: 3,
                            child: Container(
                                color:
                                    i == 0 ? theme.cellHighlight : theme.cell),
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                              flex: 2,
                              child: Container(
                                  color:
                                      i == 1 ? theme.cellOther : theme.cell)),
                        ]),
                      ),
                      if (i < 2) const SizedBox(height: 3),
                    ],
                  ]),
                ),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: Text(themeName(l10n, preset),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                if (selected)
                  Icon(Icons.check_circle_rounded, size: 18, color: accent),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

/// The colours a preview needs from a preset.
({
  Color background,
  Color header,
  Color channel,
  Color cell,
  Color cellHighlight,
  Color cellOther,
}) _presetLook(ThemePreset preset, Color accent) {
  switch (preset) {
    case ThemePreset.retroCable:
      return (
        background: RetroCable.navy,
        header: RetroCable.panelHigh,
        channel: RetroCable.cream,
        cell: RetroCable.cellBlue,
        cellHighlight: RetroCable.sportsGreen,
        cellOther: RetroCable.moviePurple,
      );
    case ThemePreset.standard:
    case ThemePreset.trueBlack:
      return (
        background: preset.background ?? AppTheme.backgroundColor,
        header: AppTheme.surfaceVariantColor,
        channel: AppTheme.surfaceVariantColor,
        cell: AppTheme.surfaceVariantColor,
        cellHighlight: accent,
        cellOther: AppTheme.surfaceVariantColor,
      );
  }
}
