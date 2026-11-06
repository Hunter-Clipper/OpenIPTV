package com.openiptv.app

import android.app.Application
import android.content.Context
import android.os.Build
import android.util.Log
import io.flutter.FlutterInjector

/**
 * Chooses how Flutter draws the app and the video texture (#157).
 *
 * Measured on a Mi TV with an Amlogic S7D (Mali-G310): Flutter's default
 * Impeller/Vulkan path put torn frames on screen (the top of the picture
 * from one video frame, the rest from the previous one) in about 1.7% of
 * screenshots (7 of 400); the older Skia path showed none (0 of 599). The
 * Chromecast with Google TV (Amlogic S905D3) showed none on either (0 of
 * 450). So this is a per-device choice, made here — before the first Flutter
 * engine exists, because the engine reads these flags once, at its first
 * initialisation (a change applies on the next start).
 *
 * TVs only — [apply] does nothing on phones and tablets.
 *
 * Setting (Power User Tools → Graphics mode):
 *  - `auto`     — compatibility only on chips where tearing was measured;
 *  - `standard` — Flutter's default (Impeller);
 *  - `compat`   — the Skia path.
 */
object GraphicsMode {
    private const val TAG = "OTV-gfx"
    private const val PREFS = "openiptv_native"
    private const val KEY = "graphics_mode"

    const val AUTO = "auto"
    const val STANDARD = "standard"
    const val COMPAT = "compat"

    /** What the user picked ([AUTO] until they choose). */
    fun setting(context: Context): String {
        val v = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, AUTO)
        return if (v == STANDARD || v == COMPAT) v else AUTO
    }

    fun setSetting(context: Context, value: String) {
        val v = if (value == STANDARD || value == COMPAT) value else AUTO
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(KEY, v).apply()
    }

    /**
     * Chips where the default path was measured to tear. Only add a chip
     * here with measurements (see the class comment) — not by guesswork.
     */
    internal fun isKnownTearingChip(socModel: String?, boardPlatform: String?): Boolean =
        socModel.equals("AMLS905X5M", ignoreCase = true) ||
            boardPlatform.equals("s7d", ignoreCase = true)

    /** The mode that will actually be used for [setting] on this chip. */
    internal fun resolve(setting: String, socModel: String?, boardPlatform: String?): String =
        when (setting) {
            STANDARD -> STANDARD
            COMPAT -> COMPAT
            else -> if (isKnownTearingChip(socModel, boardPlatform)) COMPAT else STANDARD
        }

    fun socModel(): String? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) Build.SOC_MODEL else null

    /** `ro.board.platform` (e.g. "s7d"), the chip family name on most TVs. */
    fun boardPlatform(): String? = try {
        Class.forName("android.os.SystemProperties")
            .getMethod("get", String::class.java)
            .invoke(null, "ro.board.platform") as? String
    } catch (e: Exception) { null }

    /** The mode in use, as decided at start-up. */
    @Volatile var active: String = STANDARD
        private set

    fun apply(app: Application) {
        // TVs only: phones and tablets always keep Flutter's default, whatever
        // was stored.
        if (!EngineChannels.isTelevision(app)) return
        active = resolve(setting(app), socModel(), boardPlatform())
        if (active != COMPAT) return
        Log.i(TAG, "graphics mode: compatibility (setting=${setting(app)} soc=${socModel()} board=${boardPlatform()})")
        // Starts Flutter's own initialisation early with the flag; the
        // engine's later calls reuse this result.
        val loader = FlutterInjector.instance().flutterLoader()
        loader.startInitialization(app)
        loader.ensureInitializationComplete(app, arrayOf("--enable-impeller=false"))
    }

    /** For the settings screen and bug reports. */
    fun info(context: Context): Map<String, Any?> = mapOf(
        "setting" to setting(context),
        "active" to active,
        "autoWouldUse" to resolve(AUTO, socModel(), boardPlatform()),
        "socModel" to socModel(),
        "boardPlatform" to boardPlatform(),
    )
}
