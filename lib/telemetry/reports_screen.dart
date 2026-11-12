// Settings → Advanced → Anonymous Reports (#150): the on/off switch and the
// plain list of exactly what a report contains, plus any reports waiting on
// this device shown as the raw JSON that would be sent.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_iptv/l10n/gen/app_localizations.dart';
import 'package:open_iptv/shared/widgets/tv_focusable.dart';
import 'package:open_iptv/telemetry/consent.dart';
import 'package:open_iptv/telemetry/telemetry.dart';
import 'package:open_iptv/ui/platform_helper.dart';

class AnonymousReportsScreen extends ConsumerStatefulWidget {
  const AnonymousReportsScreen({super.key});

  @override
  ConsumerState<AnonymousReportsScreen> createState() =>
      _AnonymousReportsScreenState();
}

class _AnonymousReportsScreenState
    extends ConsumerState<AnonymousReportsScreen> {
  List<Map<String, dynamic>> _queued = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final q = await Telemetry.queued();
    if (mounted) setState(() => _queued = q);
  }

  Future<void> _set(bool on) async {
    final choice = on ? StatsChoice.on : StatsChoice.off;
    await Telemetry.setChoice(choice);
    ref.read(statsChoiceProvider.notifier).state = choice;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final on = ref.watch(statsChoiceProvider) == StatsChoice.on;
    final tv = PlatformHelper.isTV(context);

    // On TV every block is a stop for the remote, so the page can be scrolled.
    Widget block(Widget child) => TvActivatable(
          onTap: tv ? () {} : null,
          builder: (_) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: child,
          ),
        );

    Widget heading(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
          child: Text(t, style: theme.textTheme.titleSmall),
        );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.reportsTitle)),
      body: SingleChildScrollView(
        padding:
            EdgeInsets.only(bottom: 32 + MediaQuery.paddingOf(context).bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TvActivatable(
              autofocus: tv,
              onTap: () => _set(!on),
              builder: (_) => SwitchListTile(
                title: Text(l10n.reportsSwitchTitle),
                subtitle: Text(l10n.reportsSwitchSubtitle),
                value: on,
                onChanged: _set,
              ),
            ),
            block(Text(
              l10n.reportsIntro,
              style: theme.textTheme.bodyMedium,
            )),
            heading(l10n.reportsContainsHeading),
            block(Text(l10n.reportsContainsList)),
            heading(l10n.reportsNeverHeading),
            block(Text(l10n.reportsNeverList)),
            heading(l10n.reportsWaitingHeading),
            block(_queued.isEmpty
                ? Text(l10n.reportsNothingWaiting)
                : SelectableText(
                    const JsonEncoder.withIndent('  ').convert(_queued),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontFamily: 'monospace'),
                  )),
            if (_queued.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TvActivatable(
                    onTap: () async {
                      await Telemetry.clearQueued();
                      await _load();
                    },
                    builder: (onTap) => OutlinedButton(
                        onPressed: onTap,
                        child: Text(l10n.reportsDeleteWaiting)),
                  ),
                ),
              ),
            heading(l10n.reportsCheckCodeHeading),
            block(Text(l10n.reportsCheckCodeBody)),
          ],
        ),
      ),
    );
  }
}
