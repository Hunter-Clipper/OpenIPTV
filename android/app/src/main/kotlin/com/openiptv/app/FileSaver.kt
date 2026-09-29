package com.openiptv.app

import android.app.Activity
import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Saves a file into the device's public Downloads folder — used by backup
 * export. The share sheet alone isn't enough: Fire TV and many Android TV
 * devices have no share targets at all, so a backup couldn't be exported.
 */
class FileSaver(private val activity: Activity) : MethodChannel.MethodCallHandler {

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "saveToDownloads" -> {
                val name = call.argument<String>("name")
                val bytes = call.argument<ByteArray>("bytes")
                val mime = call.argument<String>("mimeType") ?: "application/octet-stream"
                if (name == null || bytes == null) {
                    result.error("bad_args", "name and bytes are required", null)
                    return
                }
                try {
                    result.success(save(name, bytes, mime))
                } catch (e: Exception) {
                    result.error("save_failed", e.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }

    // Returns a human-readable location for the confirmation message.
    private fun save(name: String, bytes: ByteArray, mime: String): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // MediaStore needs no storage permission on Android 10+.
            val resolver = activity.contentResolver
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, name)
                put(MediaStore.Downloads.MIME_TYPE, mime)
                put(MediaStore.Downloads.IS_PENDING, 1)
            }
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException("MediaStore insert failed")
            resolver.openOutputStream(uri)?.use { it.write(bytes) }
                ?: throw IllegalStateException("Couldn't open output stream")
            values.clear()
            values.put(MediaStore.Downloads.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
        } else {
            // Android 9 and below (e.g. Fire OS 7): WRITE_EXTERNAL_STORAGE,
            // requested from Dart before calling this.
            @Suppress("DEPRECATION")
            val dir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            dir.mkdirs()
            File(dir, name).writeBytes(bytes)
        }
        return "Downloads/$name"
    }
}
