import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:open_iptv/app.dart';
import 'package:open_iptv/core/services/auto_refresh_service.dart';
import 'package:open_iptv/core/services/now_playing_service.dart';
import 'package:open_iptv/core/services/playback_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await initAutoRefresh();

  // Built here (rather than implicitly by ProviderScope) so the same
  // PlaybackService singleton can be handed to audio_service before runApp —
  // the Now Playing notification must mirror the exact Player instance the
  // rest of the app plays through, not a separate one.
  final container = ProviderContainer();
  await initNowPlayingService(container.read(playbackServiceProvider));

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const OpenIPTVApp(),
    ),
  );
}
