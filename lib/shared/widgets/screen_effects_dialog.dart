import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_iptv/core/providers/theme_providers.dart';
import 'package:open_iptv/core/storage/preferences.dart';
import 'package:open_iptv/l10n/gen/app_localizations.dart';
import 'package:open_iptv/shared/theme/screen_effects.dart';
import 'package:open_iptv/shared/utils/motion.dart';
import 'package:open_iptv/shared/widgets/tv_focusable.dart';

/// What the Screen effects row says underneath.
String screenEffectsSummary(AppLocalizations l10n, ScreenEffects fx) =>
    fx.any ? l10n.screenEffectsSubtitleOn : l10n.screenEffectsSubtitleOff;

String _strengthLabel(AppLocalizations l10n, CrtStrength s) => switch (s) {
      CrtStrength.light => l10n.screenEffectsStrengthLight,
      CrtStrength.medium => l10n.screenEffectsStrengthMedium,
      CrtStrength.strong => l10n.screenEffectsStrengthStrong,
    };

/// Switches for the old-TV look (#178). Every change shows at once, behind
/// and over the dialog itself, so you can judge it.
Future<void> showScreenEffectsDialog(BuildContext context, WidgetRef ref) {
  final l10n = AppLocalizations.of(context);
  return showDialog<void>(
    context: context,
    builder: (ctx) => Consumer(builder: (ctx, ref, _) {
      final fx = ref.watch(screenEffectsProvider);
      Future<void> change(ScreenEffects next) async {
        final prefs = await ref.read(appPreferencesProvider.future);
        await setScreenEffects(ref, next, prefs);
      }

      Widget toggle(String label, bool value, ValueChanged<bool> onChanged,
              {String? note, bool autofocus = false}) =>
          TvActivatable(
            autofocus: autofocus,
            onTap: () => onChanged(!value),
            builder: (onTap) => SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(label),
              subtitle: note == null ? null : Text(note),
              value: value,
              onChanged: onTap == null ? null : (_) => onTap(),
            ),
          );

      return AlertDialog(
        title: Text(l10n.screenEffectsTitle),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                toggle(l10n.screenEffectsLines, fx.lines,
                    (v) => change(fx.copyWith(lines: v)),
                    autofocus: true),
                if (fx.lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Wrap(spacing: 8, children: [
                      for (final s in CrtStrength.values)
                        TvActivatable(
                          onTap: () => change(fx.copyWith(strength: s)),
                          builder: (onTap) => ChoiceChip(
                            label: Text(_strengthLabel(l10n, s)),
                            selected: fx.strength == s,
                            onSelected: onTap == null ? null : (_) => onTap(),
                          ),
                        ),
                    ]),
                  ),
                toggle(l10n.screenEffectsGlow, fx.glow,
                    (v) => change(fx.copyWith(glow: v))),
                toggle(l10n.screenEffectsFlicker, fx.flicker,
                    (v) => change(fx.copyWith(flicker: v)),
                    note: reduceMotion
                        ? l10n.screenEffectsFlickerReduced
                        : null),
              ],
            ),
          ),
        ),
        actions: [
          TvActivatable(
            onTap: () => Navigator.of(ctx).pop(),
            builder: (onTap) =>
                TextButton(onPressed: onTap, child: Text(l10n.commonDone)),
          ),
        ],
      );
    }),
  );
}
