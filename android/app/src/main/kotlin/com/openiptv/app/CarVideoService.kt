package com.openiptv.app

import android.app.Service
import android.content.Intent
import android.os.Binder
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.Parcel
import android.view.Surface
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * Sends the app's main player picture to another screen — the "OpenIPTV
 * Video" car add-on (android/carvideo) — and back. The add-on borrows the
 * one player the app already has, so the stream, the sound, the car's
 * controls and progress saving stay exactly as they are. Main thread only.
 */
object CarVideo {
    private var player: NativeVideoPlayer? = null
    private var surface: Surface? = null
    private var client: IBinder? = null

    // Whether the current stream was started from the car (it shows on the
    // car screen) or on the phone (it stays on the phone).
    private var toCar = true
    private val clientDied = IBinder.DeathRecipient {
        Handler(Looper.getMainLooper()).post { detach() }
    }

    fun setPlayer(p: NativeVideoPlayer) {
        player?.let {
            it.onVideoSize = null
            if (surface != null) it.setExternalSurface(null)
        }
        player = p
        p.onVideoSize = { w, h, r -> sendSize(w, h, r) }
        route()
    }

    /** Called by [p] for every new stream: started from the car or not. */
    fun routeToCar(p: NativeVideoPlayer, car: Boolean) {
        if (p !== player || car == toCar) return
        toCar = car
        route()
    }

    /** The stream started or stopped: the car screen's "playing on your phone" follows it. */
    fun streamStateChanged(p: NativeVideoPlayer) {
        if (p === player && surface != null && !toCar) sendElsewhere(p.hasStream)
    }

    /** Points the player at the car screen or back at the app, and tells the car screen. */
    private fun route() {
        val p = player ?: return
        val s = surface
        p.setExternalSurface(if (s != null && toCar) s else null)
        if (s == null) return
        sendElsewhere(!toCar && p.hasStream)
        if (toCar) p.currentVideoSize.let { (w, h, r) -> sendSize(w, h, r) }
    }

    fun playerGone(p: NativeVideoPlayer) {
        if (player === p) player = null
    }

    fun attach(s: Surface, callback: IBinder?) {
        detach()
        surface = s
        client = callback
        try {
            callback?.linkToDeath(clientDied, 0)
        } catch (e: Exception) {
            // Already gone.
            detach()
            return
        }
        android.util.Log.i("OTV-carvideo", "car screen attached (player ${player != null}, car $toCar)")
        route()
    }

    fun detach() {
        val s = surface ?: return
        surface = null
        player?.setExternalSurface(null)
        s.release()
        try {
            client?.unlinkToDeath(clientDied, 0)
        } catch (e: Exception) {
        }
        client = null
        android.util.Log.i("OTV-carvideo", "car screen detached")
    }

    private fun sendElsewhere(onPhone: Boolean) {
        val c = client ?: return
        val data = Parcel.obtain()
        try {
            data.writeInterfaceToken(CarVideoService.CLIENT_DESCRIPTOR)
            data.writeInt(if (onPhone) 1 else 0)
            c.transact(CarVideoService.CLIENT_ON_PHONE, data, null, IBinder.FLAG_ONEWAY)
        } catch (e: Exception) {
        } finally {
            data.recycle()
        }
    }

    private fun sendSize(w: Int, h: Int, ratio: Float) {
        if (!toCar) return
        val c = client ?: return
        val data = Parcel.obtain()
        try {
            data.writeInterfaceToken(CarVideoService.CLIENT_DESCRIPTOR)
            data.writeInt(w)
            data.writeInt(h)
            data.writeFloat(ratio)
            c.transact(CarVideoService.CLIENT_VIDEO_SIZE, data, null, IBinder.FLAG_ONEWAY)
        } catch (e: Exception) {
            // The add-on went away; its death notice detaches.
        } finally {
            data.recycle()
        }
    }
}

/**
 * Bound by the car add-on (protected by a signature permission). A plain
 * Binder: ATTACH hands over the car screen's Surface and a callback for the
 * picture size; DETACH is a synchronous call, so the player has let go of
 * the surface before the car screen destroys it.
 */
class CarVideoService : Service() {
    companion object {
        const val DESCRIPTOR = "com.openiptv.app.CarVideo"
        const val CLIENT_DESCRIPTOR = "com.openiptv.app.CarVideoClient"
        const val ATTACH = IBinder.FIRST_CALL_TRANSACTION
        const val DETACH = IBinder.FIRST_CALL_TRANSACTION + 1
        const val CLIENT_VIDEO_SIZE = IBinder.FIRST_CALL_TRANSACTION
        const val CLIENT_ON_PHONE = IBinder.FIRST_CALL_TRANSACTION + 1

        /** Bumped when the add-on protocol changes. */
        const val VERSION = 1
    }

    private val main = Handler(Looper.getMainLooper())

    private val binder = object : Binder() {
        override fun onTransact(code: Int, data: Parcel, reply: Parcel?, flags: Int): Boolean {
            when (code) {
                ATTACH -> {
                    data.enforceInterface(DESCRIPTOR)
                    val surface = Surface.CREATOR.createFromParcel(data)
                    val callback = data.readStrongBinder()
                    onMain { CarVideo.attach(surface, callback) }
                }
                DETACH -> {
                    data.enforceInterface(DESCRIPTOR)
                    onMain { CarVideo.detach() }
                }
                INTERFACE_TRANSACTION -> {
                    reply?.writeString(DESCRIPTOR)
                    return true
                }
                else -> return super.onTransact(code, data, reply, flags)
            }
            reply?.writeNoException()
            reply?.writeInt(VERSION)
            return true
        }
    }

    /** Runs [block] on the main thread and waits for it (bounded). */
    private fun onMain(block: () -> Unit) {
        if (Looper.myLooper() == Looper.getMainLooper()) {
            block()
            return
        }
        val done = CountDownLatch(1)
        main.post {
            try {
                block()
            } finally {
                done.countDown()
            }
        }
        done.await(5, TimeUnit.SECONDS)
    }

    override fun onBind(intent: Intent?): IBinder = binder

    override fun onUnbind(intent: Intent?): Boolean {
        main.post { CarVideo.detach() }
        return false
    }
}
