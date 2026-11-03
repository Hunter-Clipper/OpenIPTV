package com.openiptv.app

import android.content.Context
import android.os.Build
import java.io.File

/**
 * Native half of the optional anonymous crash reports (#150). Read
 * docs/design/anonymous-stats.md for the promise this keeps.
 *
 * When the app dies from an uncaught native exception AND the user turned
 * reports on (the Dart side stores the choice as "flutter.stats_choice" in
 * SharedPreferences), the exception's class name and stack frames are saved to
 * a private file. Nothing leaves the device from here: on the next launch the
 * Dart code reads the file, scrubs it (scrubber.dart) and queues it.
 *
 * The exception MESSAGE is never written, only the class name and the frames.
 */
object NativeCrashReporter {
    private const val PREFS = "FlutterSharedPreferences"
    private const val CHOICE_KEY = "flutter.stats_choice"
    private const val FILE = "telemetry/native_crash.txt"

    fun install(context: Context) {
        val app = context.applicationContext
        val previous = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, error ->
            try {
                save(app, error)
            } catch (_: Throwable) {
                // Reporting must never get in the way of the normal crash.
            }
            previous?.uncaughtException(thread, error)
        }
    }

    private fun save(context: Context, error: Throwable) {
        val choice = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(CHOICE_KEY, null)
        if (choice != "on") return
        val file = File(context.filesDir, FILE)
        file.parentFile?.mkdirs()
        // First line: class name. Then up to 60 frames, no message.
        val lines = listOf(error.javaClass.name) +
            error.stackTrace.take(60).map { "at $it" }
        file.writeText(lines.joinToString("\n"))
    }

    /** Returns the saved crash (type + stack) and deletes it, or null. */
    fun take(context: Context): Map<String, String>? {
        val file = File(context.filesDir, FILE)
        if (!file.exists()) return null
        return try {
            val text = file.readText()
            val type = text.substringBefore('\n')
            val stack = text.substringAfter('\n', "")
            mapOf("type" to type, "stack" to stack)
        } catch (_: Throwable) {
            null
        } finally {
            file.delete()
        }
    }

    /** Device facts for a report: maker, model, Android API level. No IDs. */
    fun deviceFacts(): Map<String, Any> = mapOf(
        "manufacturer" to Build.MANUFACTURER,
        "model" to Build.MODEL,
        "sdk" to Build.VERSION.SDK_INT,
    )
}
