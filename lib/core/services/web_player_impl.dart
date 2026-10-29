// Web-only video engine for OpenIPTV. Imported only on web (see the
// conditional import in native_video_player.dart), so it may use dart:html,
// dart:js_interop freely — none of which exist on native.
//
// One [WebPlaybackEngine] owns one HTML <video> element. HLS streams are fed
// through hls.js, MPEG-TS (.ts) through mpegts.js, and plain progressive
// MP4/M4V fall back to the element's own <video src>. Playback state is
// reported by polling the element plus a few media events, because the web
// has no ExoPlayer-style event channel.
import 'dart:async';
import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
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

/// hls.js's `Hls` class (loaded from web/lib/hls.min.js).
@JS('Hls')
extension type _Hls._(JSObject _) implements JSObject {
  external factory _Hls();
  external static JSBoolean isSupported();
  external static JSObject get Events;
  external void on(JSString event, JSFunction callback);
  external void loadSource(JSString url);
  external void attachMedia(JSObject video);
  external JSArray<JSAny?> getAudioTracks();
  external JSArray<JSAny?>? get subtitleTracks;
  external void destroy();
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

  _Hls? _hls;
  JSObject? _mpegts;
  Timer? _poll;
  bool _started = false;
  bool _buffering = false;
  bool _ended = false;
  // The viewer wants it playing (cleared by pause()). A browser also pauses a
  // <video> whenever it is removed from the page, which Flutter does when it
  // re-parents the platform view on a layout change — that isn't the user.
  bool _wantPlaying = true;
  // Set when the element (or something holding it) has just been taken out of
  // the page, so the pause event that follows is the browser's doing, not the
  // viewer's. Checking isConnected in the pause handler isn't enough: Flutter
  // puts the element straight back, and the event is delivered after that.
  bool _detachedPause = false;
  Timer? _detachedClear;
  html.MutationObserver? _removals;

  // ---- lifecycle ---------------------------------------------------------

  Future<void> open(
    String url, {
    String? streamTypeHint,
    bool audioFocus = true,
  }) async {
    _teardown();
    _started = false;
    _ended = false;
    _wantPlaying = true;
    _buffering = false;
    final kind = (streamTypeHint ?? _guessKind(url)).toLowerCase();
    _kind = kind;
    _buffering = true;
    _emit();
    final attempt = ++_openAttempt;
    if (kind == 'hls' || kind == 'm3u8') {
      await _ensureScript('lib/hls.min.js');
      if (attempt != _openAttempt) return; // a newer open() took over
      _openHls(url);
    } else if (kind == 'mpegts' || kind == 'ts' || kind == 'mpeg-tsv') {
      await _ensureScript('lib/mpegts.min.js');
      if (attempt != _openAttempt) return;
      _openMpegts(url);
    } else {
      _openProgressive(url);
    }
  }

  // The hls.js / mpegts.js bundles (about 175 KB gzipped) are only fetched
  // when a stream needs them, so they don't hold up the first paint; the page
  // prefetches them at low priority so they're usually already cached.
  static final _scripts = <String, Future<void>>{};
  int _openAttempt = 0;

  static Future<void> _ensureScript(String src) {
    return _scripts.putIfAbsent(src, () {
      final done = Completer<void>();
      final tag = html.ScriptElement()
        ..src = src
        ..async = true;
      tag.onLoad.first.then((_) => done.complete());
      tag.onError.first.then((_) {
        tag.remove();
        _scripts.remove(src); // let the next open() try again
        // Not fatal: _openHls / _openMpegts fall back to <video src>.
        done.complete();
      });
      html.document.head!.append(tag);
      return done.future;
    });
  }

  void _openProgressive(String url) {
    video.src = url;
    video.load();
    _started = true;
    video.play();
  }

  void _openHls(String url) {
    // `Hls` is a class on window; if hls.js didn't load (or the browser lacks
    // Media Source Extensions) fall back to <video src>, which is what Safari
    // plays natively.
    if (!globalContext.has('Hls') || !_Hls.isSupported().toDart) {
      _openProgressive(url);
      return;
    }
    final hls = _Hls();
    _hls = hls;
    final events = _Hls.Events;
    hls.on(
      events.getProperty<JSString>('MANIFEST_PARSED'.toJS),
      ((JSAny? _, JSAny? __) => _onManifest()).toJS,
    );
    hls.on(
      events.getProperty<JSString>('ERROR'.toJS),
      ((JSAny? _, JSAny? data) => _onHlsError(data)).toJS,
    );
    hls.on(
      events.getProperty<JSString>('FRAG_LOADED'.toJS),
      ((JSAny? _, JSAny? __) {
        _started = true;
        _buffering = false;
        _emit();
      }).toJS,
    );
    hls.loadSource(url.toJS);
    hls.attachMedia(video as JSObject);
  }

  void _openMpegts(String url) {
    final mpegts = globalContext.getProperty<JSAny?>('mpegts'.toJS);
    if (mpegts == null) {
      _openProgressive(url);
      return;
    }
    mpegts as JSObject;
    final config = JSObject()
      ..['type'] = 'mpegts'.toJS
      ..['url'] = url.toJS
      ..['isLive'] = true.toJS;
    final player =
        mpegts.callMethodVarArgs<JSObject>('createPlayer'.toJS, [config]);
    _mpegts = player;
    player.callMethodVarArgs('attachMediaElement'.toJS, [video as JSObject]);
    final events = mpegts.getProperty<JSObject>('Events'.toJS);
    player.callMethodVarArgs('on'.toJS, [
      events.getProperty<JSAny?>('ERROR'.toJS),
      ((JSAny? _, JSAny? __) => _emit()).toJS,
    ]);
    player.callMethodVarArgs('load'.toJS, []);
    player.callMethodVarArgs('play'.toJS, []);
    _started = true;
  }

  void _onManifest() {
    _started = true;
    _buffering = false;
    video.play();
    _emit();
  }

  void _onHlsError(JSAny? data) {
    // hls.js recovers from most errors itself; only surface a hard fatal one.
    final fatal = (data as JSObject?)?.getProperty<JSAny?>('fatal'.toJS);
    if (fatal.isA<JSBoolean>() && (fatal as JSBoolean).toDart) {
      _buffering = false;
    }
    _emit();
  }

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
    // Mutation callbacks run before the pause event they cause, so they can
    // flag it in time.
    _removals = html.MutationObserver((mutations, _) {
      for (final m in mutations) {
        final removed = (m as html.MutationRecord).removedNodes ?? const [];
        if (removed.any((n) => n == video || (n.contains(video)))) {
          _detachedPause = true;
          _detachedClear?.cancel();
          _detachedClear = Timer(const Duration(milliseconds: 500), () {
            _detachedPause = false;
          });
          return;
        }
      }
    })..observe(html.document.body!, childList: true, subtree: true);
    video.onPause.listen((_) {
      if (_detachedPause) {
        _detachedPause = false; // the browser paused it; keep wanting to play
      } else {
        _wantPlaying = false; // a real pause
      }
      _emit();
    });
    video.onEnded.listen((_) {
      _ended = true;
      _emit();
    });
    video.onLoadedMetadata.listen((_) => _emit());
    // Time updates carry the position; throttle to ~4Hz in the poll instead.
    _poll = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (_wantPlaying &&
          _started &&
          !_ended &&
          video.paused &&
          (video.isConnected ?? false)) {
        video.play().catchError((_) {});
      }
      _emit();
    });
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
    _wantPlaying = true;
    video.play().catchError((_) {});
  }

  void pause() {
    _wantPlaying = false;
    video.pause();
  }

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
    if (hls == null) return out;
    void collect(JSAny? list, String type) {
      if (list == null) return;
      final arr = (list as JSArray<JSAny?>).toDart;
      for (var i = 0; i < arr.length; i++) {
        final t = arr[i] as JSObject;
        String? str(String k) =>
            (t.getProperty<JSAny?>(k.toJS) as JSString?)?.toDart;
        final id = t.getProperty<JSAny?>('id'.toJS);
        out.add(WebTrack(
          id: id == null ? i.toString() : id.dartify().toString(),
          type: type,
          label: str('name') ?? '',
          language: str('lang'),
          selected: (t.getProperty<JSAny?>('selected'.toJS) as JSBoolean?)
                  ?.toDart ??
              false,
        ));
      }
    }

    collect(hls.getAudioTracks(), 'audio');
    collect(hls.subtitleTracks, 'text');
    return out;
  }

  Future<void> dispose() async {
    _poll?.cancel();
    _poll = null;
    _removals?.disconnect();
    _removals = null;
    _detachedClear?.cancel();
    _teardown();
  }

  /// Drops the current stream's hls.js / mpegts.js instance but keeps the
  /// element and its polling timer, so the engine can open the next channel.
  void _teardown() {
    final hls = _hls;
    if (hls != null) {
      hls.destroy();
    }
    final mpegts = _mpegts;
    if (mpegts != null) {
      mpegts.callMethodVarArgs('destroy'.toJS, []);
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
