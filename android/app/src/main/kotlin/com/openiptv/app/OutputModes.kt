package com.openiptv.app

import android.content.Context
import android.media.AudioFormat
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.audio.AudioCapabilities
import androidx.media3.exoplayer.audio.AudioSink
import androidx.media3.exoplayer.audio.DefaultAudioSink

/**
 * Audio passthrough and tunneled playback (#159), both app-wide settings
 * ("auto" | "on" | "off") pushed from Dart, plus the "multi-view is on"
 * signal that switches both off while several streams play at once.
 *
 * Only a player that holds audio focus (the app's main player) ever uses
 * either feature: a bitstream ignores the volume that mutes the other
 * multi-view tiles, and tunneled decoding is a single-owner hardware path.
 * Every other player always decodes to plain PCM, untunneled.
 */
object OutputModes {
    const val AUTO = "auto"
    const val ON = "on"
    const val OFF = "off"

    enum class Pass { DEVICE, FORCE, PCM }

    /** What one player should be built with. */
    data class Output(val tunneling: Boolean, val passthrough: Pass) {
        companion object {
            val PLAIN = Output(false, Pass.PCM)
        }
    }

    private const val PREFS = "otv_output"
    private const val KEY_TUNNEL_BROKEN = "tunneling_failed"
    private const val KEY_PASS = "passthrough"
    private const val KEY_TUNNEL = "tunneling"

    var passthrough = AUTO
        private set
    var tunneling = AUTO
        private set
    var multiViewActive = false
        private set

    // Set when a feature produced no picture / no sound on this device, so
    // it is skipped from then on (persisted only for "auto": an explicit
    // "on" is the user's choice and is retried next launch).
    var tunnelingBroken = false
        private set
    var passthroughBroken = false
        private set

    private val players = mutableSetOf<NativeVideoPlayer>()
    private val main = Handler(Looper.getMainLooper())

    fun register(p: NativeVideoPlayer) { players.add(p) }
    fun unregister(p: NativeVideoPlayer) { players.remove(p) }

    /**
     * The modes are remembered here too: the Dart side's push at start-up can
     * arrive before this channel exists (the shared engine starts Dart early),
     * so a restart must not forget the user's choice.
     */
    fun load(context: Context) {
        val p = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        passthrough = p.getString(KEY_PASS, AUTO) ?: AUTO
        tunneling = p.getString(KEY_TUNNEL, AUTO) ?: AUTO
        tunnelingBroken = p.getBoolean(KEY_TUNNEL_BROKEN, false)
    }

    /** Settings from the app. A real change clears a remembered failure: a fresh try. */
    fun configure(context: Context, passthrough: String, tunneling: String) {
        if (passthrough == this.passthrough && tunneling == this.tunneling) return
        this.passthrough = passthrough
        this.tunneling = tunneling
        passthroughBroken = false
        tunnelingBroken = false
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString(KEY_PASS, passthrough)
            .putString(KEY_TUNNEL, tunneling)
            .putBoolean(KEY_TUNNEL_BROKEN, false).apply()
        refreshAll()
    }

    fun setMultiView(active: Boolean) {
        if (active == multiViewActive) return
        multiViewActive = active
        android.util.Log.i("OTV-video",
            "multiview ${if (active) "on: tunneling+passthrough off" else "off: settings restored"}")
        refreshAll()
    }

    fun markTunnelingBroken(context: Context) {
        tunnelingBroken = true
        if (tunneling == AUTO) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putBoolean(KEY_TUNNEL_BROKEN, true).apply()
        }
    }

    fun markPassthroughBroken() { passthroughBroken = true }

    private fun refreshAll() {
        // Copy: a refresh may rebuild a player, which re-registers nothing
        // but must not trip over the set changing.
        main.post { players.toList().forEach { it.refreshOutput() } }
    }

    /**
     * Devices where tunneling has been checked to work through the app's
     * video path, so "auto" may turn it on. Everything else stays untunneled
     * until it is tested (see docs/design/tunneling-passthrough.md).
     */
    fun autoTunnelingDevice(): Boolean = VERIFIED_TUNNELING_DEVICES.contains(android.os.Build.DEVICE)

    // Checked on the device, tunneled live TV shows a picture and keeps playing
    // through channel changes (#162). Add a device only after testing it.
    private val VERIFIED_TUNNELING_DEVICES = setOf("sabrina") // Chromecast with Google TV

    /** What a player should use right now. */
    fun wanted(
        isTelevision: Boolean,
        mainPlayer: Boolean,
        onCarScreen: Boolean,
        speedIsNormal: Boolean,
        liveStream: Boolean,
        onLayer: Boolean = false,
        audioDelayed: Boolean = false,
    ): Output {
        if (!mainPlayer || multiViewActive || onCarScreen) return Output.PLAIN
        // Tunneled catch-up / movies froze on the Chromecast (clock stuck
        // with data buffered), live streams were fine: live only.
        // Tunneled frames only show on a real video layer (#162).
        // A lip-sync shift needs the sound decoded by the app and not tunneled
        // (neither a bitstream nor a tunnel passes through audio processors).
        val tunnel = onLayer && !tunnelingBroken && speedIsNormal && !audioDelayed && liveStream && when (tunneling) {
            ON -> true
            AUTO -> isTelevision && autoTunnelingDevice()
            else -> false
        }
        val pass = when {
            passthroughBroken || !speedIsNormal || audioDelayed -> Pass.PCM
            passthrough == ON -> Pass.FORCE
            passthrough == OFF -> Pass.PCM
            else -> Pass.DEVICE
        }
        return Output(tunnel, pass)
    }

    /** Encodings a receiver is trusted to decode when passthrough is forced on. */
    private val FORCED_ENCODINGS = intArrayOf(
        AudioFormat.ENCODING_PCM_16BIT,
        AudioFormat.ENCODING_AC3,
        AudioFormat.ENCODING_E_AC3,
        AudioFormat.ENCODING_E_AC3_JOC,
        AudioFormat.ENCODING_DTS,
        AudioFormat.ENCODING_DTS_HD,
        AudioFormat.ENCODING_DOLBY_TRUEHD,
    )

    /** ExoPlayer's renderers, with the audio sink set up for [pass]. */
    class Factory(
        context: Context,
        private val pass: Pass,
        private val delay: AudioDelayProcessor? = null,
    ) : DefaultRenderersFactory(context) {
        override fun buildAudioSink(
            context: Context,
            enableFloatOutput: Boolean,
            enableAudioTrackPlaybackParams: Boolean,
        ): AudioSink? {
            val caps = when (pass) {
                Pass.DEVICE -> {
                    // Same sink as the stock one; only the lip-sync processor
                    // is added (main player only).
                    if (delay == null) return super.buildAudioSink(
                        context, enableFloatOutput, enableAudioTrackPlaybackParams)
                    return DefaultAudioSink.Builder(context)
                        .setEnableFloatOutput(enableFloatOutput)
                        .setEnableAudioTrackPlaybackParams(enableAudioTrackPlaybackParams)
                        .setAudioProcessors(arrayOf(delay))
                        .build()
                }
                Pass.PCM -> AudioCapabilities.DEFAULT_AUDIO_CAPABILITIES
                Pass.FORCE -> AudioCapabilities(FORCED_ENCODINGS, 8)
            }
            return DefaultAudioSink.Builder(context)
                .setAudioCapabilities(caps)
                .setEnableFloatOutput(enableFloatOutput)
                .setEnableAudioTrackPlaybackParams(enableAudioTrackPlaybackParams)
                .apply { if (delay != null) setAudioProcessors(arrayOf(delay)) }
                .build()
        }
    }
}
