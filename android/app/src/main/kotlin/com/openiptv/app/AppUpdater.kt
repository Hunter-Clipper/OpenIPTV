package com.openiptv.app

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Native half of the sideload self-updater (see update_service.dart). The app
 * is distributed as a GitHub-hosted APK (Fire TV via Downloader, other
 * sideloaded Android devices), so there's no store to deliver updates — Dart
 * finds and downloads the new APK, and this hands it to the system installer.
 */
class AppUpdater(private val activity: Activity) : MethodChannel.MethodCallHandler {

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            // Which app installed us — "com.android.vending" means Google Play,
            // which manages updates itself, so the in-app updater stays out of it.
            "installerPackage" -> result.success(installerPackage())
            "canInstallPackages" -> result.success(canInstallPackages())
            "openInstallPermissionSettings" -> {
                openInstallPermissionSettings()
                result.success(null)
            }
            "installApk" -> {
                val path = call.argument<String>("path")
                if (path == null) {
                    result.error("bad_args", "path is required", null)
                } else {
                    try {
                        installApk(File(path))
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("install_failed", e.message, null)
                    }
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun installerPackage(): String? = try {
        val pm = activity.packageManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            pm.getInstallSourceInfo(activity.packageName).installingPackageName
        } else {
            @Suppress("DEPRECATION")
            pm.getInstallerPackageName(activity.packageName)
        }
    } catch (_: Exception) {
        null
    }

    // Android 8+ gates installs per app ("Install unknown apps"); before that
    // it was a single global "Unknown sources" setting the user already turned
    // on to sideload us in the first place.
    private fun canInstallPackages(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
            activity.packageManager.canRequestPackageInstalls()

    private fun openInstallPermissionSettings() {
        val perApp = Intent(
            Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
            Uri.parse("package:${activity.packageName}"),
        )
        try {
            activity.startActivity(perApp)
        } catch (_: ActivityNotFoundException) {
            // Some Fire OS / vendor builds lack the per-app screen.
            activity.startActivity(Intent(Settings.ACTION_SECURITY_SETTINGS))
        }
    }

    private fun installApk(apk: File) {
        val uri = FileProvider.getUriForFile(
            activity,
            "${activity.packageName}.updates",
            apk,
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        activity.startActivity(intent)
    }
}
