package com.openiptv.app

import android.app.PictureInPictureParams
import android.app.UiModeManager
import android.content.Context
import android.content.res.Configuration
import android.os.Build
import android.util.Log
import android.util.Rational
import android.view.WindowManager
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Extends AudioServiceActivity (not FlutterActivity) so the Flutter engine is
// shared with the background audio_service, keeping the Now Playing
// notification in sync with the same media_kit Player instance.
class MainActivity : AudioServiceActivity() {
    private var pipChannel: MethodChannel? = null
    private var deviceChannel: MethodChannel? = null
    private var backChannel: MethodChannel? = null
    private var videoPlayerManager: NativeVideoPlayerManager? = null

    // Updated proactively by Dart via pip_service.dart's updatePipAvailability()
    // whenever "PiP enabled AND actively playing" changes. Read synchronously
    // in onUserLeaveHint() — there's no time for a Dart round-trip at that
    // point, since the activity is paused immediately afterward.
    @Volatile
    private var pipAvailable = false

    // Updated proactively by Dart (app.dart's _ShellState) whenever it's
    // sitting on a root tab with nothing of its own left to pop — Flutter's
    // PopScope/OnBackInvokedCallback plumbing was empirically unreliable
    // here (a PopScope with canPop:false, wrapping the ShellRoute's content,
    // never actually stopped the system from closing the Activity — verified
    // by hard-coding canPop:false and watching the app still exit). Handling
    // Back directly at the Activity level sidesteps that entirely: read
    // synchronously here, so there's no round-trip race with the physical
    // key press.
    @Volatile
    private var backBlocked = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pipChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "openiptv/pip")
        pipChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "setPipAvailable" -> {
                    pipAvailable = call.arguments as? Boolean ?: false
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        deviceChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "openiptv/device")
        deviceChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "isTelevision" -> {
                    val uiModeManager = getSystemService(Context.UI_MODE_SERVICE) as UiModeManager
                    result.success(uiModeManager.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION)
                }
                else -> result.notImplemented()
            }
        }

        backChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "openiptv/back")
        backChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "setBlocked" -> {
                    backBlocked = call.arguments as? Boolean ?: false
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        videoPlayerManager = NativeVideoPlayerManager(
            applicationContext,
            flutterEngine.dartExecutor.binaryMessenger,
            flutterEngine.renderer,
        ) { anyPlaying -> setKeepScreenOn(anyPlaying) }
    }

    // Issue #28: the system's normal screen-timeout/screensaver rules apply
    // during playback because nothing was telling Android the device is in
    // active use. FLAG_KEEP_SCREEN_ON is the standard fix for this (what
    // ExoPlayer's own PlayerView does internally) — unlike a PowerManager
    // WakeLock it needs no permission and is scoped to this Window, so it's
    // released automatically if the Activity is destroyed while playing.
    private fun setKeepScreenOn(keepOn: Boolean) {
        runOnUiThread {
            if (keepOn) {
                window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            } else {
                window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            }
        }
    }

    @Suppress("DEPRECATION", "MissingSuperCall")
    override fun onBackPressed() {
        if (backBlocked) {
            backChannel?.invokeMethod("backPressed", null)
        } else {
            super.onBackPressed()
        }
    }

    // Fired when the user presses Home (or otherwise leaves the activity)
    // while it's in the foreground.
    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && pipAvailable) {
            val params = PictureInPictureParams.Builder()
                .setAspectRatio(Rational(16, 9))
                .build()
            val entered = enterPictureInPictureMode(params)
            Log.d("OTV-pip", "enterPictureInPictureMode returned=$entered")
        }
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        pipChannel?.invokeMethod("onPipModeChanged", isInPictureInPictureMode)
    }
}
