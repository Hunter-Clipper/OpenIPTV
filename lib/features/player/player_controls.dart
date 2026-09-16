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
    this.channelId,
    this.onTap,
    this.isLiveDvr = false,
    this.onLivePlayPause,
    this.onLiveRewind,
    this.onLiveForward,
    this.onGoLive,
    this.isBehindLive = false,
    this.playPauseFocusNode,
    this.backFocusNode,
  });

  final String title;
  final bool isLive;
  final String? contentType;
  final String? contentId;
  final String? channelId;
  final VoidCallback? onTap;
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

  void _showCcPicker(BuildContext context) {
    final realTracks = _tracks.where((t) => t.type == 'text').toList();
    if (realTracks.isEmpty && widget.isLive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No subtitles detected for this channel'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text('Subtitles / CC',
                    style: Theme.of(ctx)
                        .textTheme
                        .titleMedium!
                        .copyWith(fontWeight: FontWeight.bold)),
              ),
              ListTile(
                leading: const Icon(Icons.subtitles_off_outlined),
                title: const Text('Off'),
                selected: !_ccActive,
                onTap: () {
                  ref.read(playbackServiceProvider).clearTextTrack();
                  Navigator.of(ctx).pop();
                },
              ),
              ...realTracks.map((t) {
                final label = t.label.isNotEmpty
                    ? t.label
                    : (t.language?.isNotEmpty == true
                        ? t.language!.toUpperCase()
                        : 'Track ${t.id}');
                return ListTile(
                  leading: const Icon(Icons.subtitles_outlined),
                  title: Text(label),
                  selected: t.selected,
                  onTap: () {
                    ref.read(playbackServiceProvider).selectTrack(t.id);
                    Navigator.of(ctx).pop();
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showEpgPanel(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EpgPanel(
        channelId: widget.channelId ?? widget.contentId ?? '',
        channelName: widget.title,
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return widget.isLive
        ? _LiveControls(
            title: widget.title,
            contentId: widget.contentId,
            qualityLabel: _qualityLabel,
            hasCc: _hasSubtitles,
            ccActive: _ccActive,
            onBack: () => context.pop(),
            onEpg: () => _showEpgPanel(context),
            onCc: () => _showCcPicker(context),
            onPlayPause: widget.onLivePlayPause,
            onRewind: widget.onLiveRewind,
            onForward: widget.onLiveForward,
            onGoLive: widget.onGoLive,
            isBehindLive: widget.isBehindLive,
            playPauseFocusNode: widget.playPauseFocusNode,
            backFocusNode: widget.backFocusNode,
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
            formatDuration: _formatDuration,
            onBack: () => context.pop(),
            onCc: () => _showCcPicker(context),
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
// Live TV controls
// ---------------------------------------------------------------------------

class _LiveControls extends ConsumerWidget {
  const _LiveControls({
    required this.title,
    required this.contentId,
    required this.onBack,
    required this.onEpg,
    required this.onCc,
    required this.hasCc,
    required this.ccActive,
    this.qualityLabel,
    this.onPlayPause,
    this.onRewind,
    this.onForward,
    this.onGoLive,
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
  final VoidCallback? onPlayPause;
  final VoidCallback? onRewind;
  final VoidCallback? onForward;
  final VoidCallback? onGoLive;
  final bool isBehindLive;
  final FocusNode? playPauseFocusNode;
  final FocusNode? backFocusNode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profile = ref.watch(activeProfileProvider).valueOrNull;
    final isFav = profile?.favoriteChannelIds.contains(contentId) ?? false;
    final service = ref.watch(playbackServiceProvider);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xCC000000),
            Colors.transparent,
            Colors.transparent,
            Color(0xCC000000),
          ],
          stops: [0.0, 0.25, 0.75, 1.0],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top bar
            DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xDD000000), Colors.transparent],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    _ControlIconButton(
                      icon: Icons.arrow_back,
                      tooltip: 'Back',
                      onTap: onBack,
                      focusNode: backFocusNode,
                    ),
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.titleMedium!
                            .copyWith(color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Quality badge
                    if (qualityLabel != null) ...[
                      _QualityBadge(label: qualityLabel!),
                      const SizedBox(width: 8),
                    ],
                    // LIVE badge — doubles as a "back to live" tap target
                    // once the user has paused/rewound behind the live edge.
                    isBehindLive
                        ? TvFocusable(
                            onTap: onGoLive!,
                            borderRadius: BorderRadius.circular(4),
                            child: const _LiveBadge(isBehindLive: true),
                          )
                        : const _LiveBadge(isBehindLive: false),
                    const SizedBox(width: 8),
                    // CC button — always visible for live TV; dims when no
                    // tracks detected (embedded CEA-608/708 may appear late)
                    _ControlIconButton(
                      icon: ccActive
                          ? Icons.closed_caption
                          : Icons.closed_caption_outlined,
                      tooltip: 'Subtitles / CC',
                      color: ccActive
                          ? Colors.white
                          : (hasCc ? Colors.white54 : Colors.white24),
                      onTap: onCc,
                    ),
                    // Favourite toggle
                    if (contentId != null && profile != null)
                      _ControlIconButton(
                        icon: isFav ? Icons.star : Icons.star_border,
                        tooltip: isFav
                            ? 'Remove from Favorites'
                            : 'Add to Favorites',
                        color: isFav
                            ? Theme.of(context).colorScheme.primary
                            : Colors.white,
                        onTap: () => ref
                            .read(profileServiceProvider)
                            .toggleFavoriteChannel(profile.id, contentId!),
                      ),
                    // EPG button
                    _ControlIconButton(
                      icon: Icons.list_alt,
                      tooltip: 'TV Guide',
                      onTap: onEpg,
                    ),
                  ],
                ),
              ),
            ),
            if (onPlayPause != null)
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TvFocusable(
                      onTap: onRewind!,
                      borderRadius: BorderRadius.circular(24),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.replay_10,
                            color: Colors.white70, size: 32),
                      ),
                    ),
                    const SizedBox(width: 24),
                    StreamBuilder<NativeVideoPlayerState>(
                      stream: service.stateStream,
                      initialData: service.lastState,
                      builder: (context, snap) {
                        final playing = snap.data?.playing ?? false;
                        return TvFocusable(
                          onTap: onPlayPause!,
                          focusNode: playPauseFocusNode,
                          borderRadius: BorderRadius.circular(28),
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: Icon(
                              playing ? Icons.pause : Icons.play_arrow,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 24),
                    TvFocusable(
                      onTap: onForward!,
                      borderRadius: BorderRadius.circular(24),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.forward_10,
                            color: Colors.white70, size: 32),
                      ),
                    ),
                  ],
                ),
              )
            else
              const Spacer(),
            // Current programme at bottom
            if (contentId != null)
              _LiveProgrammeBar(channelId: contentId!),
          ],
        ),
      ),
    );
  }
}

class _LiveProgrammeBar extends ConsumerStatefulWidget {
  const _LiveProgrammeBar({required this.channelId});

  final String channelId;

  @override
  ConsumerState<_LiveProgrammeBar> createState() => _LiveProgrammeBarState();
}

class _LiveProgrammeBarState extends ConsumerState<_LiveProgrammeBar> {
  Timer? _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Refresh the progress position every 30 seconds.
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final epg = ref.watch(epgServiceProvider);
    return FutureBuilder<Programme?>(
      future: epg.getCurrentProgramme(widget.channelId),
      builder: (context, snapshot) {
        final prog = snapshot.data;
        if (prog == null) return const SizedBox.shrink();
        final progress = prog.progressAt(_now);
        final remaining = prog.end.difference(_now);
        final bottomPad = MediaQuery.of(context).viewPadding.bottom + 16;
        return Container(
          padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      prog.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '-${_fmtDuration(remaining)}',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white24,
                  color: Colors.white,
                  minHeight: 3,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    return h > 0 ? '${h}h ${m}m' : '${m}m';
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
    required this.formatDuration,
    required this.onBack,
    required this.onCc,
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
  final String Function(Duration) formatDuration;
  final VoidCallback onBack;
  final VoidCallback onCc;
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
    final theme = Theme.of(context);
    final service = ref.watch(playbackServiceProvider);
    final profile = ref.watch(activeProfileProvider).valueOrNull;
    final isFav = profile?.favoriteChannelIds.contains(contentId) ?? false;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xCC000000),
            Colors.transparent,
            Colors.transparent,
            Color(0xCC000000),
          ],
          stops: [0.0, 0.3, 0.7, 1.0],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top bar
            DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xDD000000), Colors.transparent],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    _ControlIconButton(
                      icon: Icons.arrow_back,
                      tooltip: 'Back',
                      onTap: onBack,
                      focusNode: backFocusNode,
                    ),
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.titleMedium!
                            .copyWith(color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (qualityLabel != null) ...[
                      _QualityBadge(label: qualityLabel!),
                      const SizedBox(width: 8),
                    ],
                    if (onGoLive != null) ...[
                      TvFocusable(
                        onTap: onGoLive!,
                        borderRadius: BorderRadius.circular(4),
                        child: const _LiveBadge(isBehindLive: false),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (hasCc)
                      _ControlIconButton(
                        icon: ccActive
                            ? Icons.closed_caption
                            : Icons.closed_caption_outlined,
                        tooltip: 'Subtitles / CC',
                        color: ccActive ? Colors.white : Colors.white54,
                        onTap: onCc,
                      ),
                    if (contentId != null && profile != null)
                      _ControlIconButton(
                        icon: isFav ? Icons.star : Icons.star_border,
                        tooltip: isFav
                            ? 'Remove from Favorites'
                            : 'Add to Favorites',
                        color: isFav
                            ? Theme.of(context).colorScheme.primary
                            : Colors.white,
                        onTap: () => ref
                            .read(profileServiceProvider)
                            .toggleFavoriteChannel(profile.id, contentId!),
                      ),
                    if (onEpg != null)
                      _ControlIconButton(
                        icon: Icons.list_alt,
                        tooltip: 'TV Guide',
                        onTap: onEpg!,
                      ),
                  ],
                ),
              ),
            ),
            // Centre play/pause + skip zones
            Expanded(
              child: Row(
                children: [
                  // ‑10s zone — double-tap for touch, select/OK for D-pad.
                  Expanded(
                    child: TvFocusable(
                      wrapsGesture: false,
                      onTap: onSkipBack,
                      child: GestureDetector(
                        onDoubleTap: onSkipBack,
                        child: Container(
                          color: Colors.transparent,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.replay_10,
                            color: Colors.white70,
                            size: 36,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Centre play/pause
                  StreamBuilder<NativeVideoPlayerState>(
                    stream: service.stateStream,
                    initialData: service.lastState,
                    builder: (context, snap) {
                      final playing = snap.data?.playing ?? false;
                      return TvFocusable(
                        onTap: () => service.togglePlayPause(),
                        focusNode: playPauseFocusNode,
                        borderRadius: BorderRadius.circular(32),
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(32),
                          ),
                          child: Icon(
                            playing ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                      );
                    },
                  ),
                  // +10s zone — double-tap for touch, select/OK for D-pad.
                  Expanded(
                    child: TvFocusable(
                      wrapsGesture: false,
                      onTap: onSkipForward,
                      child: GestureDetector(
                        onDoubleTap: onSkipForward,
                        child: Container(
                          color: Colors.transparent,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.forward_10,
                            color: Colors.white70,
                            size: 36,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Bottom seek bar
            Padding(
              padding: EdgeInsets.fromLTRB(
                  12, 0, 12, MediaQuery.of(context).viewPadding.bottom + 16),
              child: Column(
                children: [
                  // Time labels
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        formatDuration(position),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                      Text(
                        duration.inSeconds > 0
                            ? formatDuration(duration)
                            : '',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6),
                      trackHeight: 3,
                      activeTrackColor: Colors.white,
                      inactiveTrackColor: Colors.white30,
                      thumbColor: Colors.white,
                      overlayColor: Colors.white24,
                    ),
                    child: Slider(
                      value: _sliderValue,
                      onChangeStart: (_) => onSeekStart(),
                      onChanged: onSeekUpdate,
                      onChangeEnd: onSeekEnd,
                    ),
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

// ---------------------------------------------------------------------------
// Shared controls
// ---------------------------------------------------------------------------

/// Icon-only control button, focusable/selectable via D-pad (see
/// TvFocusable) — the icon-button equivalent used throughout the controls
/// overlay instead of plain IconButton, which has no visible focus
/// indicator on TV.
class _ControlIconButton extends StatelessWidget {
  const _ControlIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color = Colors.white,
    this.focusNode,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color color;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      onTap: onTap,
      focusNode: focusNode,
      borderRadius: BorderRadius.circular(8),
      child: Tooltip(
        message: tooltip,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: color, size: 24),
        ),
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({required this.isBehindLive});

  final bool isBehindLive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isBehindLive ? Colors.white24 : Colors.red,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isBehindLive) ...[
            const Icon(Icons.fast_forward, color: Colors.white, size: 12),
            const SizedBox(width: 2),
          ],
          const Text(
            'LIVE',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _QualityBadge extends StatelessWidget {
  const _QualityBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white38),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }
}
