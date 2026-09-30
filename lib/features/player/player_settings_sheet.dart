import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_iptv/core/providers/theme_providers.dart';
import 'package:open_iptv/core/services/native_video_player.dart';
import 'package:open_iptv/core/services/playback_service.dart';
import 'package:open_iptv/core/storage/preferences.dart';
import 'package:open_iptv/features/player/player_ui.dart';

/// User-facing name for an audio or subtitle track: its own label, else its
/// language, else (captions) the caption channel. Numbered when several
/// tracks would otherwise read the same.
String playerTrackLabel(
    NativeVideoTrack t, int index, List<NativeVideoTrack> all) {
  String base(NativeVideoTrack t) {
    if (t.label.isNotEmpty) return t.label;
    final lang = t.language;
    if (lang != null && lang.isNotEmpty && lang != 'und') {
      return _languageNames[lang.toLowerCase()] ?? lang.toUpperCase();
    }
    final mime = t.mimeType ?? '';
    // Broadcast captions: CEA-608 channel 1 / CEA-708 service 1 are the
    // primary (almost always English) track; higher numbers are extras.
    if (mime.contains('608')) {
      return t.channel > 1 ? 'Captions ${t.channel}' : 'Captions';
    }
    if (mime.contains('708')) {
      return t.channel > 1
          ? 'Digital captions ${t.channel}'
          : 'Digital captions';
    }
    return t.type == 'audio' ? 'Audio' : 'Subtitles';
  }

  final name = base(t);
  final duplicated = all.where((o) => base(o) == name).length > 1;
  return duplicated ? '$name ${index + 1}' : name;
}

const _languageNames = {
  'en': 'English', 'eng': 'English', 'es': 'Spanish', 'spa': 'Spanish',
  'fr': 'French', 'fra': 'French', 'fre': 'French', 'de': 'German',
  'deu': 'German', 'ger': 'German', 'it': 'Italian', 'ita': 'Italian',
  'pt': 'Portuguese', 'por': 'Portuguese', 'nl': 'Dutch', 'nld': 'Dutch',
  'ar': 'Arabic', 'ara': 'Arabic', 'ru': 'Russian', 'rus': 'Russian',
  'tr': 'Turkish', 'tur': 'Turkish', 'pl': 'Polish', 'pol': 'Polish',
  'hi': 'Hindi', 'hin': 'Hindi', 'ja': 'Japanese', 'jpn': 'Japanese',
  'ko': 'Korean', 'kor': 'Korean', 'zh': 'Chinese', 'zho': 'Chinese',
  'chi': 'Chinese', 'el': 'Greek', 'ell': 'Greek', 'gre': 'Greek',
  'sv': 'Swedish', 'swe': 'Swedish', 'da': 'Danish', 'dan': 'Danish',
  'no': 'Norwegian', 'nor': 'Norwegian', 'fi': 'Finnish', 'fin': 'Finnish',
  'he': 'Hebrew', 'heb': 'Hebrew', 'ro': 'Romanian', 'ron': 'Romanian',
};

/// Which part of the sheet to show: everything (the gear button) or only
/// subtitles (the CC button).
enum PlayerSettingsFocus { all, subtitles }

/// The player's settings: subtitles, audio track, picture fit and — for
/// movies and episodes — playback speed. Changes apply instantly.
class PlayerSettingsSheet extends ConsumerStatefulWidget {
  const PlayerSettingsSheet({
    super.key,
    required this.isLive,
    this.focus = PlayerSettingsFocus.all,
  });

  final bool isLive;
  final PlayerSettingsFocus focus;

  @override
  ConsumerState<PlayerSettingsSheet> createState() =>
      _PlayerSettingsSheetState();
}

class _PlayerSettingsSheetState extends ConsumerState<PlayerSettingsSheet> {
  StreamSubscription<List<NativeVideoTrack>>? _sub;
  List<NativeVideoTrack> _tracks = const [];

  static const _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  void initState() {
    super.initState();
    final service = ref.read(playbackServiceProvider);
    service.getTracks().then((t) {
      if (mounted) setState(() => _tracks = t);
    });
    _sub = service.tracksStream.listen((t) {
      if (mounted) setState(() => _tracks = t);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(playbackServiceProvider);
    final text = _tracks.where((t) => t.type == 'text').toList();
    final audio = _tracks.where((t) => t.type == 'audio').toList();
    final selectedText = text.where((t) => t.selected).firstOrNull;
    final selectedAudio = audio.where((t) => t.selected).firstOrNull;
    final fit = ref.watch(videoFitProvider);
    final onlySubtitles = widget.focus == PlayerSettingsFocus.subtitles;

    return PlayerSheet(
      title: onlySubtitles ? 'Subtitles' : 'Playback settings',
      children: [
        OptionRow<String?>(
          icon: Icons.closed_caption_outlined,
          label: 'Subtitles',
          autofocusSelected: true,
          options: [
            (null, 'Off'),
            for (final (i, t) in text.indexed)
              (t.id, playerTrackLabel(t, i, text)),
          ],
          selected: selectedText?.id,
          onSelected: (id) {
            if (id == null) {
              service.clearTextTrack();
            } else {
              service.selectTrack(id);
            }
          },
        ),
        if (text.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: Text(
              widget.isLive
                  ? 'No subtitles detected on this channel yet. Captions '
                      'appear here as soon as the broadcast sends them.'
                  : 'This video has no subtitles.',
              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
        if (!onlySubtitles) ...[
          if (audio.length > 1)
            OptionRow<String>(
              icon: Icons.graphic_eq_rounded,
              label: 'Audio',
              options: [
                for (final (i, t) in audio.indexed)
                  (t.id, playerTrackLabel(t, i, audio)),
              ],
              selected: selectedAudio?.id ?? '',
              onSelected: service.selectTrack,
            ),
          OptionRow<String>(
            icon: Icons.aspect_ratio_rounded,
            label: 'Picture',
            options: const [
              ('fit', 'Fit'),
              ('zoom', 'Zoom'),
              ('fill', 'Fill screen'),
            ],
            selected: fit,
            onSelected: (v) async {
              final prefs = await ref.read(appPreferencesProvider.future);
              await setVideoFit(ref, v, prefs);
            },
          ),
          if (!widget.isLive)
            OptionRow<double>(
              icon: Icons.speed_rounded,
              label: 'Speed',
              options: [
                for (final s in _speeds)
                  (s, s == 1.0 ? 'Normal' : '${_trim(s)}×'),
              ],
              selected: service.speed,
              onSelected: (v) async {
                await service.setSpeed(v);
                if (mounted) setState(() {});
              },
            ),
        ],
      ],
    );
  }

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v';
}
