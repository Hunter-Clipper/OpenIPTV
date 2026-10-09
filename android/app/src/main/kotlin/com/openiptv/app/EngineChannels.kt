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
        MethodChannel(messenger, "openiptv/device").setMethodCallHandler { call, result ->
            when (call.method) {
                "isTelevision" -> result.success(isTelevision(context))
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
        EngineChannels.install()
    }
}
