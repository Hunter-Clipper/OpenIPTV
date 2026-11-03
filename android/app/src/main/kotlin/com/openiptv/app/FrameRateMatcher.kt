package com.openiptv.app

import android.app.Activity
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Display
import java.lang.ref.WeakReference
import kotlin.math.abs

/**
 * Auto frame rate (#149): asks the screen to run at a refresh rate that
 * suits the video, e.g. 24 Hz (or 48 / 72 / 96) for a 24 fps film, so motion
 * isn't judder-stepped to 60 Hz.
 *
 * Video is drawn into a Flutter texture, so ExoPlayer's own frame-rate
 * strategy (which acts on the surface it renders to) can't reach the display.
 * Instead we pick one of the display's modes, at the screen's current
 * resolution, and set it as the window's preferred mode. Off unless the user
 * turned "Match Frame Rate" on in Settings → Playback.
 */
object FrameRateMatcher {
    private const val TAG = "OTV-fps"
    // How close a mode's rate must be to a whole multiple of the video's.
    private const val TOLERANCE_HZ = 0.12f

    @Volatile var enabled = false
    private var activity: WeakReference<Activity>? = null
    private var applied = false
    private val handler = Handler(Looper.getMainLooper())
    private val restoreNow = Runnable { restoreInternal() }

    fun attach(a: Activity) { activity = WeakReference(a) }

    /** Picks the best matching mode for [fps]; no-op when nothing fits. */
    fun match(fps: Float) {
        if (!enabled || fps <= 0f || Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        // Changing channel stops and restarts the player: keep the mode.
        handler.removeCallbacks(restoreNow)
        val act = activity?.get() ?: return
        act.runOnUiThread {
            @Suppress("DEPRECATION")
            val display = act.windowManager.defaultDisplay ?: return@runOnUiThread
            val current = display.mode
            val best = bestMode(fps, current, display.supportedModes.toList()) ?: return@runOnUiThread
            if (best.modeId == current.modeId && !applied) return@runOnUiThread
            val attrs = act.window.attributes
            if (attrs.preferredDisplayModeId == best.modeId) return@runOnUiThread
            attrs.preferredDisplayModeId = best.modeId
            act.window.attributes = attrs
            applied = true
            Log.i(TAG, "video ${fps}fps -> ${best.refreshRate}Hz (mode ${best.modeId})")
        }
    }

    /**
     * Playback ended: give the screen back to the system. Slightly delayed,
     * so zapping between channels doesn't flip the display mode each time.
     */
    fun restore(immediately: Boolean = false) {
        handler.removeCallbacks(restoreNow)
        if (immediately) restoreInternal() else handler.postDelayed(restoreNow, 2_000)
    }

    private fun restoreInternal() {
        if (!applied) return
        val act = activity?.get() ?: return
        act.runOnUiThread {
            val attrs = act.window.attributes
            attrs.preferredDisplayModeId = 0
            act.window.attributes = attrs
            applied = false
            Log.i(TAG, "restored the system refresh rate")
        }
    }

    /**
     * The lowest whole multiple of [fps] (1x, 2x, 3x, 4x, 5x) that one of the
     * modes sharing the current resolution hits within [TOLERANCE_HZ].
     */
    internal fun bestMode(fps: Float, current: Display.Mode, modes: List<Display.Mode>): Display.Mode? {
        val sameSize = modes.filter {
            it.physicalWidth == current.physicalWidth && it.physicalHeight == current.physicalHeight
        }
        for (k in 1..5) {
            val target = fps * k
            val hit = sameSize
                .filter { abs(it.refreshRate - target) <= TOLERANCE_HZ }
                .minByOrNull { abs(it.refreshRate - target) }
            if (hit != null) return hit
        }
        return null
    }
}
