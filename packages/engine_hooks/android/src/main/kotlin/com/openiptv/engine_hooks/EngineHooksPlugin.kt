package com.openiptv.engine_hooks

import io.flutter.embedding.engine.plugins.FlutterPlugin

/**
 * Registered on every Flutter engine (Flutter auto-registers plugins), so
 * the app can attach its own native channels to engines it didn't create —
 * notably the headless engine audio_service starts when Android Auto binds
 * the media service while the app isn't open. The app sets [onAttach] in
 * Application.onCreate, which always runs before any engine exists.
 */
class EngineHooksPlugin : FlutterPlugin {
    companion object {
        @JvmStatic
        var onAttach: ((FlutterPlugin.FlutterPluginBinding) -> Unit)? = null

        @JvmStatic
        var onDetach: ((FlutterPlugin.FlutterPluginBinding) -> Unit)? = null
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        onAttach?.invoke(binding)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        onDetach?.invoke(binding)
    }
}
