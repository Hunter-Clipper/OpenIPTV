// Settings → Advanced → Anonymous Reports (#150): the on/off switch and the
// plain list of exactly what a report contains, plus any reports waiting on
// this device shown as the raw JSON that would be sent.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      appBar: AppBar(title: const Text('Anonymous Reports')),
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
                title: const Text('Send anonymous crash reports'),
                subtitle: const Text(
                    'Off unless you turn it on. Helps fix crashes faster.'),
                value: on,
                onChanged: _set,
              ),
            ),
            block(Text(
              'When the app crashes, a short report is saved on this device '
              'and sent in the background, at most once a day. It cannot be '
              'tied to you or to anything you watch.',
              style: theme.textTheme.bodyMedium,
            )),
            heading('A report contains only this'),
            block(const Text(
              '• App version\n'
              '• Android version\n'
              '• Device maker and model\n'
              '• The date (no time)\n'
              '• Crash type (the error\'s name only)\n'
              '• Where in the code it happened (up to 30 lines)',
            )),
            heading('Never included'),
            block(const Text(
              '• Playlists, logins, passwords or links\n'
              '• Channel, movie or series names, or what you watch\n'
              '• Search text, profile names or settings\n'
              '• IP addresses, device IDs, or any ID that '
              'could tie reports together\n'
              '• Error messages (they can contain links or names)',
            )),
            heading('Waiting to be sent from this device'),
            block(_queued.isEmpty
                ? const Text('Nothing is waiting.')
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
                        child: const Text('Delete waiting reports')),
                  ),
                ),
              ),
            heading('Check the code'),
            block(const Text(
              'All of it lives in lib/telemetry/ in the OpenIPTV GitHub '
              'repository, with a short design note in docs/design/'
              'anonymous-stats.md.',
            )),
          ],
        ),
      ),
    );
  }
}
