import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_iptv/core/services/cast_service.dart';
import 'package:open_iptv/features/player/player_ui.dart';
import 'package:open_iptv/shared/utils/display_name.dart';
import 'package:open_iptv/shared/utils/format.dart';
import 'package:open_iptv/shared/widgets/tv_focusable.dart';
import 'package:open_iptv/ui/platform_helper.dart';

/// Opens the cast device picker (or, when already casting, the "connected
/// to …" sheet with Stop casting).
Future<void> showCastPicker(BuildContext context) =>
    showPlayerSheet<void>(context, (_) => const _CastPickerSheet());

class _CastPickerSheet extends ConsumerStatefulWidget {
  const _CastPickerSheet();

  @override
  ConsumerState<_CastPickerSheet> createState() => _CastPickerSheetState();
}

class _CastPickerSheetState extends ConsumerState<_CastPickerSheet> {
  late final CastService _cast = ref.read(castServiceProvider);
  bool _closing = false;
  // The device the user picked — only its row shows the spinner.
  String? _pickedId;

  @override
  void initState() {
    super.initState();
    _cast.startDiscovery();
  }

  @override
  void dispose() {
    _cast.stopDiscovery();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final status = ref.watch(castStatusProvider).valueOrNull ?? _cast.status;
    // Close once a chosen device connects — the player switches over.
    ref.listen(castStatusProvider, (prev, next) {
      final was = prev?.valueOrNull?.connected ?? false;
      if (!was && (next.valueOrNull?.connected ?? false) && !_closing) {
        _closing = true;
        Navigator.of(context).pop();
      }
      // A failed attempt drops from connecting back to idle: let the user
      // pick again.
      if (prev?.valueOrNull?.session == CastSessionState.connecting &&
          next.valueOrNull?.session == CastSessionState.idle) {
        setState(() => _pickedId = null);
      }
    });

    if (status.connected) {
      return PlayerSheet(title: 'Casting', children: [
        ListTile(
          leading: Icon(Icons.cast_connected_rounded,
              color: theme.colorScheme.primary),
          title: Text(status.device ?? 'Cast device'),
          subtitle: const Text('Connected'),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: TvActivatable(
            autofocus: true,
            borderRadius: BorderRadius.circular(24),
            onTap: () {
              _cast.disconnect();
              Navigator.of(context).pop();
            },
            builder: (onTap) => OutlinedButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.cast_rounded),
              label: const Text('Stop casting'),
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: const StadiumBorder()),
            ),
          ),
        ),
      ]);
    }

    return PlayerSheet(title: 'Cast to', children: [
      if (status.devices.isEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
          child: Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Looking for TVs and speakers on your Wi-Fi…',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        )
      else
        for (final (i, d) in status.devices.indexed)
          TvActivatable(
            autofocus: i == 0,
            onTap: _pickedId != null
                ? null
                : () {
                    setState(() => _pickedId = d.id);
                    _cast.connect(d);
                  },
            builder: (onTap) => ListTile(
              enabled: _pickedId == null || _pickedId == d.id,
              leading: Icon(d.speaker ? Icons.speaker_rounded : Icons.tv_rounded),
              title: Text(d.name),
              subtitle: _pickedId == d.id ? const Text('Connecting…') : null,
              trailing: _pickedId == d.id
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              onTap: onTap,
            ),
          ),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
        child: Text(
          'Your phone and the TV need to be on the same Wi-Fi network.',
          style: theme.textTheme.bodySmall!.copyWith(color: muted),
        ),
      ),
    ]);
  }
}

/// What the player shows while the video plays on a cast device: what's on,
/// where, and the remote controls.
class CastRemoteView extends ConsumerWidget {
  const CastRemoteView({
    super.key,
    required this.title,
    required this.isLive,
    required this.onBack,
    this.subtitle,
    this.message,
    this.onChannels,
  });

  final String title;
  final String? subtitle;
  final bool isLive;
  // Set when the device couldn't play this stream.
  final String? message;
  final VoidCallback onBack;
  final VoidCallback? onChannels;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final m = PlayerMetrics.of(context);
    final cast = ref.read(castServiceProvider);
    final status = ref.watch(castStatusProvider).valueOrNull ?? cast.status;
    final playing = status.playerState == CastPlayerState.playing;
    final loading = status.playerState == CastPlayerState.buffering ||
        (message == null && status.playerState == CastPlayerState.idle);
    final seekable = !isLive && status.duration > Duration.zero;

    return ColoredBox(
      color: const Color(0xFF0B0B10),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: m.edge, vertical: 12),
          child: Column(
            children: [
              Row(
                children: [
                  PlayerButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Back',
                    onTap: onBack,
                    size: m.actionSize,
                    style: PlayerButtonStyle.tonal,
                  ),
                  const Spacer(),
                  PlayerButton(
                    icon: Icons.cast_connected_rounded,
                    tooltip: 'Cast',
                    onTap: () => showCastPicker(context),
                    size: m.actionSize,
                    selected: true,
                  ),
                ],
              ),
              const Spacer(),
              Icon(Icons.cast_connected_rounded,
                  size: 56 * m.scale, color: scheme.primary),
              SizedBox(height: 14 * m.scale),
              Text(
                'Playing on ${status.device ?? 'your TV'}',
                style: theme.textTheme.titleSmall!
                    .copyWith(color: Colors.white70, letterSpacing: 0.3),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 6 * m.scale),
              Text(
                context.displayName(title),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: m.titleSize,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null) ...[
                SizedBox(height: 4 * m.scale),
                Text(
                  context.displayName(subtitle!),
                  style: const TextStyle(color: Colors.white60),
                  textAlign: TextAlign.center,
                ),
              ],
              if (message != null) ...[
                SizedBox(height: 18 * m.scale),
                Text(
                  message!,
                  style: TextStyle(color: scheme.error, fontSize: m.bodySize + 1),
                  textAlign: TextAlign.center,
                ),
              ],
              const Spacer(),
              if (seekable) ...[
                _CastSeekBar(status: status, cast: cast),
                SizedBox(height: 8 * m.scale),
              ],
              if (message == null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (seekable) ...[
                      PlayerButton(
                        icon: Icons.replay_10_rounded,
                        tooltip: 'Back 10 seconds',
                        onTap: () => cast.seek(_clamp(
                            status.position - const Duration(seconds: 10),
                            status.duration)),
                        size: m.skipSize,
                        style: PlayerButtonStyle.tonal,
                      ),
                      SizedBox(width: m.transportGap),
                    ],
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        PlayerButton(
                          icon: playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          tooltip: playing ? 'Pause' : 'Play',
                          onTap: playing ? cast.pause : cast.play,
                          size: m.playSize,
                          style: PlayerButtonStyle.primary,
                          autofocus: true,
                        ),
                        if (loading)
                          IgnorePointer(
                            child: SizedBox(
                              width: m.playSize + 14,
                              height: m.playSize + 14,
                              child: const CircularProgressIndicator(
                                  strokeWidth: 3, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                    if (seekable) ...[
                      SizedBox(width: m.transportGap),
                      PlayerButton(
                        icon: Icons.forward_10_rounded,
                        tooltip: 'Forward 10 seconds',
                        onTap: () => cast.seek(_clamp(
                            status.position + const Duration(seconds: 10),
                            status.duration)),
                        size: m.skipSize,
                        style: PlayerButtonStyle.tonal,
                      ),
                    ],
                  ],
                ),
              SizedBox(height: 18 * m.scale),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PlayerButton(
                    icon: Icons.volume_down_rounded,
                    tooltip: 'Volume down',
                    onTap: () => cast.setVolume(status.volume - 0.05),
                    size: m.actionSize,
                  ),
                  PlayerButton(
                    icon: Icons.volume_up_rounded,
                    tooltip: 'Volume up',
                    onTap: () => cast.setVolume(status.volume + 0.05),
                    size: m.actionSize,
                  ),
                  if (onChannels != null)
                    PlayerButton(
                      icon: Icons.format_list_bulleted_rounded,
                      tooltip: 'Channels',
                      onTap: onChannels!,
                      size: m.actionSize,
                    ),
                  SizedBox(width: 12 * m.scale),
                  TvActivatable(
                    borderRadius: BorderRadius.circular(24),
                    onTap: cast.disconnect,
                    builder: (onTap) => OutlinedButton.icon(
                      onPressed: onTap,
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Stop casting'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white38),
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Duration _clamp(Duration d, Duration max) =>
      d < Duration.zero ? Duration.zero : (d > max ? max : d);
}

class _CastSeekBar extends StatefulWidget {
  const _CastSeekBar({required this.status, required this.cast});

  final CastStatus status;
  final CastService cast;

  @override
  State<_CastSeekBar> createState() => _CastSeekBarState();
}

class _CastSeekBarState extends State<_CastSeekBar> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final total = widget.status.duration.inMilliseconds;
    final value = _dragValue ??
        (total == 0
            ? 0.0
            : (widget.status.position.inMilliseconds / total).clamp(0.0, 1.0));
    final shown = Duration(milliseconds: (value * total).round());
    const style = TextStyle(
      color: Colors.white70,
      fontFeatures: [FontFeature.tabularFigures()],
    );
    return Column(
      children: [
        Slider(
          value: value,
          onChanged: (v) => setState(() => _dragValue = v),
          onChangeEnd: (v) {
            widget.cast.seek(Duration(milliseconds: (v * total).round()));
            setState(() => _dragValue = null);
          },
        ),
        Row(
          children: [
            Text(formatClock(shown), style: style),
            const Spacer(),
            Text(formatClock(widget.status.duration), style: style),
          ],
        ),
      ],
    );
  }
}

/// Cast button for the browse screens' top bars (phones / tablets). Shows
/// once a cast device is on the network; filled while connected. Connect
/// first, then whatever you pick plays on the TV.
class CastAction extends ConsumerStatefulWidget {
  const CastAction({super.key});

  @override
  ConsumerState<CastAction> createState() => _CastActionState();
}

class _CastActionState extends ConsumerState<CastAction> {
  late final CastService _cast = ref.read(castServiceProvider);
  late final bool _tv = PlatformHelper.isTVDevice;

  @override
  void initState() {
    super.initState();
    // Device discovery runs while a Cast button is on screen.
    if (!_tv) _cast.startDiscovery();
  }

  @override
  void dispose() {
    if (!_tv) _cast.stopDiscovery();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_tv) return const SizedBox.shrink();
    final status = ref.watch(castStatusProvider).valueOrNull ?? _cast.status;
    if (!status.available && !status.connected) return const SizedBox.shrink();
    final connected = status.connected;
    return IconButton(
      icon: Icon(
        connected ? Icons.cast_connected_rounded : Icons.cast_rounded,
        color: connected ? Theme.of(context).colorScheme.primary : null,
      ),
      tooltip: connected ? 'Casting to ${status.device}' : 'Cast',
      onPressed: () => showCastPicker(context),
    );
  }
}

/// "Now casting" bar shown above the bottom tabs while something plays on
/// a cast device: title, device, play / pause; tap for the full remote.
class CastMiniBar extends ConsumerWidget {
  const CastMiniBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(castStatusProvider).valueOrNull;
    if (status == null || !status.hasMedia) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final cast = ref.read(castServiceProvider);
    final playing = status.playerState == CastPlayerState.playing;
    final progress = !status.live && status.duration > Duration.zero
        ? (status.position.inMilliseconds / status.duration.inMilliseconds)
            .clamp(0.0, 1.0)
        : null;
    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      child: InkWell(
        onTap: () => openCastRemote(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (progress != null)
              LinearProgressIndicator(value: progress, minHeight: 2),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  Icon(Icons.cast_connected_rounded,
                      color: theme.colorScheme.primary),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          context.displayName(status.title ?? 'Casting'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                        Text(
                          'On ${status.device ?? 'your TV'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall!.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(playing
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded),
                    tooltip: playing ? 'Pause' : 'Play',
                    onPressed: playing ? cast.pause : cast.play,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Stop casting',
                    onPressed: cast.disconnect,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen remote for whatever is on the cast device, opened from the
/// "now casting" bar. Closes itself when casting stops.
Future<void> openCastRemote(BuildContext context) =>
    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(
      builder: (_) => const _CastRemotePage(),
    ));

class _CastRemotePage extends ConsumerWidget {
  const _CastRemotePage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(castStatusProvider).valueOrNull;
    ref.listen(castStatusProvider, (_, next) {
      if (!(next.valueOrNull?.hasMedia ?? false) &&
          Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
    return Scaffold(
      body: CastRemoteView(
        title: status?.title ?? 'Casting',
        subtitle: status?.subtitle,
        isLive: status?.live ?? false,
        onBack: () => Navigator.of(context).pop(),
      ),
    );
  }
}
