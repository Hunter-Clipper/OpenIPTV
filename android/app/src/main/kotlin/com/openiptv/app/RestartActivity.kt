package com.openiptv.app

import android.app.Activity
import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.Process

/**
 * Restarts the app (#157: the graphics mode is read once, when the first
 * Flutter engine starts). The app can't relaunch itself and then kill its
 * own process — the new screen would open inside the process that is about
 * to die and be removed with it. So this runs in its own short-lived
 * process (`:restart`): it waits until the app's main process is gone, then
 * launches the app and ends itself.
 */
class RestartActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val handler = Handler(Looper.getMainLooper())
        val deadline = System.currentTimeMillis() + 4_000
        fun relaunch() {
            packageManager.getLaunchIntentForPackage(packageName)?.let {
                it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
                startActivity(it)
            }
            finish()
            // This helper process has done its job.
            handler.postDelayed({ Process.killProcess(Process.myPid()) }, 500)
        }
        fun check() {
            if (!mainProcessAlive(this) || System.currentTimeMillis() > deadline) relaunch()
            else handler.postDelayed({ check() }, 100)
        }
        check()
    }

    private fun mainProcessAlive(context: Context): Boolean {
        val am = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        return am.runningAppProcesses?.any { it.processName == context.packageName } == true
    }

    companion object {
        /** Ends the app's process and opens it again. */
        fun restart(context: Context) {
            context.startActivity(
                Intent(context, RestartActivity::class.java)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_ANIMATION),
            )
            Handler(Looper.getMainLooper()).postDelayed(
                { Process.killProcess(Process.myPid()) }, 300,
            )
        }

        /** True inside the helper process: it must not start Flutter. */
        fun isHelperProcess(): Boolean = try {
            // The process name, on every Android version.
            java.io.File("/proc/self/cmdline").readText().trim('\u0000').endsWith(":restart")
        } catch (e: Exception) { false }
    }
}
