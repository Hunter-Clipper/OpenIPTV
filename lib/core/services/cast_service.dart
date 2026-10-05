import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_iptv/ui/platform_helper.dart';

/// A cast device found on the network.
@immutable
class CastDevice {
  const CastDevice(this.id, this.name, {this.speaker = false});
  final String id;
  final String name;

  /// An audio-only device (speaker / speaker group).
  final bool speaker;
}

enum CastSessionState { idle, connecting, connected }

enum CastPlayerState { idle, buffering, playing, paused }

/// Snapshot of casting, pushed by the native CastController.
@immutable
class CastStatus {
  const CastStatus({
    this.supported = false,
    this.available = false,
    this.session = CastSessionState.idle,
    this.device,
    this.devices = const [],
    this.playerState = CastPlayerState.idle,
    this.idleReason,
    this.contentId,
    this.title,
    this.subtitle,
    this.live = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.volume = 0,
  });

  factory CastStatus.fromMap(Map<dynamic, dynamic> m) => CastStatus(
        supported: m['supported'] == true,
        available: m['available'] == true,
        session: switch (m['session']) {
          'connected' => CastSessionState.connected,
          'connecting' => CastSessionState.connecting,
          _ => CastSessionState.idle,
        },
        device: m['device'] as String?,
        devices: [
          for (final d in (m['devices'] as List? ?? const []))
            CastDevice('${(d as Map)['id']}', '${d['name']}',
                speaker: d['speaker'] == true),
        ],
        playerState: switch (m['playerState']) {
          'playing' => CastPlayerState.playing,
          'paused' => CastPlayerState.paused,
          'buffering' => CastPlayerState.buffering,
          _ => CastPlayerState.idle,
        },
        idleReason: m['idleReason'] as String?,
        contentId: m['contentId'] as String?,
        title: m['title'] as String?,
        subtitle: m['subtitle'] as String?,
        live: m['live'] == true,
        position: Duration(milliseconds: (m['positionMs'] as num?)?.toInt() ?? 0),
        duration: Duration(milliseconds: (m['durationMs'] as num?)?.toInt() ?? 0),
        volume: (m['volume'] as num?)?.toDouble() ?? 0,
      );

  /// Play Services and the Cast framework are present.
  final bool supported;

  /// At least one cast device is on the network.
  final bool available;
  final CastSessionState session;

  /// Name of the connected device.
  final String? device;

  /// Devices found while discovery runs (the picker is open).
  final List<CastDevice> devices;
  final CastPlayerState playerState;

  /// Why the receiver went idle: 'error', 'finished', 'canceled', …
  final String? idleReason;

  /// URL currently loaded on the receiver.
  final String? contentId;

  /// What's loaded on the receiver (set by whichever device cast it).
  final String? title;
  final String? subtitle;
  final bool live;
  final Duration position;
  final Duration duration;
  final double volume;

  bool get connected => session == CastSessionState.connected;

  /// Connected with something loaded on the receiver.
  bool get hasMedia => connected && contentId != null;
}

/// Casting to Chromecast / Google TV ("openiptv/cast"). Safe to use where
/// casting isn't supported: [status] just stays unavailable.
class CastService {
  /// [enabled] is false on TVs (Android TV, Google TV, Fire TV): they are
  /// the screen, so casting is off — no native side, every call a no-op.
  CastService({bool? enabled}) : enabled = enabled ?? !PlatformHelper.isTVDevice {
    if (this.enabled) _listen();
  }

  final bool enabled;

  // The Flutter engine is shared with audio_service and can run Dart before
  // MainActivity registers the cast channels (see isTelevisionDevice), so
  // early calls are retried until the native side is there.
  static const _retryFor = Duration(seconds: 10);
  static const _retryEvery = Duration(milliseconds: 300);

  // A stream subscribed before the native handler exists never receives
  // anything (Flutter only logs the failed 'listen'), so wait until the
  // native side answers before subscribing.
  Future<void> _listen() async {
    final deadline = DateTime.now().add(_retryFor);
    while (true) {
      try {
        await _channel.invokeMethod<void>('ping');
        break;
      } on MissingPluginException {
        if (DateTime.now().isAfter(deadline)) return;
        await Future<void>.delayed(_retryEvery);
      } on PlatformException {
        break;
      }
    }
    _events.receiveBroadcastStream().listen((e) {
      if (e is Map) {
        _status = CastStatus.fromMap(e);
        _controller.add(_status);
      }
    }, onError: (_) {});
  }

  static const _channel = MethodChannel('openiptv/cast');
  static const _events = EventChannel('openiptv/cast_events');

  final _controller = StreamController<CastStatus>.broadcast();
  CastStatus _status = const CastStatus();

  CastStatus get status => _status;
  Stream<CastStatus> get statusStream => _controller.stream;

  Future<void> _call(String method, [Map<String, Object?>? args]) async {
    if (!enabled) return;
    final deadline = DateTime.now().add(_retryFor);
    try {
      while (true) {
        try {
          await _channel.invokeMethod<void>(method, args);
          return;
        } on MissingPluginException {
          // Not registered yet (early startup) — or no native side at all
          // (tests, other platforms): give up after a while.
          if (DateTime.now().isAfter(deadline)) return;
          await Future<void>.delayed(_retryEvery);
        }
      }
    } on PlatformException catch (e) {
      debugPrint('[OTV-cast] $method failed: ${e.code}');
    }
  }

  Future<void> startDiscovery() => _call('startDiscovery');
  Future<void> stopDiscovery() => _call('stopDiscovery');
  Future<void> connect(CastDevice d) => _call('connect', {'id': d.id});
  Future<void> disconnect() => _call('disconnect');
  Future<void> play() => _call('play');
  Future<void> pause() => _call('pause');
  Future<void> seek(Duration to) =>
      _call('seek', {'positionMs': to.inMilliseconds});
  Future<void> setVolume(double v) => _call('setVolume', {'volume': v});

  /// Plays [streamUrl] on the connected device, trying each of
  /// [castCandidates] in turn. Returns the URL the receiver accepted, or
  /// null if it couldn't play any of them.
  Future<String?> load({
    required String streamUrl,
    required String title,
    required bool live,
    String? subtitle,
    String? imageUrl,
    Duration? start,
  }) async {
    if (!enabled) return null;
    for (final url in castCandidates(streamUrl, live: live)) {
      try {
        final ok = await _channel.invokeMethod<bool>('load', {
          'url': url,
          'contentType': castContentType(url),
          'live': live,
          'title': title,
          'subtitle': subtitle,
          'imageUrl': imageUrl,
          'startMs': start?.inMilliseconds ?? 0,
        });
        if (ok == true) return url;
      } on MissingPluginException {
        return null;
      } on PlatformException {
        // Try the next candidate.
      }
    }
    return null;
  }
}

final castServiceProvider = Provider<CastService>((ref) => CastService());

final castStatusProvider = StreamProvider<CastStatus>((ref) {
  final service = ref.watch(castServiceProvider);
  return service.statusStream;
});

/// URLs to try on a cast receiver, best first. Google's built-in receiver
/// plays HLS and MP4 but often not MPEG-TS, which is how Xtream panels hand
/// out live channels — so for those the HLS variant of the same channel
/// (`…/live/u/p/123.m3u8`, served by panels that allow the m3u8 output
/// format) is tried before the original link.
@visibleForTesting
List<String> castCandidates(String url, {required bool live}) {
  final uri = Uri.tryParse(url);
  if (uri == null) return [url];
  final path = uri.path;
  final xtreamLive = RegExp(r'/live/[^/]+/[^/]+/[^/]+\.ts$');
  if (live && xtreamLive.hasMatch(path)) {
    final hls = uri.replace(path: path.replaceFirst(RegExp(r'\.ts$'), '.m3u8'));
    return [hls.toString(), url];
  }
  return [url];
}

/// MIME type for a stream URL, from its extension.
@visibleForTesting
String castContentType(String url) {
  final path = (Uri.tryParse(url)?.path ?? url).toLowerCase();
  if (path.endsWith('.m3u8') || path.endsWith('.m3u')) {
    return 'application/x-mpegURL';
  }
  if (path.endsWith('.ts')) return 'video/mp2t';
  if (path.endsWith('.mkv')) return 'video/x-matroska';
  if (path.endsWith('.webm')) return 'video/webm';
  if (path.endsWith('.mp3')) return 'audio/mpeg';
  if (path.endsWith('.aac')) return 'audio/aac';
  return 'video/mp4';
}
