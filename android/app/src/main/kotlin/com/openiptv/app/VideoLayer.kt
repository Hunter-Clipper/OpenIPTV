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
    private var owner: NativeVideoPlayer? = null
    private var surface: android.view.Surface? = null

    /** Adds the (hidden) layer under Flutter's view. Called once from MainActivity. */
    fun attach(a: Activity) {
        activity = a
        if (view != null) return
        val content = a.findViewById<ViewGroup>(android.R.id.content)
        val root = content.getChildAt(0) as? FrameLayout ?: return
        val v = SurfaceView(a)
        v.visibility = View.GONE
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
        owner = p
        val lp = (v.layoutParams as FrameLayout.LayoutParams)
        if (lp.leftMargin != l || lp.topMargin != t || lp.width != w || lp.height != h) {
            lp.leftMargin = l
            lp.topMargin = t
            lp.width = w
            lp.height = h
            v.layoutParams = lp
        }
        if (v.visibility != View.VISIBLE) v.visibility = View.VISIBLE
        surface?.let { p.layerSurfaceReady(it) }
    }

    /** Takes the layer away from [p] (it goes back to the texture first). */
    fun hide(p: NativeVideoPlayer) {
        if (owner !== p) return
        p.layerSurfaceGone()
        owner = null
        view?.visibility = View.GONE
    }
}
