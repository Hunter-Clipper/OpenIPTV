import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_iptv/core/providers/theme_providers.dart';
import 'package:open_iptv/core/storage/preferences.dart';
import 'package:open_iptv/l10n/app_languages.dart';
import 'package:open_iptv/l10n/gen/app_localizations.dart';
import 'package:open_iptv/shared/widgets/tv_focusable.dart';

/// The app language as the settings row and welcome button show it:
/// "Auto — Español" while following the system, else the language's own name.
String languageLabel(BuildContext context, String pref) {
  final l10n = AppLocalizations.of(context);
  if (pref != kLanguageAuto) return languageName(localeForPref(pref)!);
  // With no forced locale this is what Flutter resolved from the system.
  return l10n.languageAutoNow(languageName(Localizations.localeOf(context)));
}

/// Dialog with "Auto-detect from system" and every shipped language; the
/// choice applies at once and is stored for the whole app (all profiles).
Future<void> showLanguagePicker(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final current = ref.read(languageProvider);
  final currentTag = current == kLanguageAuto
      ? kLanguageAuto
      : localeForPref(current)!.toLanguageTag();
  final options = <(String, String)>[
    (kLanguageAuto, l10n.languageAuto),
    for (final l in shippedLanguages) (l.toLanguageTag(), languageName(l)),
  ];
  final picked = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.languageTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final o in options)
              TvActivatable(
                // The remote starts on the current choice.
                autofocus: o.$1 == currentTag,
                onTap: () => Navigator.of(ctx).pop(o.$1),
                builder: (onTap) => SimpleDialogOption(
                  onPressed: onTap,
                  child: Row(children: [
                    Icon(Icons.check,
                        size: 18,
                        color: o.$1 == currentTag
                            ? Theme.of(ctx).colorScheme.primary
                            : Colors.transparent),
                    const SizedBox(width: 8),
                    Flexible(child: Text(o.$2)),
                  ]),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TvActivatable(
          onTap: () => Navigator.of(ctx).pop(),
          builder: (onTap) => TextButton(
              onPressed: onTap, child: Text(l10n.commonCancel)),
        ),
      ],
    ),
  );
  if (picked == null || picked == currentTag) return;
  final prefs = await ref.read(appPreferencesProvider.future);
  await setLanguage(ref, picked, prefs);
}
