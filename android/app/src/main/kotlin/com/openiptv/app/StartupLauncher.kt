package com.openiptv.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.provider.Settings
import android.util.Log

/**
 * TV only: open the app when the TV starts and/or wakes from sleep. Android
 * only lets an app start a screen from the background if the user allowed
 * "Display over other apps" for it, so both options need that permission.
 *
 * The choices live here (not only in Dart's preferences) because a boot
 * broadcast arrives before any Flutter code runs.
 */
object StartupLauncher {
    private const val TAG = "OTV-startup"
    private const val PREFS = "otv_startup"
    private var screenReceiver: BroadcastReceiver? = null

    fun set(context: Context, boot: Boolean, wake: Boolean) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putBoolean("boot", boot).putBoolean("wake", wake).apply()
    }

    private fun boot(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean("boot", false)

    private fun wake(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean("wake", false)

    fun canDrawOverlays(context: Context) = Settings.canDrawOverlays(context)

    /** Opens the system screen where the user allows "Display over other apps". */
    fun requestOverlayPermission(context: Context) {
        val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:${context.packageName}"))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try { context.startActivity(intent) } catch (e: Exception) { Log.w(TAG, "no overlay settings screen: $e") }
    }

    private fun launch(context: Context, why: String) {
        if (!canDrawOverlays(context)) {
            Log.w(TAG, "$why: not allowed to open over other apps, skipping")
            return
        }
        Log.i(TAG, "$why: opening the app")
        context.startActivity(
            Intent(context, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP))
    }

    /**
     * The TV's own home screen starts after the boot signal and would take the
     * foreground back, and Android freezes background apps within seconds, so
     * a timer inside the process never fires. Ask the system's alarm service
     * to wake us a little later instead.
     */
    fun onBootCompleted(context: Context) {
        val enabled = boot(context)
        Log.i(TAG, "boot completed: start on boot=$enabled, may open over other apps=${canDrawOverlays(context)}")
        if (!enabled) return
        val alarms = context.getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
        val pending = android.app.PendingIntent.getBroadcast(
            context, 0,
            Intent(context, BootReceiver::class.java).setAction(ACTION_OPEN_AFTER_BOOT),
            android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE)
        alarms.set(android.app.AlarmManager.ELAPSED_REALTIME_WAKEUP,
            android.os.SystemClock.elapsedRealtime() + OPEN_DELAY_MS, pending)
    }

    fun openAfterBoot(context: Context) {
        if (boot(context)) launch(context, "boot")
    }

    const val ACTION_OPEN_AFTER_BOOT = "com.openiptv.app.OPEN_AFTER_BOOT"
    private const val OPEN_DELAY_MS = 12_000L

    /** Listens for the screen turning on while the app's process is alive. */
    fun registerWake(app: android.app.Application) {
        if (screenReceiver != null) return
        val r = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                if (wake(context)) launch(context, "wake")
            }
        }
        screenReceiver = r
        app.registerReceiver(r, IntentFilter(Intent.ACTION_SCREEN_ON))
    }
}

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            "android.intent.action.QUICKBOOT_POWERON" -> StartupLauncher.onBootCompleted(context)
            StartupLauncher.ACTION_OPEN_AFTER_BOOT -> StartupLauncher.openAfterBoot(context)
        }
    }
}
