package com.openiptv.app

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import android.os.Handler
import android.os.Looper
import com.wireguard.android.backend.GoBackend
import com.wireguard.android.backend.Tunnel
import com.wireguard.config.BadConfigException
import com.wireguard.config.Config
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.StringReader
import java.util.concurrent.Executors

/**
 * Built-in WireGuard VPN for Settings → Power User Tools (#41), on channel
 * `openiptv/vpn`. Uses the official WireGuard tunnel library (Apache-2.0)
 * in userspace — no root, Android's own VPN permission.
 *
 * The profile text (it holds a private key) is kept by Dart in secure
 * storage and passed in on connect; nothing is stored here.
 *
 * Route "app" sends only OpenIPTV through the tunnel (other apps keep the
 * normal connection); "device" sends everything.
 */
class VpnController(private val activity: Activity) : MethodChannel.MethodCallHandler {

    companion object {
        const val PERMISSION_REQUEST = 4712
        private const val TUNNEL_NAME = "openiptv"
    }

    private val backend by lazy { GoBackend(activity.applicationContext) }
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    private val tunnel = object : Tunnel {
        override fun getName() = TUNNEL_NAME
        override fun onStateChange(newState: Tunnel.State) {}
    }

    // A connect waiting for the user to allow the VPN (WireGuard or OpenVPN).
    private var pending: Pair<MethodCall, MethodChannel.Result>? = null

    /** Shows Android's VPN prompt if needed; true when allowed already. */
    private fun allowed(call: MethodCall, result: MethodChannel.Result): Boolean {
        val ask: Intent = VpnService.prepare(activity) ?: return true
        pending?.second?.success("denied")
        pending = call to result
        activity.startActivityForResult(ask, PERMISSION_REQUEST)
        return false
    }

    private fun ovpnConnect(call: MethodCall, result: MethodChannel.Result) {
        if (!allowed(call, result)) return
        // One VPN at a time: bring WireGuard down first.
        work(result) {
            if (backend.getState(tunnel) == Tunnel.State.UP) {
                backend.setState(tunnel, Tunnel.State.DOWN, null)
            }
            OpenVpnService.pending = OpenVpnService.Request(
                profile = call.argument<String>("config") ?: "",
                user = call.argument<String>("user"),
                pass = call.argument<String>("pass"),
                appOnly = (call.argument<String>("route") ?: "app") == "app",
            )
            activity.startService(
                Intent(activity, OpenVpnService::class.java)
                    .setAction(OpenVpnService.ACTION_CONNECT)
            )
            "ok"
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "validate" -> result.success(validate(call.argument<String>("config") ?: ""))
            "connect" -> connect(call, result)
            "disconnect" -> work(result) {
                backend.setState(tunnel, Tunnel.State.DOWN, null)
                "ok"
            }
            "status" -> work(result) { status() }
            // OpenVPN (OpenVPN 3 core, OpenVpnService).
            "ovpnValidate" -> work(result) {
                OpenVpnNative.validate(call.argument<String>("config") ?: "")
            }
            "ovpnConnect" -> ovpnConnect(call, result)
            "ovpnDisconnect" -> {
                activity.startService(
                    Intent(activity, OpenVpnService::class.java)
                        .setAction(OpenVpnService.ACTION_DISCONNECT)
                )
                result.success("ok")
            }
            "ovpnStatus" -> {
                val stats = OpenVpnNative.stats()
                result.success(mapOf(
                    "state" to OpenVpnService.state,
                    "error" to OpenVpnService.lastError,
                    "rx" to stats[0],
                    "tx" to stats[1],
                ))
            }
            else -> result.notImplemented()
        }
    }

    /** Null when the profile is usable, else a short reason. */
    private fun validate(text: String): String? = try {
        Config.parse(BufferedReader(StringReader(text)))
        null
    } catch (e: BadConfigException) {
        "${e.section.name.lowercase()}: ${e.reason.name.lowercase().replace('_', ' ')}"
    } catch (e: Exception) {
        e.message ?: "unreadable"
    }

    private fun connect(call: MethodCall, result: MethodChannel.Result) {
        // Android asks the user once to allow OpenIPTV to set up a VPN.
        if (!allowed(call, result)) return
        val text = call.argument<String>("config") ?: ""
        val route = call.argument<String>("route") ?: "app"
        work(result) {
            // One VPN at a time: stop OpenVPN first.
            if (OpenVpnService.state != "off") {
                OpenVpnNative.stop()
                Thread.sleep(500)
            }
            val config = Config.parse(BufferedReader(StringReader(routed(text, route))))
            // Up again with new settings: take it down first.
            if (backend.getState(tunnel) == Tunnel.State.UP) {
                backend.setState(tunnel, Tunnel.State.DOWN, null)
            }
            backend.setState(tunnel, Tunnel.State.UP, config)
            "ok"
        }
    }

    /** From MainActivity.onActivityResult. */
    fun onPermissionResult(granted: Boolean) {
        val (call, result) = pending ?: return
        pending = null
        when {
            !granted -> result.success("denied")
            call.method == "ovpnConnect" -> ovpnConnect(call, result)
            else -> connect(call, result)
        }
    }

    private fun status(): Map<String, Any?> {
        val up = backend.getState(tunnel) == Tunnel.State.UP
        if (!up) return mapOf("up" to false)
        val stats = backend.getStatistics(tunnel)
        val handshake = stats.peers()
            .map { stats.peer(it)?.latestHandshakeEpochMillis() ?: 0L }
            .maxOrNull() ?: 0L
        return mapOf(
            "up" to true,
            "rx" to stats.totalRx(),
            "tx" to stats.totalTx(),
            "handshake" to handshake,
        )
    }

    /**
     * The profile with OpenIPTV's routing choice applied: any
     * Included/ExcludedApplications in the file are replaced.
     */
    private fun routed(text: String, route: String): String {
        val out = StringBuilder()
        var inInterface = false
        for (line in text.lines()) {
            val trimmed = line.trim()
            if (trimmed.startsWith("[")) {
                inInterface = trimmed.equals("[Interface]", ignoreCase = true)
                out.appendLine(line)
                if (inInterface && route == "app") {
                    out.appendLine("IncludedApplications = ${activity.packageName}")
                }
                continue
            }
            val key = trimmed.substringBefore('=').trim().lowercase()
            if (inInterface &&
                (key == "includedapplications" || key == "excludedapplications")
            ) continue
            out.appendLine(line)
        }
        return out.toString()
    }

    private fun work(result: MethodChannel.Result, block: () -> Any?) {
        worker.execute {
            val value = try {
                block()
            } catch (e: BadConfigException) {
                "bad_config"
            } catch (e: Exception) {
                android.util.Log.e("OTV-vpn", "vpn: ${e.javaClass.simpleName}")
                "error"
            }
            main.post { result.success(value) }
        }
    }
}
