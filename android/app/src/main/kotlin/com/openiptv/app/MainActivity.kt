package com.openiptv.open_iptv

import android.app.PictureInPictureParams
import android.content.res.Configuration
import android.os.Build
import android.util.Log
import android.util.Rational
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Extends AudioServiceActivity (not FlutterActivity) so the Flutter engine is
// shared with the background audio_service, keeping the Now Playing
// notification in sync with the same media_kit Player instance.
class MainActivity : AudioServiceActivity() {
    private var pipChannel: MethodChannel? = null

    // Updated proactively by Dart via pip_service.dart's updatePipAvailability()
    // whenever "PiP enabled AND actively playing" changes. Read synchronously
    // in onUserLeaveHint() — there's no time for a Dart round-trip at that
    // point, since the activity is paused immediately afterward.
    @Volatile
    private var pipAvailable = false

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
