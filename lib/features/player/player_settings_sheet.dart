import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_iptv/core/providers/theme_providers.dart';
import 'package:open_iptv/core/services/native_video_player.dart';
import 'package:open_iptv/core/services/playback_service.dart';
import 'package:open_iptv/core/storage/preferences.dart';
import 'package:open_iptv/features/player/player_ui.dart';
import 'package:open_iptv/l10n/gen/app_localizations.dart';

/// User-facing name for an audio or subtitle track: its own label, else its
/// language, else (captions) the caption channel. Numbered when several
/// tracks would otherwise read the same.
String playerTrackLabel(AppLocalizations l10n, NativeVideoTrack t, int index,
    List<NativeVideoTrack> all) {
  String base(NativeVideoTrack t) {
    if (t.label.isNotEmpty) return t.label;
    final lang = t.language;
    if (lang != null && lang.isNotEmpty && lang != 'und') {
      return _languageName(l10n, lang.toLowerCase()) ?? lang.toUpperCase();
    }
    final mime = t.mimeType ?? '';
    // Broadcast captions: CEA-608 channel 1 / CEA-708 service 1 are the
    // primary (almost always English) track; higher numbers are extras.
    if (mime.contains('608')) {
      return t.channel > 1
          ? l10n.playerCaptionsNumbered(t.channel)
          : l10n.playerCaptions;
    }
    if (mime.contains('708')) {
      return t.channel > 1
          ? l10n.playerDigitalCaptionsNumbered(t.channel)
          : l10n.playerDigitalCaptions;
    }
    return t.type == 'audio' ? l10n.playerAudio : l10n.playerSubtitles;
  }

  final name = base(t);
  final duplicated = all.where((o) => base(o) == name).length > 1;
  return duplicated ? '$name ${index + 1}' : name;
}

/// The language's name in the app language, or null when it isn't one of the
/// common ones (the caller then shows the raw code).
String? _languageName(AppLocalizations l10n, String code) => switch (code) {
      'en' || 'eng' => l10n.playerLangEn,
      'es' || 'spa' => l10n.playerLangEs,
      'fr' || 'fra' || 'fre' => l10n.playerLangFr,
      'de' || 'deu' || 'ger' => l10n.playerLangDe,
      'it' || 'ita' => l10n.playerLangIt,
      'pt' || 'por' => l10n.playerLangPt,
      'nl' || 'nld' => l10n.playerLangNl,
      'ar' || 'ara' => l10n.playerLangAr,
      'ru' || 'rus' => l10n.playerLangRu,
      'tr' || 'tur' => l10n.playerLangTr,
      'pl' || 'pol' => l10n.playerLangPl,
      'hi' || 'hin' => l10n.playerLangHi,
      'ja' || 'jpn' => l10n.playerLangJa,
      'ko' || 'kor' => l10n.playerLangKo,
      'zh' || 'zho' || 'chi' => l10n.playerLangZh,
      'el' || 'ell' || 'gre' => l10n.playerLangEl,
      'sv' || 'swe' => l10n.playerLangSv,
      'da' || 'dan' => l10n.playerLangDa,
      'no' || 'nor' => l10n.playerLangNo,
      'fi' || 'fin' => l10n.playerLangFi,
      'he' || 'heb' => l10n.playerLangHe,
      'ro' || 'ron' => l10n.playerLangRo,
      _ => null,
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
    final l10n = AppLocalizations.of(context);
    final service = ref.read(playbackServiceProvider);
    final text = _tracks.where((t) => t.type == 'text').toList();
    final audio = _tracks.where((t) => t.type == 'audio').toList();
    final selectedText = text.where((t) => t.selected).firstOrNull;
    final selectedAudio = audio.where((t) => t.selected).firstOrNull;
    final fit = ref.watch(videoFitProvider);
    final onlySubtitles = widget.focus == PlayerSettingsFocus.subtitles;

    return PlayerSheet(
      title: onlySubtitles ? l10n.playerSubtitles : l10n.playerSettingsTooltip,
      children: [
        OptionRow<String?>(
          icon: Icons.closed_caption_outlined,
          label: l10n.playerSubtitles,
          autofocusSelected: true,
          options: [
            (null, l10n.playerSubtitlesOff),
            for (final (i, t) in text.indexed)
              (t.id, playerTrackLabel(l10n, t, i, text)),
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
                  ? l10n.playerNoSubtitlesLive
                  : l10n.playerNoSubtitlesVideo,
              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
        if (!onlySubtitles) ...[
          if (audio.length > 1)
            OptionRow<String>(
              icon: Icons.graphic_eq_rounded,
              label: l10n.playerAudio,
              options: [
                for (final (i, t) in audio.indexed)
                  (t.id, playerTrackLabel(l10n, t, i, audio)),
              ],
              selected: selectedAudio?.id ?? '',
              onSelected: service.selectTrack,
            ),
          OptionRow<String>(
            icon: Icons.aspect_ratio_rounded,
            label: l10n.playerPicture,
            options: [
              ('fit', l10n.playerPictureFit),
              ('zoom', l10n.playerPictureZoom),
              ('fill', l10n.playerPictureFill),
            ],
            selected: fit,
            onSelected: (v) async {
              final prefs = await ref.read(appPreferencesProvider.future);
              await setVideoFit(ref, v, prefs);
            },
          ),
          OptionRow<bool>(
            icon: Icons.schedule_rounded,
            label: l10n.playerClock,
            options: [
              (false, l10n.playerClockWithControls),
              (true, l10n.playerClockAlwaysOn),
            ],
            selected: ref.watch(playerClockAlwaysProvider),
            onSelected: (v) async {
              final prefs = await ref.read(appPreferencesProvider.future);
              await setPlayerClockAlways(ref, v, prefs);
            },
          ),
          OptionRow<int>(
            icon: Icons.sync_rounded,
            label: l10n.playerAudioDelay,
            options: [
              for (final ms in const [-500, -300, -200, -100, 0, 100, 200, 300, 500, 1000])
                (ms, ms == 0 ? l10n.playerAudioDelayNone : '${ms > 0 ? '+' : '−'}${ms.abs()} ms'),
            ],
            selected: ref.watch(audioDelayProvider),
            onSelected: (v) async {
              final prefs = await ref.read(appPreferencesProvider.future);
              await setAudioDelay(ref, v, prefs);
            },
          ),
          OptionRow<bool>(
            icon: Icons.info_outline_rounded,
            label: l10n.playerStreamDetailsLabel,
            options: [
              (true, l10n.playerShow),
              (false, l10n.playerHide),
            ],
            selected: ref.watch(streamDetailsProvider),
            onSelected: (v) async {
              final prefs = await ref.read(appPreferencesProvider.future);
              await setStreamDetails(ref, v, prefs);
            },
          ),
          if (!widget.isLive)
            OptionRow<double>(
              icon: Icons.speed_rounded,
              label: l10n.playerSpeed,
              options: [
                for (final s in _speeds)
                  (s, s == 1.0 ? l10n.playerSpeedNormal : '${_trim(s)}×'),
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
