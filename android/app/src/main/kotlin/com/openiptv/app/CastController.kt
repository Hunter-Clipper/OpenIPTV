package com.openiptv.app

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.mediarouter.media.MediaRouteSelector
import androidx.mediarouter.media.MediaRouter
import com.google.android.gms.cast.CastMediaControlIntent
import com.google.android.gms.cast.MediaInfo
import com.google.android.gms.cast.MediaLoadRequestData
import com.google.android.gms.cast.MediaMetadata
import com.google.android.gms.cast.MediaSeekOptions
import com.google.android.gms.cast.MediaStatus
import com.google.android.gms.cast.framework.CastContext
import com.google.android.gms.cast.framework.CastOptions
import com.google.android.gms.cast.framework.CastSession
import com.google.android.gms.cast.framework.CastState
import com.google.android.gms.cast.framework.OptionsProvider
import com.google.android.gms.cast.framework.SessionManagerListener
import com.google.android.gms.cast.framework.SessionProvider
import com.google.android.gms.cast.framework.media.CastMediaOptions
import com.google.android.gms.cast.framework.media.NotificationOptions
import com.google.android.gms.cast.framework.media.RemoteMediaClient
import com.google.android.gms.common.images.WebImage
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Cast framework configuration, named in the manifest. Uses Google's
 * built-in Default Media Receiver (no custom receiver app), and a media
 * notification that opens OpenIPTV when tapped.
 */
class CastOptionsProvider : OptionsProvider {
    override fun getCastOptions(context: Context): CastOptions {
        val notification = NotificationOptions.Builder()
            .setTargetActivityClassName(MainActivity::class.java.name)
            .build()
        return CastOptions.Builder()
            .setReceiverApplicationId(
                CastMediaControlIntent.DEFAULT_MEDIA_RECEIVER_APPLICATION_ID
            )
            .setCastMediaOptions(
                CastMediaOptions.Builder()
                    .setNotificationOptions(notification)
                    .build()
            )
            .build()
    }

    override fun getAdditionalSessionProviders(context: Context): List<SessionProvider>? =
        null
}

/**
 * Casting to Chromecast / Google TV devices for the Dart side, on the
 * "openiptv/cast" method channel and "openiptv/cast_events" event channel.
 *
 * Dart gets one state map on every change (see [stateMap]): whether any
 * cast device is on the network, the discovered devices (while the picker
 * asks for discovery), the session (idle / connecting / connected, device
 * name) and the receiver's playback (state, position, duration). Devices
 * are listed through MediaRouter so the app can show them in its own
 * styled sheet instead of the framework's AppCompat dialog.
 */
class CastController(
    private val context: Context,
    messenger: BinaryMessenger,
) {
    private val main = Handler(Looper.getMainLooper())
    private var castContext: CastContext? = null
    private var router: MediaRouter? = null
    private var selector: MediaRouteSelector? = null
    private var events: EventChannel.EventSink? = null
    // Screens that want an active device scan (the player, the picker);
    // scanning runs while any of them is open.
    private var discoveryRequests = 0
    private var connecting = false
    private var client: RemoteMediaClient? = null

    private val routerCallback = object : MediaRouter.Callback() {
        override fun onRouteAdded(router: MediaRouter, route: MediaRouter.RouteInfo) = emit()
        override fun onRouteRemoved(router: MediaRouter, route: MediaRouter.RouteInfo) = emit()
        override fun onRouteChanged(router: MediaRouter, route: MediaRouter.RouteInfo) = emit()
    }

    private val clientCallback = object : RemoteMediaClient.Callback() {
        override fun onStatusUpdated() = emit()
        override fun onMetadataUpdated() = emit()
    }

    private val sessionListener = object : SessionManagerListener<CastSession> {
        override fun onSessionStarting(session: CastSession) {
            connecting = true
            emit()
        }
        override fun onSessionStarted(session: CastSession, sessionId: String) =
            attach(session)
        override fun onSessionResumed(session: CastSession, wasSuspended: Boolean) =
            attach(session)
        override fun onSessionStartFailed(session: CastSession, error: Int) {
            Log.w("OTV-cast", "session start failed: $error")
            detach()
        }
        override fun onSessionEnding(session: CastSession) {}
        override fun onSessionEnded(session: CastSession, error: Int) = detach()
        override fun onSessionResuming(session: CastSession, sessionId: String) {
            connecting = true
            emit()
        }
        override fun onSessionResumeFailed(session: CastSession, error: Int) = detach()
        override fun onSessionSuspended(session: CastSession, reason: Int) = emit()
    }

    // Position ticks while something is loaded on the receiver.
    private val ticker = object : Runnable {
        override fun run() {
            if (client?.hasMediaSession() == true) emit()
            main.postDelayed(this, 1000)
        }
    }

    init {
        MethodChannel(messenger, "openiptv/cast").setMethodCallHandler { call, result ->
            handle(call, result)
        }
        EventChannel(messenger, "openiptv/cast_events").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                    events = sink
                    emit()
                }
                override fun onCancel(arguments: Any?) {
                    events = null
                }
            }
        )
        // Play Services may be missing (some TV boxes, de-Googled phones):
        // casting is then simply unavailable.
        try {
            CastContext.getSharedInstance(context, Executors.newSingleThreadExecutor())
                .addOnSuccessListener { ctx -> main.post { setUp(ctx) } }
                .addOnFailureListener { e -> Log.w("OTV-cast", "unavailable: $e") }
        } catch (e: Exception) {
            Log.w("OTV-cast", "unavailable: $e")
        }
    }

    private fun setUp(ctx: CastContext) {
        castContext = ctx
        val sel = ctx.mergedSelector ?: MediaRouteSelector.Builder()
            .addControlCategory(
                CastMediaControlIntent.categoryForCast(
                    CastMediaControlIntent.DEFAULT_MEDIA_RECEIVER_APPLICATION_ID
                )
            ).build()
        selector = sel
        router = MediaRouter.getInstance(context).also {
            // Passive callback: keeps the device list current without an
            // active scan (that only runs while the picker is open).
            it.addCallback(sel, routerCallback, 0)
        }
        applyDiscovery()
        ctx.addCastStateListener { emit() }
        ctx.sessionManager.addSessionManagerListener(sessionListener, CastSession::class.java)
        ctx.sessionManager.currentCastSession?.let { attach(it) }
        main.post(ticker)
        emit()
    }

    private fun applyDiscovery() {
        val r = router ?: return
        val sel = selector ?: return
        r.removeCallback(routerCallback)
        r.addCallback(
            sel,
            routerCallback,
            if (discoveryRequests > 0) MediaRouter.CALLBACK_FLAG_REQUEST_DISCOVERY else 0,
        )
    }

    private fun attach(session: CastSession) {
        Log.i("OTV-cast", "session connected")
        connecting = false
        client?.unregisterCallback(clientCallback)
        client = session.remoteMediaClient?.also { it.registerCallback(clientCallback) }
        emit()
    }

    private fun detach() {
        connecting = false
        client?.unregisterCallback(clientCallback)
        client = null
        emit()
    }

    private fun devices(): List<MediaRouter.RouteInfo> {
        val r = router ?: return emptyList()
        val sel = selector ?: return emptyList()
        // Sorted so the list doesn't reshuffle under the user's finger.
        return r.routes.filter {
            !it.isDefaultOrBluetooth && it.isEnabled && it.matchesSelector(sel)
        }.sortedBy { it.name.lowercase() }
    }

    private fun stateMap(): Map<String, Any?> {
        val ctx = castContext
        val session = ctx?.sessionManager?.currentCastSession
        val connected = session?.isConnected == true
        val c = client
        val status = c?.mediaStatus
        val devices = devices()
        val playerState = when (status?.playerState) {
            MediaStatus.PLAYER_STATE_PLAYING -> "playing"
            MediaStatus.PLAYER_STATE_PAUSED -> "paused"
            MediaStatus.PLAYER_STATE_BUFFERING, MediaStatus.PLAYER_STATE_LOADING -> "buffering"
            else -> "idle"
        }
        val idleReason = when (status?.idleReason) {
            MediaStatus.IDLE_REASON_ERROR -> "error"
            MediaStatus.IDLE_REASON_FINISHED -> "finished"
            MediaStatus.IDLE_REASON_CANCELED -> "canceled"
            MediaStatus.IDLE_REASON_INTERRUPTED -> "interrupted"
            else -> null
        }
        return mapOf(
            "supported" to (ctx != null),
            // The framework's cast state only tracks its own MediaRouteButton;
            // our own discovery result counts too.
            "available" to (ctx != null &&
                (ctx.castState != CastState.NO_DEVICES_AVAILABLE || devices.isNotEmpty())),
            "session" to when {
                connected -> "connected"
                connecting || ctx?.castState == CastState.CONNECTING -> "connecting"
                else -> "idle"
            },
            "device" to session?.castDevice?.friendlyName,
            "devices" to devices.map {
                mapOf(
                    "id" to it.id,
                    "name" to it.name,
                    "speaker" to (it.deviceType == MediaRouter.RouteInfo.DEVICE_TYPE_SPEAKER),
                )
            },
            "playerState" to playerState,
            "idleReason" to idleReason,
            "contentId" to status?.mediaInfo?.contentId,
            "title" to status?.mediaInfo?.metadata?.getString(MediaMetadata.KEY_TITLE),
            "subtitle" to status?.mediaInfo?.metadata?.getString(MediaMetadata.KEY_SUBTITLE),
            "live" to (status?.mediaInfo?.streamType == MediaInfo.STREAM_TYPE_LIVE),
            "positionMs" to (c?.approximateStreamPosition ?: 0L),
            "durationMs" to (c?.streamDuration?.takeIf { it > 0 } ?: 0L),
            "volume" to (session?.volume ?: 0.0),
        )
    }

    private fun emit() {
        main.post { events?.success(stateMap()) }
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "ping" -> result.success(true)
            "startDiscovery" -> {
                discoveryRequests++
                applyDiscovery()
                emit()
                result.success(null)
            }
            "stopDiscovery" -> {
                discoveryRequests = (discoveryRequests - 1).coerceAtLeast(0)
                applyDiscovery()
                result.success(null)
            }
            "connect" -> {
                val id = call.argument<String>("id")
                val route = devices().firstOrNull { it.id == id }
                Log.i("OTV-cast", "connect requested, route found=${route != null}")
                if (route == null) {
                    result.success(false)
                } else {
                    connecting = true
                    router?.selectRoute(route)
                    emit()
                    result.success(true)
                }
            }
            "disconnect" -> {
                castContext?.sessionManager?.endCurrentSession(true)
                result.success(null)
            }
            "load" -> load(call, result)
            "play" -> { client?.play(); result.success(null) }
            "pause" -> { client?.pause(); result.success(null) }
            "seek" -> {
                val ms = call.argument<Number>("positionMs")?.toLong() ?: 0L
                client?.seek(MediaSeekOptions.Builder().setPosition(ms).build())
                result.success(null)
            }
            "setVolume" -> {
                val v = call.argument<Double>("volume") ?: 0.5
                try {
                    castContext?.sessionManager?.currentCastSession?.volume = v.coerceIn(0.0, 1.0)
                } catch (e: Exception) {
                    Log.w("OTV-cast", "volume: $e")
                }
                result.success(null)
            }
            "stopMedia" -> { client?.stop(); result.success(null) }
            else -> result.notImplemented()
        }
    }

    // Loads a stream on the receiver; replies true once the receiver
    // accepted it, false if it refused (unsupported format, unreachable…).
    private fun load(call: MethodCall, result: MethodChannel.Result) {
        val c = client
        val url = call.argument<String>("url")
        if (c == null || url == null) {
            result.success(false)
            return
        }
        val live = call.argument<Boolean>("live") ?: false
        val metadata = MediaMetadata(
            if (live) MediaMetadata.MEDIA_TYPE_GENERIC else MediaMetadata.MEDIA_TYPE_MOVIE
        ).apply {
            call.argument<String>("title")?.let { putString(MediaMetadata.KEY_TITLE, it) }
            call.argument<String>("subtitle")?.let { putString(MediaMetadata.KEY_SUBTITLE, it) }
            call.argument<String>("imageUrl")?.let {
                try {
                    addImage(WebImage(android.net.Uri.parse(it)))
                } catch (_: Exception) {}
            }
        }
        val info = MediaInfo.Builder(url)
            .setStreamType(if (live) MediaInfo.STREAM_TYPE_LIVE else MediaInfo.STREAM_TYPE_BUFFERED)
            .setContentType(call.argument<String>("contentType") ?: "video/mp4")
            .setMetadata(metadata)
            .build()
        val request = MediaLoadRequestData.Builder()
            .setMediaInfo(info)
            .setAutoplay(true)
            .setCurrentTime(call.argument<Number>("startMs")?.toLong() ?: 0L)
            .build()
        var replied = false
        fun reply(ok: Boolean) {
            if (replied) return
            replied = true
            result.success(ok)
        }
        try {
            c.load(request).setResultCallback { r ->
                Log.i("OTV-cast", "load ${call.argument<String>("contentType")} ok=${r.status.isSuccess} code=${r.status.statusCode}")
                main.post { reply(r.status.isSuccess) }
            }
        } catch (e: Exception) {
            Log.w("OTV-cast", "load failed: $e")
            reply(false)
        }
    }
}
