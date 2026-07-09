import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:open_iptv/core/models/programme.dart';
import 'package:open_iptv/core/services/epg_service.dart';
import 'package:open_iptv/core/services/playback_service.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/features/live_tv/epg_panel.dart';

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
  });

  final String title;
  final bool isLive;
  final String? contentType;
  final String? contentId;
  final String? channelId;
  final VoidCallback? onTap;
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
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<VideoParams>? _videoParamsSub;
  StreamSubscription<Tracks>? _tracksSub;
  StreamSubscription<Track>? _trackSub;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  VideoParams _videoParams = const VideoParams();
  Tracks _tracks = const Tracks();
  Track _currentTrack = const Track();
  String _hwdecCurrent = '';
  bool _isSeeking = false;
  double _seekValue = 0;

  bool get _hasSubtitles => _tracks.subtitle
      .any((t) => t.id != 'auto' && t.id != 'no');

  bool get _ccActive =>
      _currentTrack.subtitle.id != 'no' &&
      _currentTrack.subtitle.id != 'auto';

  String? get _qualityLabel {
    final h = _videoParams.h ?? _videoParams.dh;
    if (h == null || h == 0) return null;
    if (h >= 2160) return '4K';
    if (h >= 1080) return 'FHD';
    if (h >= 720) return 'HD';
    return 'SD';
  }

  // Non-null only once video is playing; 'HW' if GPU decode is active.
  // Uses hwdec-current from mpv — hwPixelformat is null for mediacodec-copy
  // (frames are copied to CPU so mpv reports the software pixelformat instead).
  String? get _decodeLabel {
    final h = _videoParams.h ?? _videoParams.dh;
    if (h == null || h == 0) return null;
    return (_hwdecCurrent.isNotEmpty && _hwdecCurrent != 'no') ? 'HW' : 'SW';
  }

  @override
  void initState() {
    super.initState();
    final player = ref.read(playbackServiceProvider).player;
    _position = player.state.position;
    _duration = player.state.duration;
    _videoParams = player.state.videoParams;
    _tracks = player.state.tracks;
    _currentTrack = player.state.track;
    _positionSub = player.stream.position.listen((p) {
      if (!_isSeeking && mounted) setState(() => _position = p);
    });
    _durationSub = player.stream.duration.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _videoParamsSub = player.stream.videoParams.listen((vp) {
      if (mounted) setState(() => _videoParams = vp);
      // Log hwdec status every time video params update.
      debugPrint('[OTV-vp] w=${vp.w} h=${vp.h} '
          'pixelformat=${vp.pixelformat} hwPixelformat=${vp.hwPixelformat}');
      final native = player.platform;
      if (native is NativePlayer) {
        native.getProperty('hwdec-current').then<void>((v) {
          debugPrint('[OTV-hwdec-current] "$v"');
          if (mounted) setState(() => _hwdecCurrent = v);
        });
      }
    });
    _tracksSub = player.stream.tracks.listen((t) {
      if (mounted) setState(() => _tracks = t);
      debugPrint('[OTV-tracks] audio=${t.audio.length} '
          'video=${t.video.length} subtitle=${t.subtitle.length}');
      for (final s in t.subtitle) {
        debugPrint('[OTV-sub] id=${s.id} lang=${s.language} title=${s.title}');
      }
    });
    _trackSub = player.stream.track.listen((t) {
      if (mounted) setState(() => _currentTrack = t);
      debugPrint('[OTV-track-active] sub.id=${t.subtitle.id} '
          'sub.lang=${t.subtitle.language}');
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _videoParamsSub?.cancel();
    _tracksSub?.cancel();
    _trackSub?.cancel();
    super.dispose();
  }

  Future<void> _seek(Duration target) async {
    await ref.read(playbackServiceProvider).seek(target);
  }

  Future<void> _seekRelative(Duration delta) async {
    await ref.read(playbackServiceProvider).seekRelative(delta);
  }

  void _showCcPicker(BuildContext context) {
    final realTracks = _tracks.subtitle
        .where((t) => t.id != 'auto' && t.id != 'no')
        .toList();
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
                  ref
                      .read(playbackServiceProvider)
                      .setSubtitleTrack(SubtitleTrack.no());
                  Navigator.of(ctx).pop();
                },
              ),
              ...realTracks.map((t) {
                final label = t.title?.isNotEmpty == true
                    ? t.title!
                    : (t.language?.isNotEmpty == true
                        ? t.language!.toUpperCase()
                        : 'Track ${t.id}');
                return ListTile(
                  leading: const Icon(Icons.subtitles_outlined),
                  title: Text(label),
                  selected: _currentTrack.subtitle == t,
                  onTap: () {
                    ref
                        .read(playbackServiceProvider)
                        .setSubtitleTrack(t);
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
            decodeLabel: _decodeLabel,
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
          )
        : _VodControls(
            title: widget.title,
            qualityLabel: _qualityLabel,
            decodeLabel: _decodeLabel,
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
    this.decodeLabel,
    this.onPlayPause,
    this.onRewind,
    this.onForward,
    this.onGoLive,
    this.isBehindLive = false,
  });

  final String title;
  final String? contentId;
  final String? qualityLabel;
  final String? decodeLabel;
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profile = ref.watch(activeProfileProvider).valueOrNull;
    final isFav = profile?.favoriteChannelIds.contains(contentId) ?? false;
    final player = ref.watch(playbackServiceProvider).player;

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
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      color: Colors.white,
                      tooltip: 'Back',
                      onPressed: onBack,
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
                    // Quality + decode badges
                    if (qualityLabel != null) ...[
                      _QualityBadge(label: qualityLabel!),
                      const SizedBox(width: 4),
                    ],
                    if (decodeLabel != null) ...[
                      _DecodeBadge(label: decodeLabel!),
                      const SizedBox(width: 8),
                    ],
                    // LIVE badge — doubles as a "back to live" tap target
                    // once the user has paused/rewound behind the live edge.
                    GestureDetector(
                      onTap: isBehindLive ? onGoLive : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isBehindLive ? Colors.white24 : Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isBehindLive) ...[
                              const Icon(Icons.fast_forward,
                                  color: Colors.white, size: 12),
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
                      ),
                    ),
                    const SizedBox(width: 8),
                    // CC button — always visible for live TV; dims when no
                    // tracks detected (embedded CEA-608/708 may appear late)
                    IconButton(
                      icon: Icon(
                        ccActive
                            ? Icons.closed_caption
                            : Icons.closed_caption_outlined,
                        color: ccActive
                            ? Colors.white
                            : (hasCc ? Colors.white54 : Colors.white24),
                      ),
                      tooltip: 'Subtitles / CC',
                      onPressed: onCc,
                    ),
                    // Favourite toggle
                    if (contentId != null && profile != null)
                      IconButton(
                        icon: Icon(
                          isFav ? Icons.star : Icons.star_border,
                          color: isFav
                              ? Theme.of(context).colorScheme.primary
                              : Colors.white,
                        ),
                        tooltip: isFav
                            ? 'Remove from Favorites'
                            : 'Add to Favorites',
                        onPressed: () => ref
                            .read(profileServiceProvider)
                            .toggleFavoriteChannel(profile.id, contentId!),
                      ),
                    // EPG button
                    IconButton(
                      icon: const Icon(Icons.list_alt),
                      color: Colors.white,
                      tooltip: 'TV Guide',
                      onPressed: onEpg,
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
                    IconButton(
                      icon: const Icon(Icons.replay_10,
                          color: Colors.white70, size: 32),
                      onPressed: onRewind,
                    ),
                    const SizedBox(width: 24),
                    StreamBuilder<bool>(
                      stream: player.stream.playing,
                      initialData: player.state.playing,
                      builder: (context, snap) {
                        final playing = snap.data ?? false;
                        return GestureDetector(
                          onTap: onPlayPause,
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
                    IconButton(
                      icon: const Icon(Icons.forward_10,
                          color: Colors.white70, size: 32),
                      onPressed: onForward,
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
    this.decodeLabel,
    this.onEpg,
    this.contentId,
    this.onGoLive,
  });

  final String title;
  final String? qualityLabel;
  final String? decodeLabel;
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
    final player = service.player;
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
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      color: Colors.white,
                      tooltip: 'Back',
                      onPressed: onBack,
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
                      const SizedBox(width: 4),
                    ],
                    if (decodeLabel != null) ...[
                      _DecodeBadge(label: decodeLabel!),
                      const SizedBox(width: 8),
                    ],
                    if (onGoLive != null) ...[
                      GestureDetector(
                        onTap: onGoLive,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'LIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (hasCc)
                      IconButton(
                        icon: Icon(
                          ccActive
                              ? Icons.closed_caption
                              : Icons.closed_caption_outlined,
                          color: ccActive ? Colors.white : Colors.white54,
                        ),
                        tooltip: 'Subtitles / CC',
                        onPressed: onCc,
                      ),
                    if (contentId != null && profile != null)
                      IconButton(
                        icon: Icon(
                          isFav ? Icons.star : Icons.star_border,
                          color: isFav
                              ? Theme.of(context).colorScheme.primary
                              : Colors.white,
                        ),
                        tooltip: isFav
                            ? 'Remove from Favorites'
                            : 'Add to Favorites',
                        onPressed: () => ref
                            .read(profileServiceProvider)
                            .toggleFavoriteChannel(profile.id, contentId!),
                      ),
                    if (onEpg != null)
                      IconButton(
                        icon: const Icon(Icons.list_alt),
                        color: Colors.white,
                        tooltip: 'TV Guide',
                        onPressed: onEpg,
                      ),
                  ],
                ),
              ),
            ),
            // Centre play/pause + skip zones
            Expanded(
              child: Row(
                children: [
                  // ‑10s double-tap zone
                  Expanded(
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
                  // Centre play/pause
                  StreamBuilder<bool>(
                    stream: player.stream.playing,
                    initialData: player.state.playing,
                    builder: (context, snap) {
                      final playing = snap.data ?? false;
                      return GestureDetector(
                        onTap: () => service.togglePlayPause(),
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
                  // +10s double-tap zone
                  Expanded(
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
// Shared badges
// ---------------------------------------------------------------------------

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

class _DecodeBadge extends StatelessWidget {
  const _DecodeBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isHw = label == 'HW';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isHw ? Colors.green.withValues(alpha: 0.3) : Colors.white12,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
            color: isHw ? Colors.greenAccent.withValues(alpha: 0.6) : Colors.white24),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isHw ? Colors.greenAccent : Colors.white54,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }
}
