// The one-time "Help improve OpenIPTV?" question (#150). Shown once to people
// who update (from the app's main screen) and once in the setup wizard for
// new installs. Either button is a final answer; it never asks again, and
// Settings → Advanced → Anonymous Reports changes it any time.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_iptv/ui/platform_helper.dart';
import 'package:open_iptv/shared/widgets/tv_focusable.dart';
import 'package:open_iptv/telemetry/consent.dart';
import 'package:open_iptv/telemetry/telemetry.dart';

/// Asks once. Returns without asking if a choice was already made.
Future<void> askStatsConsentOnce(
    BuildContext context, ProviderContainer container) async {
  // Test builds only: --dart-define=OPENIPTV_FORCE_STATS_PROMPT=true shows the
  // question again so the prompt can be checked on a device that already
  // answered it.
  const force = bool.fromEnvironment('OPENIPTV_FORCE_STATS_PROMPT');
  if (!force && await readStatsChoice() != StatsChoice.unset) return;
  if (!context.mounted) return;
  final yes = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _KeepFocus(
        child: AlertDialog(
      title: const Text('Help improve OpenIPTV?'),
      scrollable: true,
      content: const Text(
        'OpenIPTV can send an anonymous report when the app crashes or freezes. A report '
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
    )),
  );
  final choice = yes == true ? StatsChoice.on : StatsChoice.off;
  await Telemetry.setChoice(choice);
  container.read(statsChoiceProvider.notifier).state = choice;
}

/// Keeps the remote working inside the dialog on TV. Something behind it
/// (a screen finishing its own start-up focus) could take focus away, leaving
/// both buttons unreachable; this puts focus back on the dialog's first
/// action whenever it ends up outside the dialog.
class _KeepFocus extends StatefulWidget {
  const _KeepFocus({required this.child});

  final Widget child;

  @override
  State<_KeepFocus> createState() => _KeepFocusState();
}

class _KeepFocusState extends State<_KeepFocus> {
  final _scope = FocusScopeNode(debugLabel: 'StatsConsent');

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_check);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_check);
    _scope.dispose();
    super.dispose();
  }

  void _check() {
    if (!mounted || !PlatformHelper.isTVDevice) return;
    final f = FocusManager.instance.primaryFocus;
    if (f != null && _scope.descendants.contains(f)) return;
    // Outside the dialog: back to its first action, after this frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cur = FocusManager.instance.primaryFocus;
      if (cur != null && _scope.descendants.contains(cur)) return;
      final first = _scope.traversalDescendants.firstOrNull;
      first?.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) =>
      FocusScope(node: _scope, child: widget.child);
}
