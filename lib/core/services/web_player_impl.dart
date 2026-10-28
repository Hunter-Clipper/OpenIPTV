// Web-only video engine for OpenIPTV. Imported only on web (see the
// conditional import in native_video_player.dart), so it may use dart:html,
// dart:js and dart:js_util freely — none of which exist on native.
//
// One [WebPlaybackEngine] owns one HTML <video> element. HLS streams are fed
// through hls.js, MPEG-TS (.ts) through mpegts.js, and plain progressive
// MP4/M4V fall back to the element's own <video src>. Playback state is
// reported by polling the element plus a few media events, because the web
// has no ExoPlayer-style event channel.
import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:js_util' as jsu;
import 'dart:ui_web' as ui_web;

/// One audio or subtitle track surfaced to the UI, mirroring the native
/// [NativeVideoTrack] shape but defined here so this file has no dependency
/// on the (native) player class — that would make the conditional import
/// circular.
class WebTrack {
  WebTrack({
    required this.id,
    required this.type,
    required this.label,
    this.language,
    required this.selected,
    this.mimeType,
    this.channel = -1,
  });
  final String id;
  // 'audio' or 'text' (subtitle/CC), matching the native naming.
  final String type;
  final String label;
  final String? language;
  final bool selected;
  final String? mimeType;
  final int channel;
}

/// A point-in-time playback snapshot, mapped to [NativeVideoPlayerState] by
/// the player on the other side of the conditional import.
class WebSnapshot {
  WebSnapshot({
    required this.position,
    required this.duration,
    required this.playing,
    required this.buffering,
    required this.completed,
    required this.videoWidth,
    required this.videoHeight,
  });
  final double position; // seconds
  final double duration; // seconds; 0 for live/unknown
  final bool playing;
  final bool buffering;
  final bool completed;
  final int videoWidth;
  final int videoHeight;
}

int _viewCounter = 0;

class WebPlaybackEngine {
  WebPlaybackEngine({required this.onState}) {
    video = html.document.createElement('video') as html.VideoElement
      ..autoplay = true
      ..setAttribute('playsinline', '')
      ..preload = 'auto'
      ..style.objectFit = 'contain'
      ..style.width = '100%'
      ..style.height = '100%';
    _wireEvents();
    // Render this element inside a Flutter HtmlElementView. Each engine gets a
    // unique viewType, which the surface rebuilds from the player's textureId.
    ui_web.platformViewRegistry
        .registerViewFactory(viewType, (int id) => video);
  }

  /// The unique platform-view type this engine registered; the web surface
  /// uses `HtmlElementView(viewType)` to show this engine's <video>.
  late final int webId = _viewCounter++;
  late final String viewType = 'openiptv-web-video-$webId';

  late final html.VideoElement video;
  final void Function(WebSnapshot) onState;

  js.JsObject? _hls;
  js.JsObject? _mpegts;
  Timer? _poll;
  bool _started = false;
  bool _buffering = false;
  bool _ended = false;

  // ---- lifecycle ---------------------------------------------------------

  Future<void> open(
    String url, {
    String? streamTypeHint,
    bool audioFocus = true,
  }) async {
    dispose();
    _started = false;
    _ended = false;
    _buffering = false;
    final kind = (streamTypeHint ?? _guessKind(url)).toLowerCase();
    _kind = kind;
    _buffering = true;
    _emit();
    if (kind == 'hls' || kind == 'm3u8') {
      _openHls(url);
    } else if (kind == 'mpegts' || kind == 'ts' || kind == 'mpeg-tsv') {
      _openMpegts(url);
    } else {
      _openProgressive(url);
    }
  }

  void _openProgressive(String url) {
    video.src = url;
    video.load();
    _started = true;
    video.play();
  }

  void _openHls(String url) {
    final ctx = js.context;
    final hlsCtor = jsu.getProperty(ctx, 'Hls');
    if (hlsCtor == null || !jsu.callMethod(hlsCtor, 'isSupported', []) as bool) {
      // Safari / unsupported browser: fall back to native <video> src (works
      // for HLS in Safari, and is harmless elsewhere — it just won't play).
      _openProgressive(url);
      return;
    }
    // new Hls() with default config; hls.js has sane defaults.
    final hls = jsu.callConstructor(hlsCtor, <Object?>[]) as js.JsObject;
    _hls = hls;
    final events = jsu.getProperty(hls, 'Events') as js.JsObject;
    jsu.callMethod(
        hls, 'on', [jsu.getProperty(events, 'MANIFEST_PARSED'), _onManifest]);
    jsu.callMethod(hls, 'on', [jsu.getProperty(events, 'ERROR'), _onHlsError]);
    jsu.callMethod(hls, 'on', [
      jsu.getProperty(events, 'FRAG_LOADED'),
      jsu.allowInterop((_) {
        _started = true;
        _buffering = false;
        _emit();
      })
    ]);
    jsu.callMethod(hls, 'loadSource', [url]);
    jsu.callMethod(hls, 'attachMedia', [video]);
  }

  void _openMpegts(String url) {
    final ctx = js.context;
    final mpegts = jsu.getProperty(ctx, 'mpegts');
    if (mpegts == null) {
      _openProgressive(url);
      return;
    }
    final config = js.JsObject.jsify(<String, dynamic>{
      'type': 'mpegts',
      'url': url,
      'isLive': true,
    });
    final player =
        jsu.callMethod(mpegts, 'createPlayer', [config]) as js.JsObject;
    _mpegts = player;
    jsu.callMethod(player, 'attachMediaElement', [video]);
    jsu.callMethod(player, 'generateScript', <Object?>[]);
    jsu.callMethod(player, 'play', <Object?>[]);
    jsu.callMethod(
        player, 'on', [jsu.getProperty(mpegts, 'Events').getProperty('ERROR'), _onMpegtsError]);
    _started = true;
  }

  void _onManifest(Object? _e) {
    _started = true;
    _buffering = false;
    video.play();
    _emit();
  }

  void _onHlsError(Object? data) {
    // hls.js recovers from most errors itself; only surface a hard fatal one.
    final fatal = jsu.getProperty(data as js.JsObject, 'fatal');
    if (fatal == true) _buffering = false;
    _emit();
  }

  void _onMpegtsError(Object? _e) => _emit();

  void _wireEvents() {
    video.onWaiting.listen((_) {
      _buffering = true;
      _emit();
    });
    video.onCanPlay.listen((_) {
      _buffering = false;
      _emit();
    });
    video.onCanPlayThrough.listen((_) {
      _buffering = false;
      _emit();
    });
    video.onPlay.listen((_) {
      _started = true;
      _buffering = false;
      _emit();
    });
    video.onPause.listen((_) => _emit());
    video.onEnded.listen((_) {
      _ended = true;
      _emit();
    });
    video.onLoadedMetadata.listen((_) => _emit());
    // Time updates carry the position; throttle to ~4Hz in the poll instead.
    _poll = Timer.periodic(const Duration(milliseconds: 250), (_) => _emit());
  }

  WebSnapshot _snapshot() => WebSnapshot(
        position: video.currentTime.isFinite ? video.currentTime.toDouble() : 0.0,
        duration: video.duration.isFinite ? video.duration.toDouble() : 0.0,
        playing: _started && !video.paused && !_ended,
        buffering: _buffering,
        completed: _ended,
        videoWidth: video.videoWidth,
        videoHeight: video.videoHeight,
      );

  void _emit() => onState(_snapshot());

  // ---- transport controls ------------------------------------------------

  void play() {
    _started = true;
    video.play();
  }

  void pause() => video.pause();

  Future<void> seekTo(double seconds) async {
    video.currentTime = seconds;
    _emit();
  }

  void setSpeed(double speed) => video.playbackRate = speed;

  void setAudible(bool on) => video.muted = !on;

  /// Whether this engine currently has a live/unknown-length stream, so the
  /// UI can hide the scrubber the way it does for live native playback.
  bool get isLive => _kind == 'hls' || _kind == 'mpegts';
  String? _kind;

  List<WebTrack> tracks() {
    final out = <WebTrack>[];
    final hls = _hls;
    if (hls != null) {
      final audio =
          jsu.callMethod(hls, 'getAudioTracks', <Object?>[]) as js.JsArray;
      for (var i = 0; i < audio.length; i++) {
        final t = audio[i] as js.JsObject;
        out.add(WebTrack(
          id: (jsu.getProperty(t, 'id') ?? i.toString()),
          type: 'audio',
          label: (jsu.getProperty(t, 'name') ?? '') as String,
          language: jsu.getProperty(t, 'lang') as String?,
          selected: jsu.getProperty(t, 'selected') == true,
        ));
      }
      final subs = jsu.getProperty(hls, 'subtitleTracks') as js.JsArray? ??
          js.JsArray();
      for (var i = 0; i < subs.length; i++) {
        final t = subs[i] as js.JsObject;
        out.add(WebTrack(
          id: (jsu.getProperty(t, 'id') ?? i.toString()),
          type: 'text',
          label: (jsu.getProperty(t, 'name') ?? '') as String,
          language: jsu.getProperty(t, 'lang') as String?,
          selected: jsu.getProperty(t, 'selected') == true,
        ));
      }
    }
    return out;
  }

  Future<void> dispose() async {
    _poll?.cancel();
    _poll = null;
    final hls = _hls;
    if (hls != null) {
      jsu.callMethod(hls, 'destroy', <Object?>[]);
    }
    final mpegts = _mpegts;
    if (mpegts != null) {
      jsu.callMethod(mpegts, 'destroy', <Object?>[]);
    }
    _hls = null;
    _mpegts = null;
    try {
      video.pause();
    } catch (_) {}
  }

  static String _guessKind(String url) {
    final q = url.split('?').first.toLowerCase();
    if (q.endsWith('.m3u8')) return 'hls';
    if (q.endsWith('.ts')) return 'mpegts';
    return 'progressive';
  }
}
