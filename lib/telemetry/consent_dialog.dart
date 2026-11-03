// The one-time "Help improve OpenIPTV?" question (#150). Shown once to people
// who update (from the app's main screen) and once in the setup wizard for
// new installs. Either button is a final answer; it never asks again, and
// Settings → Advanced → Anonymous Reports changes it any time.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_iptv/shared/widgets/tv_focusable.dart';
import 'package:open_iptv/telemetry/consent.dart';
import 'package:open_iptv/telemetry/telemetry.dart';

/// Asks once. Returns without asking if a choice was already made.
Future<void> askStatsConsentOnce(
    BuildContext context, ProviderContainer container) async {
  if (await readStatsChoice() != StatsChoice.unset) return;
  if (!context.mounted) return;
  final yes = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('Help improve OpenIPTV?'),
      scrollable: true,
      content: const Text(
        'OpenIPTV can send an anonymous report when the app crashes. A report '
        'holds the app version, your device model and where in the code the '
        "problem happened. It never holds your playlists, logins, links, "
        "channel names or what you watch, and it can't be tied to you.\n\n"
        'This is off unless you turn it on. You can change your mind any time '
        'in Settings, where you can also see exactly what is sent. The code '
        'that does this is small and open on GitHub if you want to check it.',
      ),
      actions: [
        // "No Thanks" has focus first so a stray OK press never opts in.
        TvActivatable(
          autofocus: true,
          onTap: () => Navigator.of(ctx).pop(false),
          builder: (onTap) =>
              TextButton(onPressed: onTap, child: const Text('No Thanks')),
        ),
        TvActivatable(
          onTap: () => Navigator.of(ctx).pop(true),
          builder: (onTap) =>
              FilledButton(onPressed: onTap, child: const Text('Turn On')),
        ),
      ],
    ),
  );
  final choice = yes == true ? StatsChoice.on : StatsChoice.off;
  await Telemetry.setChoice(choice);
  container.read(statsChoiceProvider.notifier).state = choice;
}
