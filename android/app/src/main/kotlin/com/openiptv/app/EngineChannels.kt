package com.openiptv.app

import android.app.Application
import android.app.UiModeManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import com.openiptv.engine_hooks.EngineHooksPlugin
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel

/**
 * Native channels that must exist on *every* Flutter engine, not just the
 * one MainActivity shows: the video player and device info. Android Auto
 * binds audio_service's media service while the app isn't open, and that
 * service starts a headless engine that runs the app's Dart code — without
 * these channels it couldn't play anything. Window-bound channels (PiP,
 * Back, updates, files, casting) stay in MainActivity.
 */
object EngineChannels {
    private val players = mutableMapOf<Any, NativeVideoPlayerManager>()

    // MainActivity keeps the screen on while anything plays.
    @Volatile
    var onAnyPlayingChanged: ((Boolean) -> Unit)? = null

    fun install() {
        EngineHooksPlugin.onAttach = { attach(it) }
        EngineHooksPlugin.onDetach = { players.remove(it.binaryMessenger) }
    }

    private fun attach(binding: FlutterPlugin.FlutterPluginBinding) {
        val context = binding.applicationContext
        val messenger = binding.binaryMessenger
        // EdTV integration: this channel is installed on every engine, including
        // audio_service's headless playback engine. Only display metadata and
        // progress cross the app boundary; stream URLs and provider credentials do not.
        MethodChannel(messenger, "openiptv/edtv").setMethodCallHandler { call, result ->
            when (call.method) {
                "takePendingResume" -> {
                    val prefs = context.getSharedPreferences("edtv_bridge", Context.MODE_PRIVATE)
                    val raw = prefs.getString("pending_resume", null)
                    prefs.edit().remove("pending_resume").apply()
                    if (raw == null) {
                        result.success(null)
                    } else {
                        try {
                            val data = org.json.JSONObject(raw)
                            result.success(mapOf(
                                "contentId" to data.optString("contentId"),
                                "contentType" to data.optString("contentType"),
                                "seriesId" to data.optString("seriesId").takeIf { it.isNotEmpty() },
                                "resumePositionMs" to data.optLong("resumePositionMs", 0L),
                            ))
                        } catch (_: Exception) {
                            result.success(null)
                        }
                    }
                }
                "publishQueueSnapshot" -> {
                    val raw = call.arguments as? String
                    if (raw.isNullOrBlank()) {
                        result.error("bad_arguments", "Queue snapshot missing", null)
                    } else {
                        try {
                            val data = org.json.JSONObject(raw)
                            if (data.optInt("apiVersion") != 1) {
                                result.error("bad_version", "Unsupported queue snapshot", null)
                            } else {
                                context.getSharedPreferences("edtv_bridge", Context.MODE_PRIVATE)
                                    .edit()
                                    .putString("queue_snapshot", raw)
                                    .putLong("queue_snapshot_updated_at", data.optLong("updatedAt", 0L))
                                    .apply()
                                result.success(null)
                            }
                        } catch (_: Exception) {
                            result.error("bad_arguments", "Invalid queue snapshot", null)
                        }
                    }
                }
                "publishPlayback" -> {
                    val data = call.arguments as? Map<*, *>
                    if (data == null) {
                        result.error("bad_arguments", "Playback metadata missing", null)
                    } else {
                        val broadcast = Intent("tv.edtv.home.IPTV_PLAYBACK")
                            .setClassName("tv.edtv.home", "tv.edtv.home.IptvPlaybackReceiver")
                        for ((key, value) in data) {
                            if (key is String && (value is String || value is Number ||
                                value is Boolean)) {
                                // Android's getLongExtra() does not widen an Integer
                                // extra. Flutter encodes Dart ints as Integer when
                                // they fit, so persist all millisecond/timestamp fields
                                // as Long regardless of their original numeric type.
                                when {
                                    key in setOf("positionMs", "durationMs", "timestamp") && value is Number ->
                                        broadcast.putExtra(key, value.toLong())
                                    value is String -> broadcast.putExtra(key, value)
                                    value is Long -> broadcast.putExtra(key, value)
                                    value is Int -> broadcast.putExtra(key, value)
                                    value is Boolean -> broadcast.putExtra(key, value)
                                }
                            }
                        }
                        context.sendBroadcast(broadcast)
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(messenger, "openiptv/device").setMethodCallHandler { call, result ->
            when (call.method) {
                "isTelevision" -> result.success(isTelevision(context))
                // Free space where the app keeps its data (database
                // maintenance needs room for a temporary copy).
                "freeDiskBytes" -> result.success(
                    android.os.StatFs(context.filesDir.path).availableBytes,
                )
                // Google TV / Fire TV often ship without a document picker:
                // OPEN_DOCUMENT resolves to a framework stub that just
                // cancels, so "choose a file" silently does nothing.
                "hasDocumentPicker" -> {
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT)
                        .addCategory(Intent.CATEGORY_OPENABLE)
                        .setType("*/*")
                    val handler = context.packageManager
                        .resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY)
                        ?.activityInfo?.packageName
                    result.success(handler != null && !handler.contains("frameworkpackagestubs"))
                }
                "networkInfo" -> result.success(networkInfo(context))
                "setStartup" -> {
                    StartupLauncher.set(
                        context,
                        call.argument<Boolean>("boot") ?: false,
                        call.argument<Boolean>("wake") ?: false,
                    )
                    result.success(null)
                }
                "canDrawOverlays" -> result.success(StartupLauncher.canDrawOverlays(context))
                "requestOverlayPermission" -> {
                    StartupLauncher.requestOverlayPermission(context)
                    result.success(null)
                }
                // Optional anonymous crash reports (#150).
                "deviceFacts" -> result.success(NativeCrashReporter.deviceFacts())
                "takeNativeCrash" -> result.success(NativeCrashReporter.take(context))
                "takeExitReports" -> result.success(
                    NativeCrashReporter.takeExitReports(context, call.argument<Boolean>("report") ?: false),
                )
                // Graphics mode (#157): applies on the next start.
                "graphicsInfo" -> result.success(GraphicsMode.info(context))
                "setGraphicsMode" -> {
                    GraphicsMode.setSetting(context, call.argument<String>("mode") ?: GraphicsMode.AUTO)
                    result.success(GraphicsMode.info(context))
                }
                // Video layer (#162): applies on the next start.
                "videoLayerInfo" -> result.success(VideoLayerMode.info(context))
                // Dart has decided to draw for the layer: only now may a stream
                // take it (otherwise the picture would sit in a 1 px layer).
                "videoLayerConfirm" -> {
                    VideoLayer.dartConfirmed = true
                    result.success(true)
                }
                "setVideoLayerMode" -> {
                    VideoLayerMode.setSetting(context, call.argument<String>("mode") ?: VideoLayerMode.AUTO)
                    result.success(VideoLayerMode.info(context))
                }
                "restartApp" -> {
                    result.success(true)
                    RestartActivity.restart(context)
                }
                else -> result.notImplemented()
            }
        }
        players[messenger] = NativeVideoPlayerManager(
            context,
            messenger,
            binding.textureRegistry,
        ) { anyPlaying -> onAnyPlayingChanged?.invoke(anyPlaying) }
    }

    /**
     * The active connection, for Settings → Power User Tools: transport
     * (wifi / ethernet / cellular / other / none), whether a VPN carries
     * it, the device's own addresses on it and its DNS servers.
     */
    fun networkInfo(context: Context): Map<String, Any?> {
        val cm = context.getSystemService(ConnectivityManager::class.java)
            ?: return mapOf("transport" to "none")
        fun isVpn(n: android.net.Network) = cm.getNetworkCapabilities(n)
            ?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) == true
        // With a VPN up, the app's "active" network is the tunnel. Report
        // the real Wi-Fi / Ethernet / mobile network as the connection and
        // device address, and the tunnel's address on its own.
        val vpnNet = cm.allNetworks.firstOrNull { isVpn(it) }
        val active = cm.activeNetwork
        val real = active?.takeIf { !isVpn(it) } ?: cm.allNetworks.firstOrNull {
            val c = cm.getNetworkCapabilities(it)
            c != null && !c.hasTransport(NetworkCapabilities.TRANSPORT_VPN) &&
                c.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
        }
        if (real == null && vpnNet == null) return mapOf("transport" to "none")
        val caps = real?.let { cm.getNetworkCapabilities(it) }
        val link = real?.let { cm.getLinkProperties(it) }
        val transport = when {
            caps == null -> "other"
            caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> "ethernet"
            caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "wifi"
            caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "cellular"
            else -> "other"
        }
        val vpnLink = vpnNet?.let { cm.getLinkProperties(it) }
        return mapOf(
            "transport" to transport,
            "vpn" to (vpnNet != null),
            "addresses" to (link?.linkAddresses?.mapNotNull { it.address?.hostAddress } ?: emptyList()),
            "dns" to (link?.dnsServers?.mapNotNull { it.hostAddress } ?: emptyList()),
            "vpnAddresses" to (vpnLink?.linkAddresses?.mapNotNull { it.address?.hostAddress } ?: emptyList()),
            "vpnDns" to (vpnLink?.dnsServers?.mapNotNull { it.hostAddress } ?: emptyList()),
        )
    }

    /** TV mode (Android TV, Google TV, Fire TV), or Leanback hardware. */
    fun isTelevision(context: Context): Boolean {
        val uiModeManager = context.getSystemService(Context.UI_MODE_SERVICE) as UiModeManager
        return uiModeManager.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION ||
            context.packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK)
    }
}

/** Installs [EngineChannels] before any Flutter engine is created. */
class OpenIptvApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        // The restart helper's own process must not start Flutter.
        if (RestartActivity.isHelperProcess()) return
        GraphicsMode.apply(this)
        EngineChannels.install()
        NativeCrashReporter.install(this)
        OutputModes.load(this)
        StartupLauncher.registerWake(this)
    }
}
