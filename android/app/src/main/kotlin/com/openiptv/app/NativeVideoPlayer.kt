package com.openiptv.app

import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.media3.common.C
import androidx.media3.common.Format
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.ParserException
import androidx.media3.common.Player
import androidx.media3.common.TrackSelectionOverride
import androidx.media3.common.Tracks
import androidx.media3.common.text.CueGroup
import androidx.media3.common.util.TimestampAdjuster
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.hls.HlsMediaSource
import androidx.media3.exoplayer.source.MediaSource
import androidx.media3.exoplayer.source.ProgressiveMediaSource
import androidx.media3.extractor.Extractor
import androidx.media3.extractor.ExtractorsFactory
import androidx.media3.extractor.ts.DefaultTsPayloadReaderFactory
import androidx.media3.extractor.ts.TsExtractor
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry

/**
 * Prototype native video engine replacing media_kit/mpv — see the plan doc
 * for why: mpv's hardware decoder was repeatedly resetting on a real
 * low-end Android TV device with a glitchy real-world IPTV stream.
 * ExoPlayer/Media3 is what most production Android/Android TV apps ship
 * for exactly this reason (far more battle-tested against the fragmented
 * Android decoder landscape than mpv).
 *
 * One instance per texture/surface. Rendered into a TextureRegistry
 * SurfaceTexture (see the field comment for why not a SurfaceProducer)
 * rather than a full native PlatformView — simpler and composes better
 * with Flutter (including PiP) since it's just a GPU texture, no view
 * hierarchy overlay.
 */
class NativeVideoPlayer(
    context: Context,
    private val texture: TextureRegistry.SurfaceTextureEntry,
    private val onPlayingChanged: (Boolean) -> Unit = {},
    // The main player owns media audio focus; the TV guide's muted preview
    // must not take it away.
    audioFocus: Boolean = true,
) {
    // A SurfaceTexture, not a SurfaceProducer: on Android 10+ the producer
    // is ImageReader-backed and Flutter draws the whole decoder buffer,
    // ignoring its crop rectangle. Decoders that pad their buffers (common
    // on TV chips, e.g. SD channels in a 1920x1088 buffer) then showed the
    // picture in the top-left corner with uninitialised green around it
    // (#30). SurfaceTexture's transform matrix carries the crop, which the
    // engine applies on every backend.
    private val surface = android.view.Surface(texture.surfaceTexture())

    private val appContext = context.applicationContext
    private val audioFocus = audioFocus

    // Buffer settings (Settings → Power User Tools). ExoPlayer can't change
    // its LoadControl after it's built, so a different preset rebuilds the
    // player at the next open() — between streams, where nothing is lost.
    private var bufferPreset = "fast"

    var exoPlayer: ExoPlayer = buildPlayer(context, bufferPreset)
        private set

    private fun buildPlayer(context: Context, preset: String): ExoPlayer =
        ExoPlayer.Builder(context)
            .setLoadControl(loadControlFor(preset))
            // Declared as media audio and holding audio focus, like any
            // media app: Android Auto only opens the car's media audio
            // channel for the app that holds focus (without it the car
            // showed the channel but played no sound), and calls /
            // navigation prompts pause or duck it.
            .setAudioAttributes(
                androidx.media3.common.AudioAttributes.Builder()
                    .setUsage(C.USAGE_MEDIA)
                    .setContentType(C.AUDIO_CONTENT_TYPE_MOVIE)
                    .build(),
                audioFocus,
            )
            // Pause when headphones / the car disconnect instead of blaring
            // from the phone speaker.
            .setHandleAudioBecomingNoisy(audioFocus)
            // Keep the CPU and Wi-Fi awake while playing with the screen off
            // (listening in the car with the phone locked).
            .setWakeMode(if (audioFocus) C.WAKE_MODE_NETWORK else C.WAKE_MODE_NONE)
            .build()

    private fun loadControlFor(preset: String): DefaultLoadControl {
        // (min buffer, max buffer, before first play, after a rebuffer), ms.
        val (minMs, maxMs, startMs, rebufferMs) = when (preset) {
            "balanced" -> listOf(50_000, 50_000, 2_500, 5_000)
            "smooth" -> listOf(50_000, 120_000, 4_000, 8_000)
            // Fast start: resume quickly after a hiccup — by default
            // ExoPlayer waits for 5 s of fresh data after a rebuffer, which
            // turned a one-second network blip into a long freeze. Dart's
            // stream watchdog reconnects if data stops altogether.
            else -> listOf(
                DefaultLoadControl.DEFAULT_MIN_BUFFER_MS,
                DefaultLoadControl.DEFAULT_MAX_BUFFER_MS,
                1_000,
                2_000,
            )
        }
        return DefaultLoadControl.Builder()
            .setBufferDurationsMs(minMs, maxMs, startMs, rebufferMs)
            .build()
    }

    /** Rebuilds the player with [preset]'s buffer if it differs. */
    private fun applyBufferPreset(preset: String) {
        if (preset == bufferPreset) return
        val old = exoPlayer
        old.removeListener(playerListener)
        old.release()
        bufferPreset = preset
        exoPlayer = buildPlayer(appContext, preset)
        exoPlayer.setVideoSurface(surface)
        exoPlayer.addListener(playerListener)
        android.util.Log.i("OTV-exo", "buffer preset: $preset")
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null
    private var currentTracks: Tracks = Tracks.EMPTY
    private var videoWidth = 0
    private var videoHeight = 0
    // Non-square pixel ratio (anamorphic SD broadcasts, e.g. 720x576 shown
    // as 16:9) — needed to compute the true display aspect ratio.
    private var pixelRatio = 1f
    private val positionUpdater = object : Runnable {
        override fun run() {
            emitState()
            mainHandler.postDelayed(this, 500)
        }
    }

    private val playerListener = object : Player.Listener {
            override fun onPlaybackStateChanged(playbackState: Int) = emitState()
            override fun onPlayWhenReadyChanged(playWhenReady: Boolean, reason: Int) = emitState()
            override fun onPlaybackSuppressionReasonChanged(reason: Int) = emitState()
            override fun onIsPlayingChanged(isPlaying: Boolean) {
                onPlayingChanged(isPlaying)
                emitState()
            }
            override fun onPlayerError(error: androidx.media3.common.PlaybackException) {
                android.util.Log.e("OTV-exo", "playback error: ${error.errorCodeName}", error)
                if (retryAsHls(error)) return
                // Tell Dart, so the player can show a message or reconnect
                // instead of sitting idle on the last frame.
                var cause: Throwable? = error
                while (cause != null &&
                    cause !is androidx.media3.datasource.HttpDataSource.InvalidResponseCodeException) {
                    cause = cause.cause
                }
                val http = (cause as? androidx.media3.datasource.HttpDataSource.InvalidResponseCodeException)
                    ?.responseCode
                eventSink?.success(mapOf(
                    "type" to "error",
                    "code" to error.errorCodeName,
                    "httpStatus" to http,
                ))
            }
            // Fires once the first real decoded video frame's size is known —
            // the same signal media_kit's videoParams.w>0 gave the buffering
            // overlay to distinguish "still warming up" from "actually playing".
            override fun onVideoSizeChanged(videoSize: androidx.media3.common.VideoSize) {
                videoWidth = videoSize.width
                videoHeight = videoSize.height
                pixelRatio = videoSize.pixelWidthHeightRatio
                emitState()
            }
            override fun onTracksChanged(tracks: Tracks) {
                currentTracks = tracks
                eventSink?.success(mapOf("type" to "tracks", "tracks" to tracksAsList()))
            }
            // Fires with decoded subtitle/CC cue text (CEA-608/708 included —
            // ExoPlayer decodes these internally; we just forward the text).
            // Flutter renders it as an overlay, same as this app's existing
            // architecture (subtitle presentation owned by Flutter, not the
            // native layer).
            override fun onCues(cueGroup: CueGroup) {
                val text = cueGroup.cues.joinToString("\n") { it.text?.toString() ?: "" }
                eventSink?.success(mapOf("type" to "cues", "text" to text))
            }
        }

    init {
        exoPlayer.setVideoSurface(surface)
        exoPlayer.addListener(playerListener)
        mainHandler.post(positionUpdater)
    }

    // What the current open() asked for — kept so a format-mismatch failure
    // can be retried as HLS (see retryAsHls).
    private var currentUrl: String? = null
    private var currentHint: String? = null
    private var hlsRetried = false

    // Follows redirects that switch between http and https, which
    // ExoPlayer refuses by default. Xtream panels commonly answer a stream
    // request with a 302 to an https CDN (e.g. an http://…/live/….ts link
    // redirecting to an https HLS URL); without this the player fails with
    // "Response code: 302" and shows a black screen.
    private val dataSourceFactory = DefaultDataSource.Factory(
        appContext,
        DefaultHttpDataSource.Factory().setAllowCrossProtocolRedirects(true),
    )

    fun open(
        url: String,
        streamTypeHint: String?,
        startPositionMs: Long = 0L,
        bufferPreset: String = this.bufferPreset,
    ) {
        applyBufferPreset(bufferPreset)
        currentUrl = url
        currentHint = streamTypeHint
        hlsRetried = false
        // Every stream starts at normal speed (a movie watched at 1.5x must
        // not make the next live channel run fast).
        exoPlayer.setPlaybackSpeed(1f)
        // A new stream has no frames yet — reset so Dart's "has video" check
        // doesn't mistake the previous stream's last frame for playback.
        videoWidth = 0
        videoHeight = 0
        pixelRatio = 1f
        // Captions start off for every stream (the app's default). Without
        // this, ExoPlayer auto-selects any text track matching the device
        // language — e.g. HLS streams declaring an English CC rendition.
        clearTextTrack()
        startSource(buildMediaSource(url, streamTypeHint), startPositionMs)
    }

    private fun startSource(mediaSource: MediaSource, startPositionMs: Long) {
        // Starting at the resume point directly (rather than seeking once the
        // duration is known) avoids briefly playing from 0 and then jumping.
        if (startPositionMs > 0) {
            exoPlayer.setMediaSource(mediaSource, startPositionMs)
        } else {
            exoPlayer.setMediaSource(mediaSource)
        }
        exoPlayer.prepare()
        exoPlayer.playWhenReady = true
    }

    /**
     * A stream's URL doesn't always say what it serves: Xtream panels that
     * front other services hand out `….ts` / `….mp4` links that redirect to
     * an HLS playlist. The progressive extractors then can't recognise the
     * data — the TS-only path fails with a malformed-content ParserException,
     * the default extractors with UnrecognizedInputFormatException (also a
     * ParserException). Rather than probing every stream up front (an extra
     * connection, which single-connection accounts may reject), retry once
     * as HLS when a parse failure happens. Returns true if a retry started.
     */
    private fun retryAsHls(error: androidx.media3.common.PlaybackException): Boolean {
        val url = currentUrl ?: return false
        if (hlsRetried || currentHint == "hls") return false
        var cause: Throwable? = error
        while (cause != null && cause !is ParserException) {
            cause = cause.cause
        }
        if (cause == null) return false
        hlsRetried = true
        android.util.Log.w("OTV-exo", "unrecognised format; retrying as HLS")
        val position = exoPlayer.currentPosition.coerceAtLeast(0L)
        startSource(buildMediaSource(url, "hls"), position)
        return true
    }

    private fun buildMediaSource(url: String, streamTypeHint: String?): MediaSource {
        val mediaItem = MediaItem.fromUri(url)
        return when (streamTypeHint) {
            "hls" -> HlsMediaSource.Factory(dataSourceFactory).createMediaSource(mediaItem)
            // Raw MPEG-TS (live/catch-up): ExoPlayer no longer auto-generates
            // a CEA-608/708 track for standalone .ts files unless TsExtractor
            // is given an explicit hint that closed-caption data may be
            // present — the same root cause the old mpv setup solved with
            // demuxer-lavf-o=scan_all_pmts=1 (captions live in a program the
            // default single-PMT scan doesn't look at). MODE_MULTI_PMT scans
            // every program in the transport stream, matching that fix.
            "ts" -> ProgressiveMediaSource.Factory(dataSourceFactory, ccAwareExtractorsFactory())
                .createMediaSource(mediaItem)
            // VOD containers (mp4/mkv/avi/etc.) — must NOT go through the
            // TS-only extractor above: TsExtractor never finds valid MPEG-TS
            // sync bytes in these files, so playback would silently stall in
            // BUFFERING forever instead of erroring or playing. The default
            // ExtractorsFactory auto-detects and handles these correctly.
            else -> ProgressiveMediaSource.Factory(dataSourceFactory).createMediaSource(mediaItem)
        }
    }

    private fun ccAwareExtractorsFactory(): ExtractorsFactory {
        val closedCaptionFormats = listOf(
            Format.Builder()
                .setSampleMimeType(MimeTypes.APPLICATION_CEA608)
                .setAccessibilityChannel(1)
                .build(),
            Format.Builder()
                .setSampleMimeType(MimeTypes.APPLICATION_CEA708)
                .setAccessibilityChannel(1)
                .build(),
        )
        return ExtractorsFactory {
            arrayOf<Extractor>(
                TsExtractor(
                    TsExtractor.MODE_MULTI_PMT,
                    TimestampAdjuster(0),
                    DefaultTsPayloadReaderFactory(
                        DefaultTsPayloadReaderFactory.FLAG_ALLOW_NON_IDR_KEYFRAMES,
                        closedCaptionFormats,
                    ),
                )
            )
        }
    }

    fun play() = exoPlayer.play()
    fun pause() = exoPlayer.pause()
    fun stop() = exoPlayer.stop()

    // 0.25–4x; ExoPlayer keeps audio pitch-corrected.
    fun setSpeed(speed: Float) = exoPlayer.setPlaybackSpeed(speed.coerceIn(0.25f, 4f))

    // Returns the resulting position immediately — unlike mpv, ExoPlayer
    // updates currentPosition synchronously on seekTo, so callers no longer
    // need to defensively track a "pending" target across rapid taps.
    fun seekTo(positionMs: Long): Long {
        exoPlayer.seekTo(positionMs)
        return exoPlayer.currentPosition
    }

    fun setEventSink(sink: EventChannel.EventSink?) {
        eventSink = sink
    }

    // "group:index" — synthetic id encoding the Tracks.Group and the track's
    // position within it, enough to look the group back up for selection.
    private fun tracksAsList(): List<Map<String, Any?>> {
        val result = mutableListOf<Map<String, Any?>>()
        currentTracks.groups.forEachIndexed { groupIndex, group ->
            val typeStr = when (group.type) {
                C.TRACK_TYPE_AUDIO -> "audio"
                C.TRACK_TYPE_TEXT -> "text"
                else -> null
            } ?: return@forEachIndexed
            for (trackIndex in 0 until group.length) {
                val format = group.getTrackFormat(trackIndex)
                result.add(mapOf(
                    "id" to "$groupIndex:$trackIndex",
                    "type" to typeStr,
                    // Raw details only — Dart builds the user-facing label
                    // (a bare per-group index isn't unique across groups).
                    "label" to (format.label ?: ""),
                    "language" to format.language,
                    "mimeType" to format.sampleMimeType,
                    "channel" to format.accessibilityChannel,
                    "selected" to group.isTrackSelected(trackIndex),
                ))
            }
        }
        return result
    }

    fun getTracks(): List<Map<String, Any?>> = tracksAsList()

    fun selectTrack(id: String) {
        val parts = id.split(":")
        val groupIndex = parts.getOrNull(0)?.toIntOrNull() ?: return
        val trackIndex = parts.getOrNull(1)?.toIntOrNull() ?: return
        val group = currentTracks.groups.getOrNull(groupIndex) ?: return
        val override = TrackSelectionOverride(group.mediaTrackGroup, trackIndex)
        exoPlayer.trackSelectionParameters = exoPlayer.trackSelectionParameters
            .buildUpon()
            .setTrackTypeDisabled(group.type, false)
            .addOverride(override)
            .build()
    }

    // No text-track override selected == no captions, matching this app's
    // existing default-off CC behavior.
    fun clearTextTrack() {
        exoPlayer.trackSelectionParameters = exoPlayer.trackSelectionParameters
            .buildUpon()
            .clearOverridesOfType(C.TRACK_TYPE_TEXT)
            .setTrackTypeDisabled(C.TRACK_TYPE_TEXT, true)
            .build()
    }

    private fun emitState() {
        val state = mapOf(
            "type" to "state",
            "position" to exoPlayer.currentPosition,
            "duration" to exoPlayer.duration.coerceAtLeast(0L),
            "playing" to exoPlayer.isPlaying,
            // What the user asked for (play vs pause) — unlike "playing",
            // which is also false while stalled. Dart tells a freeze from a
            // pause with this.
            "playWhenReady" to exoPlayer.playWhenReady,
            // Held back by the system (a phone call took audio focus): like
            // a pause, not a stall.
            "suppressed" to (exoPlayer.playbackSuppressionReason !=
                Player.PLAYBACK_SUPPRESSION_REASON_NONE),
            "buffering" to (exoPlayer.playbackState == Player.STATE_BUFFERING),
            "completed" to (exoPlayer.playbackState == Player.STATE_ENDED),
            "videoWidth" to videoWidth,
            "videoHeight" to videoHeight,
            "pixelRatio" to pixelRatio.toDouble(),
        )
        eventSink?.success(state)
    }

    fun dispose() {
        mainHandler.removeCallbacks(positionUpdater)
        onPlayingChanged(false)
        exoPlayer.release()
        surface.release()
        texture.release()
    }
}

/**
 * Owns every NativeVideoPlayer instance (keyed by texture id) and the
 * "openiptv/video_player" control channel. Multiple concurrent instances
 * are supported deliberately — the TV guide's mini live-preview runs a
 * second player alongside the main one.
 */
class NativeVideoPlayerManager(
    private val context: Context,
    private val messenger: BinaryMessenger,
    private val textureRegistry: TextureRegistry,
    // Lets the Activity keep the screen awake (FLAG_KEEP_SCREEN_ON) for as
    // long as any instance is actively playing — the TV guide's mini preview
    // can run alongside the main player, so "playing" is tracked per id
    // rather than assumed to be a single player.
    private val onAnyPlayingChanged: (Boolean) -> Unit = {},
) {
    private val players = mutableMapOf<Long, NativeVideoPlayer>()
    private val playingIds = mutableSetOf<Long>()
    private val controlChannel = MethodChannel(messenger, "openiptv/video_player")

    private fun setPlaying(id: Long, isPlaying: Boolean) {
        val changed = if (isPlaying) playingIds.add(id) else playingIds.remove(id)
        if (changed) onAnyPlayingChanged(playingIds.isNotEmpty())
    }

    init {
        controlChannel.setMethodCallHandler { call, result -> handle(call, result) }
    }

    private fun idArg(call: MethodCall): Long = (call.argument<Number>("id") ?: 0).toLong()

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "create" -> {
                val texture = textureRegistry.createSurfaceTexture()
                val id = texture.id()
                val audioFocus = call.argument<Boolean>("audioFocus") ?: true
                val player = NativeVideoPlayer(context, texture, { isPlaying ->
                    setPlaying(id, isPlaying)
                }, audioFocus)
                val eventChannel = EventChannel(messenger, "openiptv/video_player_events/$id")
                eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
                    override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                        player.setEventSink(sink)
                    }
                    override fun onCancel(arguments: Any?) {
                        player.setEventSink(null)
                    }
                })
                players[id] = player
                result.success(id)
            }
            "open" -> {
                players[idArg(call)]?.open(
                    call.argument<String>("url") ?: "",
                    call.argument<String>("streamTypeHint"),
                    call.argument<Number>("startPositionMs")?.toLong() ?: 0L,
                    call.argument<String>("bufferPreset") ?: "fast",
                )
                result.success(null)
            }
            "play" -> {
                players[idArg(call)]?.play()
                result.success(null)
            }
            "pause" -> {
                players[idArg(call)]?.pause()
                result.success(null)
            }
            "stop" -> {
                players[idArg(call)]?.stop()
                result.success(null)
            }
            "seekTo" -> {
                val pos = players[idArg(call)]
                    ?.seekTo((call.argument<Number>("positionMs") ?: 0).toLong())
                result.success(pos)
            }
            "setSpeed" -> {
                players[idArg(call)]?.setSpeed((call.argument<Number>("speed") ?: 1).toFloat())
                result.success(null)
            }
            "getTracks" -> {
                result.success(players[idArg(call)]?.getTracks() ?: emptyList<Any>())
            }
            "selectTrack" -> {
                players[idArg(call)]?.selectTrack(call.argument<String>("trackId") ?: "")
                result.success(null)
            }
            "clearTextTrack" -> {
                players[idArg(call)]?.clearTextTrack()
                result.success(null)
            }
            "dispose" -> {
                players.remove(idArg(call))?.dispose()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }
}
