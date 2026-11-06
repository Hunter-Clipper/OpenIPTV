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
import androidx.media3.datasource.DataSource
import androidx.media3.datasource.DataSpec
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

    // Where the video goes: the Flutter texture, or the car screen while
    // CarVideoActivity shows it (Android Auto).
    private var output: android.view.Surface = surface

    /** Sends the picture to [external] (the car screen), or back to the app with null. */
    fun setExternalSurface(external: android.view.Surface?) {
        carSurface = external
        output = desiredSurface()
        exoPlayer.setVideoSurface(output)
        // The car screen gets plain output (no tunneling / passthrough).
        refreshOutput()
    }

    /** The current picture's display size (width, height × pixel ratio), for the car screen. */
    var onVideoSize: ((Int, Int, Float) -> Unit)? = null

    private val appContext = context.applicationContext
    // Whether this player is what you hear: media audio focus + full volume.
    // Multi-view (#52) moves it between tiles; the TV guide preview starts
    // without it.
    private var audible = audioFocus
    // Only the app's main player ever holds audio focus. Multi-view's other
    // tiles are made audible by volume alone: with several players asking
    // for focus, a late request from one tile took it from the audible one,
    // and ExoPlayer paused that tile for good (a "dead" tile).
    private val ownsFocus = audioFocus

    private val mediaAudioAttributes = androidx.media3.common.AudioAttributes.Builder()
        .setUsage(C.USAGE_MEDIA)
        .setContentType(C.AUDIO_CONTENT_TYPE_MOVIE)
        .build()

    // Buffer settings (Settings → Power User Tools). ExoPlayer can't change
    // its LoadControl after it's built, so a different preset rebuilds the
    // player at the next open() — between streams, where nothing is lost.
    private var bufferPreset = "fast"

    // Tunneling / passthrough (#159): what this player was built with.
    private var speed = 1f
    // Set by open(): tunneling is only for live streams.
    private var liveStream = false
    private var builtOutput = wantedOutput()


    // The real video layer (#162): the picture goes to a SurfaceView behind
    // Flutter instead of the texture while this (main) player has claimed it.
    // The layer's surface exists from app start (a 1-pixel view), so a claimed
    // player is built on it from its very first frame and never has to
    // switch surfaces (which would restart the stream).
    private var layerSurface: android.view.Surface? = null
    private var layerClaimed = false
    private var carSurface: android.view.Surface? = null

    private fun desiredSurface(): android.view.Surface = carSurface
        ?: layerSurface.takeIf { layerClaimed && !OutputModes.multiViewActive }
        ?: surface

    /** Points the video at [desiredSurface]; true if that changed it. */
    private fun applySurface(): Boolean {
        val want = desiredSurface()
        if (want === output) return false
        output = want
        exoPlayer.setVideoSurface(want)
        return true
    }

    /** The layer's surface exists. */
    fun layerSurfaceReady(s: android.view.Surface) {
        layerSurface = s
        if (applySurface()) refreshOutput()
    }

    /** The layer's surface is gone (screen off / app stopped): back to the texture. */
    fun layerSurfaceGone() {
        layerSurface = null
        if (applySurface()) refreshOutput()
    }

    /** Nobody shows the layer any more: the picture goes back to the texture. */
    fun layerReleased() {
        layerClaimed = false
        if (applySurface()) refreshOutput()
    }

    /** Where Dart wants the layer; null lets it go. */
    fun setLayer(rect: IntArray?) {
        if (rect == null) {
            VideoLayer.hide(this)
            return
        }
        layerClaimed = true
        VideoLayer.show(this, rect[0], rect[1], rect[2], rect[3])
        if (applySurface()) refreshOutput()
    }

    // The main player on a TV takes the layer as each stream opens.
    private fun claimLayerForNewStream(carScreen: Boolean) {
        if (ownsFocus && !carScreen && VideoLayer.available &&
            EngineChannels.isTelevision(appContext)) {
            layerClaimed = true
            VideoLayer.owner = this
            layerSurface = layerSurface ?: VideoLayer.currentSurface()
            applySurface()
        }
    }

    private fun wantedOutput() = OutputModes.wanted(
        isTelevision = EngineChannels.isTelevision(appContext),
        mainPlayer = ownsFocus,
        onCarScreen = carSurface != null,
        onLayer = layerSurface != null && output === layerSurface,
        speedIsNormal = speed == 1f,
        liveStream = liveStream,
    )

    var exoPlayer: ExoPlayer = buildPlayer(context, bufferPreset, builtOutput)
        private set

    private fun buildPlayer(context: Context, preset: String, out: OutputModes.Output): ExoPlayer {
        val selector = androidx.media3.exoplayer.trackselection.DefaultTrackSelector(context)
        selector.parameters = selector.buildUponParameters()
            .setTunnelingEnabled(out.tunneling)
            .build()
        return ExoPlayer.Builder(context, OutputModes.Factory(context, out.passthrough))
            .setTrackSelector(selector)
            .setLoadControl(loadControlFor(preset))
            .build()
            .also {
                applyAudible(it, audible)
                it.addAnalyticsListener(AudioPathLog(if (audible) "main" else "aux", out))
                // Decoder / frame-timing logging (#157): TVs only, so phones
                // run exactly the player they always did.
                if (EngineChannels.isTelevision(context)) attachDiagnostics(it)
            }
    }

    private fun attachDiagnostics(player: ExoPlayer) {
        val tag = if (audible) "main" else "aux"
        player.addAnalyticsListener(VideoDiagnostics(tag))
        val cadence = FrameCadence(tag)
        player.setVideoFrameMetadataListener(cadence)
        player.addAnalyticsListener(object : androidx.media3.exoplayer.analytics.AnalyticsListener {
            override fun onVideoDecoderInitialized(
                eventTime: androidx.media3.exoplayer.analytics.AnalyticsListener.EventTime,
                decoderName: String, initializedTimestampMs: Long, initializationDurationMs: Long,
            ) = cadence.reset()
        })
    }

    /**
     * Makes this the player you hear (multi-view, #52): volume and media
     * audio focus move together, so a call or a navigation prompt still
     * pauses / ducks the channel you're listening to, and never a muted one.
     */
    fun setAudible(on: Boolean) {
        if (on == audible) return
        audible = on
        applyAudible(exoPlayer, on)
    }

    private fun applyAudible(player: ExoPlayer, on: Boolean) {
        player.volume = if (on) 1f else 0f
        // Declared as media audio and holding audio focus, like any
        // media app: Android Auto only opens the car's media audio
        // channel for the app that holds focus (without it the car
        // showed the channel but played no sound), and calls /
        // navigation prompts pause or duck it.
        player.setAudioAttributes(mediaAudioAttributes, ownsFocus)
        // Pause when headphones / the car disconnect instead of blaring
        // from the phone speaker.
        player.setHandleAudioBecomingNoisy(on)
        // Keep the CPU and Wi-Fi awake while playing with the screen off
        // (listening in the car with the phone locked).
        player.setWakeMode(if (on) C.WAKE_MODE_NETWORK else C.WAKE_MODE_NONE)
    }

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

    /** Rebuilds the player with [preset]'s buffer / the wanted output if either differs. */
    private fun applyBufferPreset(preset: String) {
        val want = wantedOutput()
        if (preset == bufferPreset && want == builtOutput) return
        val old = exoPlayer
        old.removeListener(playerListener)
        old.release()
        bufferPreset = preset
        builtOutput = want
        exoPlayer = buildPlayer(appContext, preset, want)
        currentTracks = Tracks.EMPTY
        exoPlayer.setVideoSurface(output)
        exoPlayer.addListener(playerListener)
        // The new player starts with default track selection: captions off.
        clearTextTrack()
        android.util.Log.i("OTV-exo", "buffer preset: $preset, output: $want")
    }

    /**
     * The settings changed, multi-view started or ended, or a feature failed:
     * if this player should now be built differently, rebuild it and carry on
     * with the same stream (a live channel rejoins at the live edge, a movie
     * resumes where it was). A short pause, never a manual step.
     */
    fun refreshOutput() {
        applySurface()
        if (wantedOutput() == builtOutput) return
        val url = currentUrl
        val old = exoPlayer
        val live = old.isCurrentMediaItemLive || old.isCurrentMediaItemDynamic
        val pos = if (live) 0L else old.currentPosition
        val resume = url != null && old.playbackState != Player.STATE_IDLE
        val play = old.playWhenReady
        applyBufferPreset(bufferPreset)
        if (resume && url != null) {
            renderedFrame = false
            startSource(buildMediaSource(url, currentHint), pos)
            exoPlayer.playWhenReady = play
        }
    }

    // Tunneled video that never shows a picture while the audio plays is the
    // classic failure: give up on tunneling for this device and carry on.
    private val noPictureCheck = Runnable {
        if (builtOutput.tunneling && !renderedFrame &&
            exoPlayer.playbackState == Player.STATE_READY) {
            tunnelingFailed("no picture")
        }
    }

    private fun tunnelingFailed(why: String) {
        android.util.Log.w("OTV-video", "tunneling: $why, switching it off")
        OutputModes.markTunnelingBroken(appContext)
        eventSink?.success(mapOf("type" to "outputNotice", "feature" to "tunneling"))
        refreshOutput()
    }

    // Tunneled playback whose clock stands still although data is waiting
    // (seen on catch-up on the Chromecast): give up on tunneling, carry on.
    private var lastPos = -1L
    private var lastMoveAt = 0L
    // Tunneled frames go straight to the screen hardware, not into our video
    // texture, so on a TV that can't composite them the picture stays black
    // (or on the last frame) while the audio plays and ExoPlayer reports
    // everything fine (seen on the Mi TV). The texture's frame timestamp
    // only moves when real pictures arrive.
    private var lastTexTs = -1L
    private var lastTexAt = 0L
    private fun checkTunnelPicture(now: Long): Boolean {
        val p = exoPlayer
        if (output !== surface || !p.playWhenReady || p.playbackState != Player.STATE_READY) {
            lastTexAt = now
            return false
        }
        val ts = try { texture.surfaceTexture().timestamp } catch (_: Exception) { return false }
        if (ts != lastTexTs) {
            lastTexTs = ts
            lastTexAt = now
            return false
        }
        if (now - lastTexAt > 3_500) {
            lastTexAt = now
            tunnelingFailed("no pictures reach the screen")
            return true
        }
        return false
    }

    private fun checkTunnelFreeze() {
        if (!builtOutput.tunneling) return
        val p = exoPlayer
        val now = android.os.SystemClock.elapsedRealtime()
        if (checkTunnelPicture(now)) return
        val pos = p.currentPosition
        val state = p.playbackState
        // A network stall has an empty buffer ahead of the clock instead.
        val ahead = p.bufferedPosition - pos
        val stuckCandidate = p.playWhenReady &&
            (state == Player.STATE_READY || state == Player.STATE_BUFFERING) && ahead > 1_000
        if (!stuckCandidate || pos != lastPos) {
            lastPos = pos
            lastMoveAt = now
            return
        }
        // Shorter than the Dart watchdog's 4 s, so this gets there first.
        if (now - lastMoveAt > 2_500) {
            lastMoveAt = now
            tunnelingFailed("clock stuck at ${pos}ms, state=$state, ${ahead}ms buffered, frame=$renderedFrame")
        }
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
            maybeQueueNext()
            checkTunnelFreeze()
            emitState()
            mainHandler.postDelayed(this, 500)
        }
    }

    private val playerListener = object : Player.Listener {
            override fun onPlaybackStateChanged(playbackState: Int) {
                mainHandler.removeCallbacks(noPictureCheck)
                if (playbackState == Player.STATE_READY && builtOutput.tunneling && !renderedFrame) {
                    mainHandler.postDelayed(noPictureCheck, 4_000)
                }
                CarVideo.streamStateChanged(this@NativeVideoPlayer)
                // Auto frame rate (#149): hand the screen back when the main
                // player stops (multi-view's other tiles must not).
                if (audible && (playbackState == Player.STATE_IDLE ||
                        playbackState == Player.STATE_ENDED)) FrameRateMatcher.restore()
                emitState()
            }
            override fun onPlayWhenReadyChanged(playWhenReady: Boolean, reason: Int) {
                // A muted multi-view tile never holds audio focus, so a
                // focus loss that still reaches it must not pause it for
                // good (nothing would ever resume it).
                if (!playWhenReady && !ownsFocus &&
                    reason == Player.PLAY_WHEN_READY_CHANGE_REASON_AUDIO_FOCUS_LOSS) {
                    exoPlayer.playWhenReady = true
                    return
                }
                emitState()
            }
            override fun onPlaybackSuppressionReasonChanged(reason: Int) {
                // Another app took the sound (a video starting elsewhere, a
                // call): stay paused. ExoPlayer would otherwise resume on its
                // own once that app lets go, i.e. a stream nobody is
                // watching suddenly playing in the background.
                if (reason == Player.PLAYBACK_SUPPRESSION_REASON_TRANSIENT_AUDIO_FOCUS_LOSS) {
                    exoPlayer.pause()
                }
                emitState()
            }
            override fun onIsPlayingChanged(isPlaying: Boolean) {
                onPlayingChanged(isPlaying)
                emitState()
            }
            override fun onPlayerError(error: androidx.media3.common.PlaybackException) {
                android.util.Log.e("OTV-exo", "playback error: ${error.errorCodeName}", error)
                if (outputFeatureFailed(error)) return
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
                onVideoSize?.invoke(videoWidth, videoHeight, pixelRatio)
                matchFrameRate()
                emitState()
            }
            override fun onRenderedFirstFrame() {
                renderedFrame = true
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
        OutputModes.register(this)
    }

    // What the current open() asked for — kept so a format-mismatch failure
    // can be retried as HLS (see retryAsHls).
    private var currentUrl: String? = null
    private var currentHint: String? = null
    private var hlsRetried = false
    // The start position open() asked for, and whether any frame has been
    // drawn since: the HLS retry is only for streams that never played.
    private var currentStartMs = 0L
    private var renderedFrame = false

    // Follows redirects that switch between http and https, which
    // ExoPlayer refuses by default. Xtream panels commonly answer a stream
    // request with a 302 to an https CDN (e.g. an http://…/live/….ts link
    // redirecting to an https HLS URL); without this the player fails with
    // "Response code: 302" and shows a black screen.
    private val dataSourceFactory = DefaultDataSource.Factory(
        appContext,
        DataSource.Factory {
            LoggingDataSource(
                DefaultHttpDataSource.Factory()
                    .setAllowCrossProtocolRedirects(true)
                    .setUserAgent(currentUserAgent())
                    .createDataSource(),
                System.identityHashCode(this),
                onEnd = { ends.incrementAndGet() },
            )
        },
    )

    // The app's own user agent. Providers tell connections apart by IP +
    // user agent (confirmed on the owner's provider, #52): left to Android,
    // every player on one device sent the same "Dalvik/…" string and the
    // provider counted several streams as one. The short per-install tag
    // keeps two devices of the same model on one network apart too; a
    // multi-view tile adds its own tag on top.
    private val baseUserAgent: String by lazy {
        val version = try {
            appContext.packageManager.getPackageInfo(appContext.packageName, 0).versionName
        } catch (e: Exception) { "0" }
        val prefs = appContext.getSharedPreferences("openiptv_native", Context.MODE_PRIVATE)
        var tag = prefs.getString("ua_install", null)
        if (tag == null) {
            tag = java.util.UUID.randomUUID().toString().substring(0, 6)
            prefs.edit().putString("ua_install", tag).apply()
        }
        "OpenIPTV/$version (Android ${android.os.Build.VERSION.RELEASE}; ${android.os.Build.MODEL}; $tag)"
    }
    private var userAgentSuffix: String? = null
    // The user's own user agent from Power User Tools (replaces the app's).
    private var customUserAgent: String? = null

    private fun currentUserAgent(): String {
        val base = customUserAgent ?: baseUserAgent
        return userAgentSuffix?.let { "$base $it" } ?: base
    }

    // Live MPEG-TS from some providers arrives as ~60 s bursts: the server
    // ends the response and the player used to wait until its buffer ran dry
    // before reconnecting (1–2 s of buffering a minute). With this on, the
    // next connection is queued as the playlist's next item shortly before
    // the buffer ends, so ExoPlayer moves on without a gap.
    private var liveReconnect = false
    private val ends = java.util.concurrent.atomic.AtomicInteger(0)
    private var itemsOpened = 1

    private fun maybeQueueNext() {
        if (!liveReconnect) return
        val player = exoPlayer
        // Drop items already played.
        val done = player.currentMediaItemIndex
        if (done > 0) {
            player.removeMediaItems(0, done)
            itemsOpened -= done
            ends.addAndGet(-done)
        }
        val url = currentUrl ?: return
        if (player.playbackState != Player.STATE_READY) return
        if (ends.get() < itemsOpened) return // still downloading the current one
        if (player.totalBufferedDuration > 3_500) return
        itemsOpened++
        android.util.Log.i("OTV-http", "[${System.identityHashCode(this)}] next connection queued " +
            "(${player.totalBufferedDuration} ms left)")
        player.addMediaSource(buildMediaSource(url, currentHint))
    }

    fun open(
        url: String,
        streamTypeHint: String?,
        startPositionMs: Long = 0L,
        bufferPreset: String = this.bufferPreset,
        carScreen: Boolean = false,
        userAgentSuffix: String? = null,
        liveReconnect: Boolean = false,
        userAgent: String? = null,
        live: Boolean = false,
    ) {
        liveStream = live
        this.userAgentSuffix = userAgentSuffix
        this.customUserAgent = userAgent?.takeIf { it.isNotBlank() }
        this.liveReconnect = liveReconnect && streamTypeHint == "ts"
        ends.set(0)
        itemsOpened = 1
        android.util.Log.i("OTV-http", "[${System.identityHashCode(this)}] user agent: " +
            "${currentUserAgent()}${if (this.liveReconnect) " (seamless)" else ""}")
        speed = 1f
        claimLayerForNewStream(carScreen)
        applyBufferPreset(bufferPreset)
        // Only what the car started goes to the car screen; a stream opened
        // on the phone shows on the phone.
        CarVideo.routeToCar(this, carScreen)
        currentUrl = url
        currentHint = streamTypeHint
        hlsRetried = false
        currentStartMs = startPositionMs
        renderedFrame = false
        // Every stream starts at normal speed (a movie watched at 1.5x must
        // not make the next live channel run fast).
        exoPlayer.setPlaybackSpeed(1f)
        // A new stream has no frames yet — reset so Dart's "has video" check
        // doesn't mistake the previous stream's last frame for playback.
        videoWidth = 0
        videoHeight = 0
        pixelRatio = 1f
        onVideoSize?.invoke(0, 0, 1f)
        emitState()
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
    /** A tunneling / passthrough failure: drop that feature and carry on. */
    private fun outputFeatureFailed(error: androidx.media3.common.PlaybackException): Boolean {
        val audioFail = error.errorCode == androidx.media3.common.PlaybackException.ERROR_CODE_AUDIO_TRACK_INIT_FAILED ||
            error.errorCode == androidx.media3.common.PlaybackException.ERROR_CODE_AUDIO_TRACK_WRITE_FAILED
        val decodeFail = error.errorCode == androidx.media3.common.PlaybackException.ERROR_CODE_DECODER_INIT_FAILED ||
            error.errorCode == androidx.media3.common.PlaybackException.ERROR_CODE_DECODING_FAILED
        val feature = when {
            audioFail && builtOutput.passthrough != OutputModes.Pass.PCM -> "passthrough"
            (audioFail || decodeFail) && builtOutput.tunneling -> "tunneling"
            else -> return false
        }
        android.util.Log.w("OTV-video", "$feature failed (${error.errorCodeName}), switching it off")
        if (feature == "passthrough") OutputModes.markPassthroughBroken()
        else OutputModes.markTunnelingBroken(appContext)
        eventSink?.success(mapOf("type" to "outputNotice", "feature" to feature))
        refreshOutput()
        return true
    }

    private fun retryAsHls(error: androidx.media3.common.PlaybackException): Boolean {
        val url = currentUrl ?: return false
        // A stream that already played hit a transient parse error, not a
        // wrong guess about its format: don't restart it as HLS.
        if (hlsRetried || renderedFrame || currentHint == "hls") return false
        var cause: Throwable? = error
        while (cause != null && cause !is ParserException) {
            cause = cause.cause
        }
        if (cause == null) return false
        hlsRetried = true
        currentHint = "hls"
        liveReconnect = false
        android.util.Log.w("OTV-exo", "unrecognised format; retrying as HLS")
        // Same start as the original open(): a live stream joins at its live
        // edge instead of seeking into the live window.
        startSource(buildMediaSource(url, "hls"), currentStartMs)
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
    fun setSpeed(speed: Float) {
        this.speed = speed.coerceIn(0.25f, 4f)
        // A bitstream or a tunnel can't be sped up: use plain output meanwhile.
        refreshOutput()
        exoPlayer.setPlaybackSpeed(this.speed)
    }

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

    val currentVideoSize get() = Triple(videoWidth, videoHeight, pixelRatio)

    /** A stream is open (loading, playing or paused) — not stopped or finished. */
    val hasStream get() =
        exoPlayer.playbackState != Player.STATE_IDLE && exoPlayer.playbackState != Player.STATE_ENDED

    // Auto frame rate (#149): the player you hear drives the screen's rate.
    private fun matchFrameRate() {
        if (!audible) return
        val fps = exoPlayer.videoFormat?.frameRate ?: return
        if (fps > 0f) FrameRateMatcher.match(fps)
    }

    fun dispose() {
        OutputModes.unregister(this)
        mainHandler.removeCallbacks(noPictureCheck)
        if (audible) FrameRateMatcher.restore()
        CarVideo.playerGone(this)
        mainHandler.removeCallbacks(positionUpdater)
        onPlayingChanged(false)
        exoPlayer.removeListener(playerListener)
        // Detach whichever surface (app or car) it is drawing on first.
        exoPlayer.clearVideoSurface()
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
    private val eventChannels = mutableMapOf<Long, EventChannel>()
    private val playingIds = mutableSetOf<Long>()

    init {
        synchronized(managers) { managers.add(this) }
    }

    /** Stops every stream this manager owns, whatever Dart is doing. */
    private fun killAll() {
        for (p in players.values) {
            p.exoPlayer.playWhenReady = false
            p.stop()
        }
    }

    companion object {
        private val managers = mutableListOf<NativeVideoPlayerManager>()

        /** The PiP window was closed: nothing may keep playing. */
        fun stopAll() {
            synchronized(managers) { managers.toList() }.forEach { it.killAll() }
        }
    }
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
                // The app's main player (it holds media audio focus) is the
                // one the car screen shows.
                if (audioFocus) CarVideo.setPlayer(player)
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
                eventChannels[id] = eventChannel
                result.success(id)
            }
            "open" -> {
                players[idArg(call)]?.open(
                    call.argument<String>("url") ?: "",
                    call.argument<String>("streamTypeHint"),
                    call.argument<Number>("startPositionMs")?.toLong() ?: 0L,
                    call.argument<String>("bufferPreset") ?: "fast",
                    call.argument<Boolean>("carScreen") ?: false,
                    call.argument<String>("userAgentSuffix"),
                    call.argument<Boolean>("liveReconnect") ?: false,
                    call.argument<String>("userAgent"),
                    call.argument<Boolean>("live") ?: false,
                )
                result.success(null)
            }
            // Tunneling / passthrough settings (#159) and the multi-view signal.
            "setOutputModes" -> {
                OutputModes.configure(
                    context,
                    call.argument<String>("passthrough") ?: OutputModes.AUTO,
                    call.argument<String>("tunneling") ?: OutputModes.AUTO,
                )
                result.success(null)
            }
            "setVideoLayer" -> {
                // [left, top, width, height] in pixels, or null to hide.
                val r = call.argument<List<Number>>("rect")?.map { it.toInt() }?.toIntArray()
                players[idArg(call)]?.setLayer(r)
                result.success(null)
            }
            "setMultiViewActive" -> {
                OutputModes.setMultiView(call.argument<Boolean>("active") ?: false)
                result.success(null)
            }
            "setAutoFrameRate" -> {
                FrameRateMatcher.enabled = call.argument<Boolean>("enabled") ?: false
                if (!FrameRateMatcher.enabled) FrameRateMatcher.restore(immediately = true)
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
            "setAudible" -> {
                players[idArg(call)]?.setAudible(call.argument<Boolean>("on") ?: true)
                result.success(null)
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
                val id = idArg(call)
                players.remove(id)?.dispose()
                eventChannels.remove(id)?.setStreamHandler(null)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }
}

/**
 * Logs what the provider answers to each request (status, the headers that
 * say who is limiting us, how long a stream's connection lived), without the
 * URL — it holds the login. For finding out why multi-view tiles die (#52).
 */
@androidx.annotation.OptIn(androidx.media3.common.util.UnstableApi::class)
private class LoggingDataSource(
    private val inner: DataSource,
    private val owner: Int,
    private val onEnd: () -> Unit = {},
) : DataSource by inner {
    private var openedAt = 0L
    private var bytes = 0L
    private var what = ""

    private fun pick(h: Map<String, List<String>>): String {
        val keys = listOf("server", "connection", "x-ratelimit-remaining",
            "retry-after", "content-type", "location")
        val parts = h.entries.mapNotNull { (k, v) ->
            val lk = k?.lowercase() ?: return@mapNotNull null
            if (lk in keys || lk.startsWith("x-ratelimit")) "$lk=${v.firstOrNull()?.take(60)}"
            else if (lk == "set-cookie") "set-cookie=yes" else null
        }
        return parts.joinToString(" ")
    }

    override fun open(dataSpec: DataSpec): Long {
        val name = dataSpec.uri.lastPathSegment ?: ""
        what = (if (name.contains('.')) name.substringAfterLast('.') else "?").take(8) +
            (if (dataSpec.position > 0) "+range" else "")
        openedAt = android.os.SystemClock.elapsedRealtime()
        bytes = 0
        try {
            return inner.open(dataSpec)
        } catch (e: androidx.media3.datasource.HttpDataSource.InvalidResponseCodeException) {
            android.util.Log.w("OTV-http", "[$owner] open $what HTTP ${e.responseCode} ${pick(e.headerFields)}")
            throw e
        } catch (e: java.io.IOException) {
            android.util.Log.w("OTV-http", "[$owner] open $what failed ${e.javaClass.simpleName}: ${e.message?.take(80)}")
            throw e
        }
    }

    override fun read(buffer: ByteArray, offset: Int, length: Int): Int {
        val n = try {
            inner.read(buffer, offset, length)
        } catch (e: java.io.IOException) {
            android.util.Log.w("OTV-http", "[$owner] read $what failed after ${bytes / 1024} KB, " +
                "${(android.os.SystemClock.elapsedRealtime() - openedAt) / 1000}s: ${e.javaClass.simpleName}")
            throw e
        }
        if (n > 0) bytes += n
        if (n == androidx.media3.common.C.RESULT_END_OF_INPUT) onEnd()
        return n
    }

    override fun close() {
        // Only long-lived streams are worth a line (HLS segments are many).
        val secs = (android.os.SystemClock.elapsedRealtime() - openedAt) / 1000
        if (secs >= 5) android.util.Log.i("OTV-http", "[$owner] closed $what after ${secs}s, ${bytes / 1024} KB")
        inner.close()
    }
}
