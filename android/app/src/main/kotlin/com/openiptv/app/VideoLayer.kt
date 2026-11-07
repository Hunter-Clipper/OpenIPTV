package com.openiptv.app

import android.app.Activity
import android.view.SurfaceHolder
import android.view.SurfaceView
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout

/**
 * A real on-screen video layer (#162) for the main player on TVs.
 *
 * The usual video path draws into a Flutter texture, which the app then
 * paints once per refresh: frames and refreshes drift apart (jitter), the
 * TV's frame-rate request is dropped, and tunneled playback (frames that go
 * straight to the display hardware) has nowhere to arrive. This SurfaceView
 * sits *behind* Flutter's own (transparent) surface, so the video is shown
 * by the system compositor with proper timing and Flutter draws the controls
 * over it. Dart reports where the picture goes ([show]); where Flutter draws
 * nothing, the video shows through.
 */
object VideoLayer {
    private var view: SurfaceView? = null
    private var activity: Activity? = null
    var owner: NativeVideoPlayer? = null
    private var surface: android.view.Surface? = null

    val available: Boolean get() = view != null
    fun currentSurface(): android.view.Surface? = surface

    /** Adds the (hidden) layer under Flutter's view. Called once from MainActivity. */
    fun attach(a: Activity) {
        activity = a
        if (view != null) return
        val content = a.findViewById<ViewGroup>(android.R.id.content)
        val root = content.getChildAt(0) as? FrameLayout ?: return
        val v = SurfaceView(a)
        // Visible but one pixel from the start, so its surface exists before any
        // stream opens; Dart moves and sizes it when a picture is shown.
        v.holder.addCallback(object : SurfaceHolder.Callback {
            override fun surfaceCreated(holder: SurfaceHolder) {
                surface = holder.surface
                owner?.layerSurfaceReady(holder.surface)
            }
            override fun surfaceChanged(h: SurfaceHolder, f: Int, w: Int, ht: Int) {}
            override fun surfaceDestroyed(holder: SurfaceHolder) {
                surface = null
                owner?.layerSurfaceGone()
            }
        })
        root.addView(v, 0, FrameLayout.LayoutParams(1, 1))
        view = v
    }

    /** Shows the layer at [l],[t] size [w]x[h] (pixels) for [p]. */
    fun show(p: NativeVideoPlayer, l: Int, t: Int, w: Int, h: Int) {
        val v = view ?: return
        main.removeCallbacks(hideLater)
        android.util.Log.i("OTV-layer", "show $l,$t ${w}x$h")
        owner = p
        val lp = (v.layoutParams as FrameLayout.LayoutParams)
        if (lp.leftMargin != l || lp.topMargin != t || lp.width != w || lp.height != h) {
            lp.leftMargin = l
            lp.topMargin = t
            lp.width = w
            lp.height = h
            v.layoutParams = lp
        }
        surface?.let { p.layerSurfaceReady(it) }
    }

    /** Takes the layer away from [p] (it goes back to the texture first). */
    fun hide(p: NativeVideoPlayer) {
        if (owner !== p) return
        // Moving between screens (guide pane, full screen) hides and shows
        // again within a moment: keep the surface so the stream isn't
        // restarted by a switch to the texture and back.
        main.removeCallbacks(hideLater)
        main.postDelayed(hideLater, 500)
    }

    private val main = android.os.Handler(android.os.Looper.getMainLooper())
    private val hideLater = Runnable {
        val p = owner ?: return@Runnable
        view?.let {
            val lp = it.layoutParams as FrameLayout.LayoutParams
            lp.leftMargin = 0; lp.topMargin = 0; lp.width = 1; lp.height = 1
            it.layoutParams = lp
        }
        p.layerReleased()
    }
}

/**
 * The "Video layer" setting (Power User Tools): Automatic / On / Off. TVs
 * only. The layer needs a see-through Flutter surface, which is chosen when
 * the screen is created, so a change applies after a restart.
 */
object VideoLayerMode {
    private const val PREFS = "openiptv_native"
    private const val KEY = "video_layer"

    const val AUTO = "auto"
    const val ON = "on"
    const val OFF = "off"

    /** Whether this run of the app was started with the layer. */
    @Volatile var activeAtStart = false

    fun setting(context: android.content.Context): String {
        val v = context.getSharedPreferences(PREFS, android.content.Context.MODE_PRIVATE).getString(KEY, AUTO)
        return if (v == ON || v == OFF) v else AUTO
    }

    fun setSetting(context: android.content.Context, value: String) {
        val v = if (value == ON || value == OFF) value else AUTO
        context.getSharedPreferences(PREFS, android.content.Context.MODE_PRIVATE).edit().putString(KEY, v).apply()
    }

    /** Automatic uses the layer on every TV (the standard way TV players show video). */
    fun wanted(context: android.content.Context): Boolean =
        EngineChannels.isTelevision(context) && setting(context) != OFF

    fun info(context: android.content.Context): Map<String, Any> = mapOf(
        "setting" to setting(context),
        "active" to activeAtStart,
        "wanted" to wanted(context),
    )
}
