package com.openiptv.app

import android.content.Intent
import android.net.IpPrefix
import android.net.VpnService
import android.os.Build
import org.json.JSONObject
import java.net.InetAddress

/** JNI entry points of libopeniptv_ovpn.so (src/main/cpp/openvpn_jni.cpp). */
object OpenVpnNative {
    init {
        System.loadLibrary("openiptv_ovpn")
    }

    /** "" = usable, "needs_login" = asks for a username/password, else why not. */
    @JvmStatic external fun validate(profile: String): String

    /** Runs a session until it ends; "" on a clean stop, else the error. */
    @JvmStatic external fun run(profile: String, user: String?, pass: String?, callback: Any): String

    @JvmStatic external fun stop()

    /** [bytesIn, bytesOut], or [-1, -1] when not running. */
    @JvmStatic external fun stats(): LongArray
}

/**
 * Built-in OpenVPN (OpenVPN 3 core), Settings → Power User Tools (#41).
 * Android's VPN interface can only be built by a VpnService, so the
 * session runs here; VpnController starts and stops it.
 */
class OpenVpnService : VpnService() {

    /** What VpnController hands over for the next connect. */
    data class Request(
        val profile: String,
        val user: String?,
        val pass: String?,
        val appOnly: Boolean,
    )

    companion object {
        const val ACTION_CONNECT = "com.openiptv.app.ovpn.CONNECT"
        const val ACTION_DISCONNECT = "com.openiptv.app.ovpn.DISCONNECT"

        @Volatile var pending: Request? = null

        /** "off" | "connecting" | "connected" | "error". */
        @Volatile var state: String = "off"
            private set

        /** Plain reason when [state] is "error". */
        @Volatile var lastError: String? = null
            private set

        @Volatile private var worker: Thread? = null
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_CONNECT -> start()
            ACTION_DISCONNECT -> {
                OpenVpnNative.stop()
                if (worker == null) stopSelf()
            }
        }
        return START_NOT_STICKY
    }

    override fun onRevoke() {
        // Another VPN took over, or the user turned it off in Android.
        OpenVpnNative.stop()
        super.onRevoke()
    }

    private fun start() {
        val req = pending ?: return
        pending = null
        // One session at a time: stop any running one first.
        worker?.let {
            OpenVpnNative.stop()
            it.join(5000)
        }
        state = "connecting"
        lastError = null
        worker = Thread({
            val callback = Callback(req.appOnly)
            var result = try {
                OpenVpnNative.run(req.profile, req.user, req.pass, callback)
            } catch (e: Throwable) {
                "native: ${e.javaClass.simpleName}"
            }
            // The core ends some failed attempts "cleanly" (e.g. after
            // CONNECTION_TIMEOUT); the error event says why.
            if (result.isEmpty() && !callback.everConnected) {
                callback.lastErrorEvent?.let { result = it }
            }
            if (result.isEmpty()) {
                state = "off"
            } else {
                state = "error"
                lastError = result
                android.util.Log.w("OTV-ovpn", "session ended: $result")
            }
            worker = null
            stopSelf()
        }, "openvpn").also { it.start() }
    }

    /** Called from the native session thread. */
    inner class Callback(private val appOnly: Boolean) {
        @Volatile var everConnected = false
        @Volatile var lastErrorEvent: String? = null

        @Suppress("unused") // called from JNI
        fun establish(json: String): Int = try {
            val s = JSONObject(json)
            val b = Builder().setSession("OpenIPTV")
            val mtu = s.optInt("mtu", 0)
            if (mtu > 0) b.setMtu(mtu)
            val addresses = s.getJSONArray("addresses")
            for (i in 0 until addresses.length()) {
                val a = addresses.getJSONObject(i)
                b.addAddress(a.getString("a"), a.getInt("p"))
            }
            if (s.optBoolean("reroute4")) b.addRoute("0.0.0.0", 0)
            if (s.optBoolean("reroute6")) b.addRoute("::", 0)
            val routes = s.getJSONArray("routes")
            for (i in 0 until routes.length()) {
                val r = routes.getJSONObject(i)
                val addr = r.getString("a")
                val prefix = r.getInt("p")
                if (!r.optBoolean("x")) {
                    b.addRoute(addr, prefix)
                } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    b.excludeRoute(IpPrefix(InetAddress.getByName(addr), prefix))
                }
            }
            val dns = s.getJSONArray("dns")
            for (i in 0 until dns.length()) b.addDnsServer(dns.getString(i))
            val domains = s.getJSONArray("domains")
            for (i in 0 until domains.length()) b.addSearchDomain(domains.getString(i))
            if (appOnly) b.addAllowedApplication(packageName)
            val pfd = b.establish()
            pfd?.detachFd() ?: -1
        } catch (e: Exception) {
            android.util.Log.e("OTV-ovpn", "establish failed: ${e.javaClass.simpleName}")
            -1
        }

        @Suppress("unused") // called from JNI
        fun protect(fd: Int): Boolean = this@OpenVpnService.protect(fd)

        @Suppress("unused") // called from JNI
        fun onEvent(name: String, info: String, error: Boolean, fatal: Boolean) {
            android.util.Log.i("OTV-ovpn", "event $name${if (error) " (error)" else ""}")
            if (error) lastErrorEvent = name.lowercase()
            when {
                name == "CONNECTED" -> {
                    everConnected = true
                    state = "connected"
                }
                name == "RECONNECTING" || name == "RESOLVE" || name == "WAIT" -> {
                    if (state != "connected") state = "connecting"
                }
                fatal -> {
                    state = "error"
                    lastError = name.lowercase()
                }
            }
        }
    }
}
