package com.openiptv.carvideo

import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.media.MediaMetadata
import android.media.browse.MediaBrowser
import android.media.session.MediaController
import android.media.session.PlaybackState
import android.os.Binder
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.Parcel
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.SurfaceHolder
import android.view.SurfaceView
import android.view.View
import android.view.WindowInsets
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.ImageButton
import android.widget.LinearLayout
import android.widget.TextView

/**
 * OpenIPTV's picture on the Android Auto screen (parked only — Android
 * Auto closes "game" apps when the car moves). Pick something in
 * OpenIPTV's car menu (it plays as sound), then open this to see it.
 *
 * There is no player here: the car screen's surface is handed to
 * OpenIPTV's CarVideoService, which points the player it is already
 * running at it. Title and controls come from OpenIPTV's media session.
 */
class CarVideoActivity : Activity(), SurfaceHolder.Callback {

    private companion object {
        const val TAG = "OTV-carvideo"
        const val APP = "com.openiptv.app"
        const val DESCRIPTOR = "com.openiptv.app.CarVideo"
        const val CLIENT_DESCRIPTOR = "com.openiptv.app.CarVideoClient"
        const val ATTACH = IBinder.FIRST_CALL_TRANSACTION
        const val DETACH = IBinder.FIRST_CALL_TRANSACTION + 1
        const val CLIENT_VIDEO_SIZE = IBinder.FIRST_CALL_TRANSACTION
        const val CLIENT_ON_PHONE = IBinder.FIRST_CALL_TRANSACTION + 1
    }

    private val main = Handler(Looper.getMainLooper())

    private lateinit var videoBox: FrameLayout
    private lateinit var surfaceView: SurfaceView
    private lateinit var hint: TextView
    private lateinit var overlay: LinearLayout
    private lateinit var title: TextView
    private lateinit var subtitle: TextView
    private lateinit var playPause: ImageButton

    // Something was opened on the phone: its picture stays there.
    private var onPhone = false
    private var videoW = 0
    private var videoH = 0
    private var pixelRatio = 1f

    // OpenIPTV's picture service.
    private var service: IBinder? = null
    private var bound = false
    private var holder: SurfaceHolder? = null
    private var attached = false

    // OpenIPTV's media session: title + controls.
    private var browser: MediaBrowser? = null
    private var controller: MediaController? = null

    /** OpenIPTV calls this with the picture size. */
    private val callback = object : Binder() {
        override fun onTransact(code: Int, data: Parcel, reply: Parcel?, flags: Int): Boolean {
            if (code == CLIENT_ON_PHONE) {
                data.enforceInterface(CLIENT_DESCRIPTOR)
                val phone = data.readInt() == 1
                main.post {
                    onPhone = phone
                    updateHint()
                }
                return true
            }
            if (code != CLIENT_VIDEO_SIZE) return super.onTransact(code, data, reply, flags)
            data.enforceInterface(CLIENT_DESCRIPTOR)
            val w = data.readInt()
            val h = data.readInt()
            val r = data.readFloat()
            main.post {
                videoW = w
                videoH = h
                pixelRatio = if (r > 0f) r else 1f
                fitVideo()
                updateHint()
            }
            return true
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        buildViews()
        bindApp()
        connectSession()
    }

    override fun onDestroy() {
        detachSurface()
        if (bound) unbindService(connection)
        bound = false
        controller?.unregisterCallback(sessionCallback)
        browser?.disconnect()
        main.removeCallbacksAndMessages(null)
        super.onDestroy()
    }

    // --- layout ---------------------------------------------------------------

    private fun buildViews() {
        val root = FrameLayout(this).apply { setBackgroundColor(Color.BLACK) }
        surfaceView = SurfaceView(this)
        surfaceView.holder.addCallback(this)
        videoBox = object : FrameLayout(this) {
            override fun onLayout(changed: Boolean, l: Int, t: Int, r: Int, b: Int) {
                super.onLayout(changed, l, t, r, b)
                fitVideo()
            }
        }
        videoBox.addView(surfaceView, FrameLayout.LayoutParams(0, 0, Gravity.CENTER))
        root.addView(videoBox, FrameLayout.LayoutParams(-1, -1))

        hint = TextView(this).apply {
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 20f)
            gravity = Gravity.CENTER
            setPadding(dp(40), dp(32), dp(40), dp(32))
            // Opaque: hides the last frame of whatever played before.
            setBackgroundColor(Color.BLACK)
            text = getString(R.string.hint_pick)
        }
        root.addView(hint, FrameLayout.LayoutParams(-1, -1))

        // Bottom bar: title on the left, round controls on the right.
        overlay = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            background = GradientDrawable(
                GradientDrawable.Orientation.BOTTOM_TOP,
                intArrayOf(0xCC000000.toInt(), 0x00000000),
            )
            setPadding(dp(24), dp(28), dp(16), dp(16))
        }
        val texts = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        title = TextView(this).apply {
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 20f)
            maxLines = 1
            ellipsize = android.text.TextUtils.TruncateAt.END
        }
        subtitle = TextView(this).apply {
            setTextColor(0xCCFFFFFF.toInt())
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
            maxLines = 1
            ellipsize = android.text.TextUtils.TruncateAt.END
        }
        texts.addView(title)
        texts.addView(subtitle)
        overlay.addView(texts, LinearLayout.LayoutParams(0, -2, 1f))
        overlay.addView(roundButton(android.R.drawable.ic_media_previous, R.string.previous) {
            controller?.transportControls?.skipToPrevious()
        })
        playPause = roundButton(android.R.drawable.ic_media_pause, R.string.pause) {
            val c = controller ?: return@roundButton
            if (c.playbackState?.state == PlaybackState.STATE_PLAYING) {
                c.transportControls.pause()
            } else {
                c.transportControls.play()
            }
        }
        overlay.addView(playPause)
        overlay.addView(roundButton(android.R.drawable.ic_media_next, R.string.next) {
            controller?.transportControls?.skipToNext()
        })
        root.addView(
            overlay,
            FrameLayout.LayoutParams(-1, -2, Gravity.BOTTOM),
        )
        overlay.visibility = View.GONE
        // Android Auto draws its own bar over the bottom of the car display
        // (reported as a system bar): keep the picture and controls above it.
        root.setOnApplyWindowInsetsListener { v, insets ->
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
                val bars = insets.getInsets(
                    WindowInsets.Type.systemBars() or WindowInsets.Type.displayCutout(),
                )
                v.setPadding(bars.left, bars.top, bars.right, bars.bottom)
            } else {
                @Suppress("DEPRECATION")
                v.setPadding(
                    insets.systemWindowInsetLeft, insets.systemWindowInsetTop,
                    insets.systemWindowInsetRight, insets.systemWindowInsetBottom,
                )
            }
            insets
        }
        // Tap the picture: show or hide the title and controls.
        root.setOnClickListener {
            if (overlay.visibility == View.VISIBLE) {
                main.removeCallbacks(hideOverlay)
                maybeHideOverlay()
            } else {
                showOverlay()
            }
        }
        setContentView(root)
    }

    private fun roundButton(icon: Int, label: Int, onTap: () -> Unit) =
        ImageButton(this).apply {
            setImageResource(icon)
            contentDescription = getString(label)
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(0x33FFFFFF)
            }
            val size = dp(56)
            layoutParams = LinearLayout.LayoutParams(size, size).apply { marginStart = dp(12) }
            setOnClickListener {
                onTap()
                showOverlay()
            }
        }

    /** Letterboxes the picture to its real shape — never stretched. */
    private fun fitVideo() {
        val boxW = videoBox.width
        val boxH = videoBox.height
        if (boxW == 0 || boxH == 0) return
        var w = boxW
        var h = boxH
        if (videoW > 0 && videoH > 0) {
            val aspect = videoW * pixelRatio / videoH
            if (boxW.toFloat() / boxH > aspect) {
                w = (boxH * aspect).toInt()
            } else {
                h = (boxW / aspect).toInt()
            }
        }
        val lp = surfaceView.layoutParams as FrameLayout.LayoutParams
        if (lp.width != w || lp.height != h) {
            lp.width = w
            lp.height = h
            surfaceView.layoutParams = lp
        }
    }

    // --- the picture (OpenIPTV's CarVideoService) -----------------------------

    private val connection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, binder: IBinder?) {
            service = binder
            attachSurface()
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            // OpenIPTV stopped; Android reconnects when it comes back.
            service = null
            attached = false
        }
    }

    private fun bindApp() {
        val intent = Intent().setComponent(ComponentName(APP, "$APP.CarVideoService"))
        bound = try {
            bindService(intent, connection, Context.BIND_AUTO_CREATE)
        } catch (e: SecurityException) {
            // Not signed with OpenIPTV's key, or OpenIPTV is too old.
            Log.w(TAG, "bind refused: ${e.message}")
            false
        }
        if (!bound) hint.text = getString(R.string.hint_missing)
    }

    override fun surfaceCreated(holder: SurfaceHolder) {
        this.holder = holder
        attachSurface()
    }

    override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {}

    override fun surfaceDestroyed(holder: SurfaceHolder) {
        // Synchronous: OpenIPTV lets go of the surface before it's destroyed.
        detachSurface()
        this.holder = null
    }

    private fun attachSurface() {
        val s = service ?: return
        val h = holder ?: return
        if (attached) return
        transact(s, ATTACH) {
            h.surface.writeToParcel(it, 0)
            it.writeStrongBinder(callback)
        }
        attached = true
    }

    private fun detachSurface() {
        if (!attached) return
        attached = false
        service?.let { transact(it, DETACH) {} }
    }

    private fun transact(binder: IBinder, code: Int, write: (Parcel) -> Unit) {
        val data = Parcel.obtain()
        val reply = Parcel.obtain()
        try {
            data.writeInterfaceToken(DESCRIPTOR)
            write(data)
            binder.transact(code, data, reply, 0)
            reply.readException()
        } catch (e: Exception) {
            Log.w(TAG, "call $code failed: ${e.javaClass.simpleName}")
        } finally {
            data.recycle()
            reply.recycle()
        }
    }

    // --- what's playing (OpenIPTV's media session) ----------------------------

    private fun connectSession() {
        val b = MediaBrowser(
            this,
            ComponentName(APP, "com.ryanheise.audioservice.AudioService"),
            object : MediaBrowser.ConnectionCallback() {
                override fun onConnected() {
                    val c = MediaController(this@CarVideoActivity, browser!!.sessionToken)
                    controller = c
                    c.registerCallback(sessionCallback, main)
                    showMetadata(c.metadata)
                    showState(c.playbackState)
                }
            },
            null,
        )
        browser = b
        try {
            b.connect()
        } catch (e: Exception) {
            Log.w(TAG, "session: ${e.javaClass.simpleName}")
        }
    }

    private val sessionCallback = object : MediaController.Callback() {
        override fun onMetadataChanged(metadata: MediaMetadata?) {
            showMetadata(metadata)
            showOverlay()
        }

        override fun onPlaybackStateChanged(state: PlaybackState?) = showState(state)
    }

    private fun showMetadata(m: MediaMetadata?) {
        title.text = m?.getString(MediaMetadata.METADATA_KEY_TITLE) ?: ""
        val sub = m?.getString(MediaMetadata.METADATA_KEY_ARTIST)
            ?: m?.getString(MediaMetadata.METADATA_KEY_DISPLAY_SUBTITLE) ?: ""
        subtitle.text = sub
        subtitle.visibility = if (sub.isEmpty()) View.GONE else View.VISIBLE
        if (title.text.isNotEmpty() && overlay.visibility != View.VISIBLE) showOverlay()
    }

    private fun showState(state: PlaybackState?) {
        val playing = state?.state == PlaybackState.STATE_PLAYING
        playPause.setImageResource(
            if (playing) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play,
        )
        playPause.contentDescription = getString(if (playing) R.string.pause else R.string.play)
        updateHint()
    }

    private fun isActive(): Boolean {
        val s = controller?.playbackState?.state
        return s == PlaybackState.STATE_PLAYING ||
            s == PlaybackState.STATE_PAUSED ||
            s == PlaybackState.STATE_BUFFERING ||
            s == PlaybackState.STATE_CONNECTING
    }

    private fun updateHint() {
        if (!bound) return
        // The size is reported as 0 while a new stream opens, so a picture
        // size means the current item is showing.
        val active = isActive()
        hint.visibility = if (active && videoW > 0 && !onPhone) View.GONE else View.VISIBLE
        val state = controller?.playbackState
        hint.text = when {
            onPhone -> getString(R.string.hint_on_phone)
            active -> getString(R.string.hint_loading)
            // OpenIPTV's plain-English reason (e.g. the provider refused it).
            state?.state == PlaybackState.STATE_ERROR && !state.errorMessage.isNullOrEmpty() ->
                getString(R.string.hint_error, state.errorMessage)
            else -> getString(R.string.hint_pick)
        }
        if (hint.visibility == View.VISIBLE) showOverlay()
    }

    private fun showOverlay() {
        // Nothing to control (stopped, or playing on the phone): no controls.
        val state = controller?.playbackState?.state
        if (title.text.isNullOrEmpty() || onPhone ||
            !(isActive() || state == PlaybackState.STATE_ERROR)
        ) {
            main.removeCallbacks(hideOverlay)
            overlay.visibility = View.GONE
            return
        }
        overlay.visibility = View.VISIBLE
        main.removeCallbacks(hideOverlay)
        main.postDelayed(hideOverlay, 5000)
    }

    // Hides the controls only over a playing picture; while there's a
    // message instead (loading, paused, couldn't play) they stay put.
    private val hideOverlay: Runnable = Runnable { maybeHideOverlay() }

    private fun maybeHideOverlay() {
        val playing = controller?.playbackState?.state == PlaybackState.STATE_PLAYING
        if (playing && hint.visibility != View.VISIBLE) {
            overlay.visibility = View.GONE
        } else {
            main.postDelayed(hideOverlay, 5000)
        }
    }

    private fun dp(v: Int) = (v * resources.displayMetrics.density).toInt()
}
