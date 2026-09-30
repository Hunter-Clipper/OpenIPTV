import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_iptv/core/models/programme.dart';
import 'package:open_iptv/core/services/epg_service.dart';
import 'package:open_iptv/core/services/native_video_player.dart';
import 'package:open_iptv/core/services/playback_service.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/features/live_tv/epg_panel.dart';
import 'package:open_iptv/features/player/player_settings_sheet.dart';
import 'package:open_iptv/features/player/player_ui.dart';
import 'package:open_iptv/shared/utils/display_name.dart';
import 'package:open_iptv/shared/utils/format.dart';
import 'package:open_iptv/shared/widgets/tv_focusable.dart';

/// Overlay controls for the full-screen player.
/// Supports both Live TV and VOD (movie / episode) modes.
class PlayerControls extends ConsumerStatefulWidget {
  const PlayerControls({
    super.key,
    required this.title,
    required this.isLive,
    this.contentType,
    this.contentId,
    this.isLiveDvr = false,
    this.onLivePlayPause,
    this.onLiveRewind,
    this.onLiveForward,
    this.onGoLive,
    this.isBehindLive = false,
    this.playPauseFocusNode,
    this.backFocusNode,
    this.onChannels,
    this.buffering = false,
  });

  final String title;
  final bool isLive;
  final String? contentType;
  final String? contentId;
  // Focus lands here whenever PlayerScreen reveals the controls (initial
  // show, tap-to-show, or pressing select/OK while hidden) so the D-pad can
  // immediately navigate from a sensible starting point.
  final FocusNode? playPauseFocusNode;
  // Lets PlayerScreen's edge-aware "Up" fallback request focus here directly
  // when Flutter's own directional traversal finds nothing above whatever's
  // currently focused (e.g. the centered play/pause button has no candidate
  // overlapping it horizontally, even though this screen-edge Back button is
  // clearly the intended target).
  final FocusNode? backFocusNode;
  // True while a catch-up-enabled live channel has been switched into full
  // DVR scrubbing (real seek bar via _VodControls) by the user pausing or
  // rewinding — as opposed to a programme picked from the EPG guide.
  final bool isLiveDvr;
  final VoidCallback? onLivePlayPause;
  final VoidCallback? onLiveRewind;
  final VoidCallback? onLiveForward;
  // Jumps back to the true live edge — from local-buffer rewind on a
  // non-catch-up channel, or out of DVR mode on a catch-up one.
  final VoidCallback? onGoLive;
  final bool isBehindLive;
  // Live TV: opens the channel switcher.
  final VoidCallback? onChannels;
  // Stream is loading: the play button shows a spinner.
  final bool buffering;

  @override
  ConsumerState<PlayerControls> createState() => _PlayerControlsState();
}

class _PlayerControlsState extends ConsumerState<PlayerControls> {
  StreamSubscription<NativeVideoPlayerState>? _stateSub;
  StreamSubscription<List<NativeVideoTrack>>? _tracksSub;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  int _videoHeight = 0;
  List<NativeVideoTrack> _tracks = const [];
  bool _isSeeking = false;
  double _seekValue = 0;

  bool get _hasSubtitles => _tracks.any((t) => t.type == 'text');

  bool get _ccActive => _tracks.any((t) => t.type == 'text' && t.selected);

  String? get _qualityLabel {
    final h = _videoHeight;
    if (h == 0) return null;
    if (h >= 2160) return '4K';
    if (h >= 1080) return 'FHD';
    if (h >= 720) return 'HD';
    return 'SD';
  }

  @override
  void initState() {
    super.initState();
    final service = ref.read(playbackServiceProvider);
    final initial = service.lastState;
    _position = initial.position;
    _duration = initial.duration;
    _videoHeight = initial.videoHeight;
    _stateSub = service.stateStream.listen((s) {
      if (!mounted) return;
      setState(() {
        if (!_isSeeking) _position = s.position;
        _duration = s.duration;
        _videoHeight = s.videoHeight;
      });
    });
    _tracksSub = service.tracksStream.listen((t) {
      if (mounted) setState(() => _tracks = t);
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _tracksSub?.cancel();
    super.dispose();
  }

  Future<void> _seek(Duration target) async {
    await ref.read(playbackServiceProvider).seek(target);
  }

  Future<void> _seekRelative(Duration delta) async {
    await ref.read(playbackServiceProvider).seekRelative(delta);
  }

  void _showSettings(BuildContext context,
      {PlayerSettingsFocus focus = PlayerSettingsFocus.all}) {
    showPlayerSheet<void>(
      context,
      (_) => PlayerSettingsSheet(isLive: widget.isLive, focus: focus),
    );
  }

  void _showEpgPanel(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EpgPanel(
        channelId: widget.contentId ?? '',
        channelName: widget.title,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _Buffering(
      buffering: widget.buffering,
      child: _build(context),
    );
  }

  Widget _build(BuildContext context) {
    return widget.isLive
        ? _LiveControls(
            title: widget.title,
            contentId: widget.contentId,
            qualityLabel: _qualityLabel,
            hasCc: _hasSubtitles,
            ccActive: _ccActive,
            onBack: () => context.pop(),
            onEpg: () => _showEpgPanel(context),
            onCc: () =>
                _showSettings(context, focus: PlayerSettingsFocus.subtitles),
            onSettings: () => _showSettings(context),
            onPlayPause: widget.onLivePlayPause,
            onRewind: widget.onLiveRewind,
            onForward: widget.onLiveForward,
            onGoLive: widget.onGoLive,
            isBehindLive: widget.isBehindLive,
            playPauseFocusNode: widget.playPauseFocusNode,
            backFocusNode: widget.backFocusNode,
            onChannels: widget.onChannels,
          )
        : _VodControls(
            title: widget.title,
            qualityLabel: _qualityLabel,
            hasCc: _hasSubtitles,
            ccActive: _ccActive,
            position: _position,
            duration: _duration,
            isSeeking: _isSeeking,
            seekValue: _seekValue,
            onBack: () => context.pop(),
            onCc: () =>
                _showSettings(context, focus: PlayerSettingsFocus.subtitles),
            onSettings: () => _showSettings(context),
            onSeekStart: () => setState(() => _isSeeking = true),
            onSeekUpdate: (v) => setState(() => _seekValue = v),
            onSeekEnd: (v) {
              setState(() {
                _isSeeking = false;
                _seekValue = v;
              });
              final target = Duration(
                  milliseconds: (v * _duration.inMilliseconds).round());
              _seek(target);
            },
            onSkipBack: () =>
                _seekRelative(const Duration(seconds: -10)),
            onSkipForward: () =>
                _seekRelative(const Duration(seconds: 10)),
            onEpg: widget.contentType == 'catchup'
                ? () => _showEpgPanel(context)
                : null,
            contentId:
                widget.contentType == 'catchup' ? widget.contentId : null,
            onGoLive: widget.isLiveDvr ? widget.onGoLive : null,
            playPauseFocusNode: widget.playPauseFocusNode,
            backFocusNode: widget.backFocusNode,
          );
  }
}

// ---------------------------------------------------------------------------
// Layout
// ---------------------------------------------------------------------------
//
// Both modes share one layout:
//   - top: round Back button, video quality chip;
//   - transport (rewind / play-pause / forward) centred on the screen, the
//     play button a solid accent disc;
//   - bottom: title block, a Material 3 seek bar, then the LIVE chip / times
//     on the left and round action buttons on the right.

class _ControlsLayout extends StatelessWidget {
  const _ControlsLayout({
    required this.onBack,
    required this.backFocusNode,
    required this.qualityLabel,
    required this.transport,
    required this.bottom,
    this.background,
  });

  final VoidCallback onBack;
  final FocusNode? backFocusNode;
  final String? qualityLabel;
  final Widget? transport;
  final Widget bottom;
  // Painted beneath the controls, above the scrim (e.g. VOD double-tap
  // seek zones).
  final Widget? background;

  @override
  Widget build(BuildContext context) {
    final m = PlayerMetrics.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xA6000000),
                Color(0x00000000),
                Color(0x00000000),
                Color(0x8C000000),
                Color(0xE6000000),
              ],
              stops: [0.0, 0.24, 0.45, 0.72, 1.0],
            ),
          ),
        ),
        if (background != null) background!,
        if (transport != null) Center(child: transport),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            minimum: EdgeInsets.fromLTRB(m.edge, m.edge / 2, m.edge, 0),
            child: Row(
              children: [
                PlayerButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Back',
                  onTap: onBack,
                  focusNode: backFocusNode,
                  size: m.actionSize,
                  style: PlayerButtonStyle.tonal,
                ),
                const Spacer(),
                if (qualityLabel != null) _QualityChip(label: qualityLabel!),
              ],
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            minimum: EdgeInsets.fromLTRB(m.edge, 0, m.edge, m.edge * 0.6),
            child: bottom,
          ),
        ),
      ],
    );
  }
}

/// Title block + progress bar + meta/actions row.
class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.title,
    required this.bar,
    required this.meta,
    required this.actions,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget bar;
  final Widget meta;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final m = PlayerMetrics.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.displayName(title),
          style: TextStyle(
            color: Colors.white,
            fontSize: m.titleSize,
            fontWeight: FontWeight.w600,
            height: 1.2,
            shadows: const [Shadow(blurRadius: 8, color: Colors.black54)],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (subtitle != null) ...[
          SizedBox(height: 2 * m.scale),
          Text(
            context.displayName(subtitle!),
            style: TextStyle(
              color: Colors.white70,
              fontSize: m.bodySize + 1,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        SizedBox(height: 10 * m.scale),
        bar,
        SizedBox(height: 6 * m.scale),
        Row(
          children: [
            Expanded(child: meta),
            for (final a in actions) ...[
              SizedBox(width: 4 * m.scale),
              a,
            ],
          ],
        ),
      ],
    );
  }
}

/// Rewind / play-pause / forward, centred as one group.
class _Transport extends ConsumerWidget {
  const _Transport({
    required this.onPlayPause,
    required this.onRewind,
    required this.onForward,
    this.playPauseFocusNode,
  });

  final VoidCallback onPlayPause;
  final VoidCallback onRewind;
  final VoidCallback onForward;
  final FocusNode? playPauseFocusNode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = PlayerMetrics.of(context);
    final service = ref.watch(playbackServiceProvider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PlayerButton(
          icon: Icons.replay_10_rounded,
          tooltip: 'Back 10 seconds',
          onTap: onRewind,
          size: m.skipSize,
          style: PlayerButtonStyle.tonal,
        ),
        SizedBox(width: m.transportGap),
        StreamBuilder<NativeVideoPlayerState>(
          stream: service.stateStream,
          initialData: service.lastState,
          builder: (context, snap) {
            final playing = snap.data?.playing ?? false;
            final loading = _Buffering.of(context);
            return Stack(
              alignment: Alignment.center,
              children: [
                PlayerButton(
                  icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  tooltip: playing ? 'Pause' : 'Play',
                  onTap: onPlayPause,
                  focusNode: playPauseFocusNode,
                  size: m.playSize,
                  style: PlayerButtonStyle.primary,
                ),
                // Loading: a spinning ring around the play button, where
                // the eye already is, instead of a spinner hidden behind it.
                if (loading)
                  IgnorePointer(
                    child: SizedBox(
                      width: m.playSize + 14 * m.scale,
                      height: m.playSize + 14 * m.scale,
                      child: CircularProgressIndicator(
                        strokeWidth: 3.5 * m.scale,
                        strokeCap: StrokeCap.round,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        SizedBox(width: m.transportGap),
        PlayerButton(
          icon: Icons.forward_10_rounded,
          tooltip: 'Forward 10 seconds',
          onTap: onForward,
          size: m.skipSize,
          style: PlayerButtonStyle.tonal,
        ),
      ],
    );
  }
}

/// CC / favourite / guide / channels / settings, shared by both modes.
List<Widget> _actionButtons({
  required BuildContext context,
  required WidgetRef ref,
  required bool showCc,
  required bool hasCc,
  required bool ccActive,
  required VoidCallback onCc,
  required VoidCallback onSettings,
  required String? favoriteChannelId,
  required VoidCallback? onEpg,
  VoidCallback? onChannels,
}) {
  final m = PlayerMetrics.of(context);
  final profile = ref.watch(activeProfileProvider).valueOrNull;
  final isFav =
      profile?.favoriteChannelIds.contains(favoriteChannelId) ?? false;
  return [
    // Live CC stays visible even with no tracks yet — embedded CEA-608/708
    // captions can appear late — but dims until some are detected.
    if (showCc)
      PlayerButton(
        icon: ccActive
            ? Icons.closed_caption_rounded
            : Icons.closed_caption_off_outlined,
        tooltip: 'Subtitles',
        onTap: onCc,
        size: m.actionSize,
        dimmed: !hasCc && !ccActive,
        selected: ccActive,
      ),
    if (favoriteChannelId != null && profile != null)
      PlayerButton(
        icon: isFav ? Icons.star_rounded : Icons.star_border_rounded,
        tooltip: isFav ? 'Remove from Favorites' : 'Add to Favorites',
        onTap: () async {
          await ref
              .read(profileServiceProvider)
              .toggleFavoriteChannel(profile.id, favoriteChannelId);
          // The profile provider caches favorites; refresh so the star
          // (and the channel lists behind the player) reflect the change.
          if (context.mounted) ref.invalidate(activeProfileProvider);
        },
        size: m.actionSize,
        selected: isFav,
      ),
    if (onEpg != null)
      PlayerButton(
        icon: Icons.event_note_rounded,
        tooltip: 'TV Guide',
        onTap: onEpg,
        size: m.actionSize,
      ),
    if (onChannels != null)
      PlayerButton(
        icon: Icons.format_list_bulleted_rounded,
        tooltip: 'Channels',
        onTap: onChannels,
        size: m.actionSize,
      ),
    PlayerButton(
      icon: Icons.settings_rounded,
      tooltip: 'Playback settings',
      onTap: onSettings,
      size: m.actionSize,
    ),
  ];
}

// ---------------------------------------------------------------------------
// Live TV controls
// ---------------------------------------------------------------------------

class _LiveControls extends ConsumerWidget {
  const _LiveControls({
    required this.title,
    required this.contentId,
    required this.onBack,
    required this.onEpg,
    required this.onCc,
    required this.onSettings,
    required this.hasCc,
    required this.ccActive,
    this.qualityLabel,
    this.onPlayPause,
    this.onRewind,
    this.onForward,
    this.onGoLive,
    this.onChannels,
    this.isBehindLive = false,
    this.playPauseFocusNode,
    this.backFocusNode,
  });

  final String title;
  final String? contentId;
  final String? qualityLabel;
  final bool hasCc;
  final bool ccActive;
  final VoidCallback onBack;
  final VoidCallback onEpg;
  final VoidCallback onCc;
  final VoidCallback onSettings;
  final VoidCallback? onPlayPause;
  final VoidCallback? onRewind;
  final VoidCallback? onForward;
  final VoidCallback? onGoLive;
  final VoidCallback? onChannels;
  final bool isBehindLive;
  final FocusNode? playPauseFocusNode;
  final FocusNode? backFocusNode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = _actionButtons(
      context: context,
      ref: ref,
      showCc: true,
      hasCc: hasCc,
      ccActive: ccActive,
      onCc: onCc,
      onSettings: onSettings,
      favoriteChannelId: contentId,
      onEpg: onEpg,
      onChannels: onChannels,
    );
    // LIVE badge doubles as a "back to live" button once the user has
    // paused/rewound behind the live edge.
    final liveBadge = isBehindLive && onGoLive != null
        ? TvFocusable(
            onTap: onGoLive!,
            borderRadius: BorderRadius.circular(16),
            child: const _LiveChip(isBehindLive: true),
          )
        : const _LiveChip(isBehindLive: false);

    return _ControlsLayout(
      onBack: onBack,
      backFocusNode: backFocusNode,
      qualityLabel: qualityLabel,
      transport: onPlayPause == null
          ? null
          : _Transport(
              onPlayPause: onPlayPause!,
              onRewind: onRewind!,
              onForward: onForward!,
              playPauseFocusNode: playPauseFocusNode,
            ),
      bottom: contentId == null
          ? _BottomPanel(
              title: title,
              bar: const _ProgressBar(value: 1),
              meta: liveBadge,
              actions: actions,
            )
          : _LiveProgrammePanel(
              channelId: contentId!,
              channelName: title,
              liveBadge: liveBadge,
              actions: actions,
            ),
    );
  }
}

class _LiveProgrammePanel extends ConsumerStatefulWidget {
  const _LiveProgrammePanel({
    required this.channelId,
    required this.channelName,
    required this.liveBadge,
    required this.actions,
  });

  final String channelId;
  final String channelName;
  final Widget liveBadge;
  final List<Widget> actions;

  @override
  ConsumerState<_LiveProgrammePanel> createState() =>
      _LiveProgrammePanelState();
}

class _LiveProgrammePanelState extends ConsumerState<_LiveProgrammePanel> {
  Timer? _ticker;
  DateTime _now = DateTime.now();
  // Held in state rather than built in build() — the parent rebuilds on
  // every player state event, which would otherwise re-query the EPG
  // several times a second.
  late Future<(Programme?, Programme?)> _guide;

  @override
  void initState() {
    super.initState();
    _guide = _fetch();
    // Refresh the progress position (and the programme, in case it has
    // rolled over) every 30 seconds.
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      setState(() {
        _now = DateTime.now();
        _guide = _fetch();
      });
    });
  }

  @override
  void didUpdateWidget(covariant _LiveProgrammePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channelId != widget.channelId) _guide = _fetch();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<(Programme?, Programme?)> _fetch() async {
    final epg = ref.read(epgServiceProvider);
    final now = await epg.getCurrentProgramme(widget.channelId);
    final next = await epg.getNextProgramme(widget.channelId);
    return (now, next);
  }

  String _time(BuildContext context, DateTime t) =>
      MaterialLocalizations.of(context).formatTimeOfDay(
        TimeOfDay.fromDateTime(t),
        alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
      );

  @override
  Widget build(BuildContext context) {
    final m = PlayerMetrics.of(context);
    return FutureBuilder<(Programme?, Programme?)>(
      future: _guide,
      builder: (context, snapshot) {
        final prog = snapshot.data?.$1;
        final next = snapshot.data?.$2;
        final metaStyle = TextStyle(
          color: Colors.white70,
          fontSize: m.bodySize,
          fontFeatures: const [FontFeature.tabularFigures()],
        );
        return _BottomPanel(
          // Programme title leads when known (what's on), channel below.
          title: prog?.title ?? widget.channelName,
          subtitle: prog == null ? null : widget.channelName,
          bar: _ProgressBar(value: prog?.progressAt(_now) ?? 1),
          meta: Row(
            children: [
              widget.liveBadge,
              if (prog != null) ...[
                SizedBox(width: 12 * m.scale),
                Flexible(
                  child: Text(
                    [
                      '${_time(context, prog.start)} – ${_time(context, prog.end)}',
                      '${formatRuntime(prog.end.difference(_now))} left',
                      if (next != null) 'Next: ${next.title}',
                    ].join('  ·  '),
                    style: metaStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
          actions: widget.actions,
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// VOD controls
// ---------------------------------------------------------------------------

class _VodControls extends ConsumerWidget {
  const _VodControls({
    required this.title,
    required this.position,
    required this.duration,
    required this.isSeeking,
    required this.seekValue,
    required this.onBack,
    required this.onCc,
    required this.onSettings,
    required this.hasCc,
    required this.ccActive,
    required this.onSeekStart,
    required this.onSeekUpdate,
    required this.onSeekEnd,
    required this.onSkipBack,
    required this.onSkipForward,
    this.qualityLabel,
    this.onEpg,
    this.contentId,
    this.onGoLive,
    this.playPauseFocusNode,
    this.backFocusNode,
  });

  final String title;
  final String? qualityLabel;
  final FocusNode? playPauseFocusNode;
  final FocusNode? backFocusNode;
  // Only set for catch-up playback — the channel id, reused so the
  // favourite toggle applies to the channel, same as live playback.
  final String? contentId;
  final bool hasCc;
  final bool ccActive;
  final Duration position;
  final Duration duration;
  final bool isSeeking;
  final double seekValue;
  final VoidCallback onBack;
  final VoidCallback onCc;
  final VoidCallback onSettings;
  final VoidCallback onSeekStart;
  final void Function(double) onSeekUpdate;
  final void Function(double) onSeekEnd;
  final VoidCallback onSkipBack;
  final VoidCallback onSkipForward;
  // Only set for catch-up playback — lets the user get back to the guide
  // (browse other times, or jump back to live) without exiting the player.
  final VoidCallback? onEpg;
  // Only set when a live channel was switched into DVR scrubbing (pause/
  // rewind from _LiveControls) — jumps back to the true live edge.
  final VoidCallback? onGoLive;

  double get _sliderValue {
    if (isSeeking) return seekValue;
    if (duration.inMilliseconds == 0) return 0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = PlayerMetrics.of(context);
    final scheme = Theme.of(context).colorScheme;
    final service = ref.watch(playbackServiceProvider);
    final shownPosition = isSeeking
        ? Duration(milliseconds: (seekValue * duration.inMilliseconds).round())
        : position;
    final timeStyle = TextStyle(
      color: Colors.white,
      fontSize: m.bodySize,
      fontWeight: FontWeight.w500,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return _ControlsLayout(
      onBack: onBack,
      backFocusNode: backFocusNode,
      qualityLabel: qualityLabel,
      // Invisible double-tap seek zones for touch (left half back, right
      // half forward); D-pad users get the focusable transport buttons.
      background: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onDoubleTap: onSkipBack,
            ),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onDoubleTap: onSkipForward,
            ),
          ),
        ],
      ),
      transport: _Transport(
        onPlayPause: service.togglePlayPause,
        onRewind: onSkipBack,
        onForward: onSkipForward,
        playPauseFocusNode: playPauseFocusNode,
      ),
      bottom: _BottomPanel(
        title: title,
        bar: SizedBox(
          height: 28 * m.scale,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              year2023: false,
              padding: EdgeInsets.zero,
              trackHeight: 6 * m.scale,
              trackGap: 4 * m.scale,
              thumbSize: WidgetStatePropertyAll(Size(4 * m.scale, 24 * m.scale)),
              activeTrackColor: scheme.primary,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.28),
              thumbColor: scheme.primary,
              overlayColor: Colors.transparent,
            ),
            child: Slider(
              value: _sliderValue,
              onChangeStart: (_) => onSeekStart(),
              onChanged: onSeekUpdate,
              onChangeEnd: onSeekEnd,
            ),
          ),
        ),
        meta: Row(
          children: [
            if (onGoLive != null) ...[
              TvFocusable(
                onTap: onGoLive!,
                borderRadius: BorderRadius.circular(16),
                child: const _LiveChip(isBehindLive: true),
              ),
              SizedBox(width: 12 * m.scale),
            ],
            Text(formatClock(shownPosition), style: timeStyle),
            if (duration.inSeconds > 0)
              Text(
                '  /  ${formatClock(duration)}',
                style: timeStyle.copyWith(color: Colors.white60),
              ),
          ],
        ),
        actions: _actionButtons(
          context: context,
          ref: ref,
          // Movies/episodes: CC only when the video has subtitles (live
          // keeps it, since broadcast captions can turn up late).
          showCc: hasCc,
          hasCc: hasCc,
          ccActive: ccActive,
          onCc: onCc,
          onSettings: onSettings,
          favoriteChannelId: contentId,
          onEpg: onEpg,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared pieces
// ---------------------------------------------------------------------------

/// Non-interactive progress bar (live programme progress), in the Material 3
/// style of the seek bar: a rounded accent fill, a gap, then the track.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final m = PlayerMetrics.of(context);
    return SizedBox(
      height: 28 * m.scale,
      child: Center(
        child: ProgressIndicatorTheme(
          data: ProgressIndicatorTheme.of(context).copyWith(year2023: false),
          child: LinearProgressIndicator(
          value: value.clamp(0.0, 1.0),
          minHeight: 6 * m.scale,
          trackGap: 4 * m.scale,
          stopIndicatorColor: Colors.transparent,
          borderRadius: BorderRadius.circular(3 * m.scale),
          backgroundColor: Colors.white.withValues(alpha: 0.28),
          color: Theme.of(context).colorScheme.primary,
        ),
        ),
      ),
    );
  }
}

class _LiveChip extends StatelessWidget {
  const _LiveChip({required this.isBehindLive});

  // Behind the live edge: a tonal "Go live" chip instead of the red LIVE.
  final bool isBehindLive;

  @override
  Widget build(BuildContext context) {
    final m = PlayerMetrics.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: 12 * m.scale, vertical: 5 * m.scale),
      decoration: BoxDecoration(
        color: isBehindLive
            ? Colors.white.withValues(alpha: 0.2)
            : const Color(0xFFE53935),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isBehindLive)
            Icon(Icons.skip_next_rounded,
                color: Colors.white, size: 16 * m.scale)
          else
            Container(
              width: 7 * m.scale,
              height: 7 * m.scale,
              decoration: const BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle),
            ),
          SizedBox(width: 6 * m.scale),
          Text(
            isBehindLive ? 'Go live' : 'LIVE',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12.5 * m.scale,
              letterSpacing: isBehindLive ? 0.2 : 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _QualityChip extends StatelessWidget {
  const _QualityChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final m = PlayerMetrics.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: 10 * m.scale, vertical: 5 * m.scale),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 11.5 * m.scale,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

/// Tells the transport the stream is loading, without threading a flag
/// through every controls widget.
class _Buffering extends InheritedWidget {
  const _Buffering({required this.buffering, required super.child});

  final bool buffering;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_Buffering>()?.buffering ??
      false;

  @override
  bool updateShouldNotify(_Buffering old) => buffering != old.buffering;
}
