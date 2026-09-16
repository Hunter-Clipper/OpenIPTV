package com.openiptv.app

import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.media3.common.C
import androidx.media3.common.Format
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.Player
import androidx.media3.common.TrackSelectionOverride
import androidx.media3.common.Tracks
import androidx.media3.common.text.CueGroup
import androidx.media3.common.util.TimestampAdjuster
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.hls.HlsMediaSource
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
 * One instance per texture/surface. Rendered via TextureRegistry's modern
 * SurfaceProducer API (the same one video_player_android itself now uses)
 * rather than a full native PlatformView — simpler and composes better
 * with Flutter (including PiP) since it's just a GPU texture, no view
 * hierarchy overlay.
 */
class NativeVideoPlayer(
    context: Context,
    private val surfaceProducer: TextureRegistry.SurfaceProducer,
    private val onPlayingChanged: (Boolean) -> Unit = {},
) {
    private val appContext = context.applicationContext
    val exoPlayer: ExoPlayer = ExoPlayer.Builder(context).build()

    private val mainHandler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null
    private var currentTracks: Tracks = Tracks.EMPTY
    private var videoWidth = 0
    private var videoHeight = 0
    private val positionUpdater = object : Runnable {
        override fun run() {
            emitState()
            mainHandler.postDelayed(this, 500)
        }
    }

    init {
        exoPlayer.setVideoSurface(surfaceProducer.surface)
        exoPlayer.addListener(object : Player.Listener {
            override fun onPlaybackStateChanged(playbackState: Int) = emitState()
            override fun onIsPlayingChanged(isPlaying: Boolean) {
                onPlayingChanged(isPlaying)
                emitState()
            }
            override fun onPlayerError(error: androidx.media3.common.PlaybackException) {
                android.util.Log.e("OTV-exo", "playback error: ${error.errorCodeName}", error)
            }
            // Fires once the first real decoded video frame's size is known —
            // the same signal media_kit's videoParams.w>0 gave the buffering
            // overlay to distinguish "still warming up" from "actually playing".
            override fun onVideoSizeChanged(videoSize: androidx.media3.common.VideoSize) {
                videoWidth = videoSize.width
                videoHeight = videoSize.height
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
        })
        mainHandler.post(positionUpdater)
    }

    fun open(url: String, streamTypeHint: String?) {
        val mediaItem = MediaItem.fromUri(url)
        val dataSourceFactory = DefaultDataSource.Factory(appContext)
        val mediaSource = when (streamTypeHint) {
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
        exoPlayer.setMediaSource(mediaSource)
        exoPlayer.prepare()
        exoPlayer.playWhenReady = true
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
                    "label" to (format.label ?: format.language ?: "Track $trackIndex"),
                    "language" to format.language,
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
            "buffering" to (exoPlayer.playbackState == Player.STATE_BUFFERING),
            "completed" to (exoPlayer.playbackState == Player.STATE_ENDED),
            "videoWidth" to videoWidth,
            "videoHeight" to videoHeight,
        )
        eventSink?.success(state)
    }

    fun dispose() {
        mainHandler.removeCallbacks(positionUpdater)
        onPlayingChanged(false)
        exoPlayer.release()
        surfaceProducer.release()
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
                val surfaceProducer = textureRegistry.createSurfaceProducer()
                val id = surfaceProducer.id()
                val player = NativeVideoPlayer(context, surfaceProducer) { isPlaying ->
                    setPlaying(id, isPlaying)
                }
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
