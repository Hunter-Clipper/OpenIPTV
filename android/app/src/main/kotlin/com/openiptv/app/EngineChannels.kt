package com.openiptv.app

import android.app.Application
import android.app.UiModeManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
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
                else -> result.notImplemented()
            }
        }
        players[messenger] = NativeVideoPlayerManager(
            context,
            messenger,
            binding.textureRegistry,
        ) { anyPlaying -> onAnyPlayingChanged?.invoke(anyPlaying) }
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
