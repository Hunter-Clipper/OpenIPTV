package com.openiptv.app

import android.app.Activity
import android.content.pm.PackageManager
import android.hardware.biometrics.BiometricManager
import android.hardware.biometrics.BiometricManager.Authenticators.BIOMETRIC_STRONG
import android.hardware.biometrics.BiometricPrompt
import android.os.Build
import android.os.CancellationSignal
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.KeyProperties
import androidx.annotation.RequiresApi
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey

/**
 * Fingerprint / face unlock for admin PIN prompts (issue #47), on channel
 * `openiptv/biometric`.
 *
 * Only strong (Class 3) biometrics, never the phone's own screen-lock PIN —
 * a child who knows the phone's code must not get past parental controls.
 * Success is tied to a Keystore key that only a biometric can unlock and
 * that Android invalidates when a new fingerprint or face is enrolled, so
 * adding someone's fingerprint later can't silently grant admin access:
 * the next prompt reports "invalidated" and the admin has to turn the
 * feature on again with the PIN.
 *
 * Uses the platform BiometricPrompt (Android 11+), so MainActivity can stay
 * a plain FlutterActivity. Results: success | fallback (cancelled or "Use
 * PIN") | invalidated | not_enabled | unavailable | error.
 */
class AdminBiometric(private val activity: Activity) : MethodChannel.MethodCallHandler {

    private companion object {
        const val ALIAS = "otv_admin_biometric_v1"
        const val TRANSFORMATION = "AES/GCM/NoPadding"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> result.success(isAvailable())
            "enable" -> {
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R || !isAvailable()) {
                    result.success("unavailable")
                    return
                }
                try {
                    createKey()
                } catch (e: Exception) {
                    result.success("error")
                    return
                }
                // Confirm with a real scan; a cancelled setup leaves no key.
                authenticate(call, result, deleteKeyUnlessSuccess = true)
            }
            "authenticate" -> {
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R || !isAvailable()) {
                    result.success("unavailable")
                    return
                }
                authenticate(call, result, deleteKeyUnlessSuccess = false)
            }
            "disable" -> {
                deleteKey()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun isAvailable(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return false
        if (activity.packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK)) {
            return false
        }
        val manager = activity.getSystemService(BiometricManager::class.java) ?: return false
        return manager.canAuthenticate(BIOMETRIC_STRONG) == BiometricManager.BIOMETRIC_SUCCESS
    }

    @RequiresApi(Build.VERSION_CODES.R)
    private fun authenticate(
        call: MethodCall,
        result: MethodChannel.Result,
        deleteKeyUnlessSuccess: Boolean,
    ) {
        var answered = false
        fun answer(value: String) {
            if (answered) return
            answered = true
            if (value != "success" && deleteKeyUnlessSuccess) deleteKey()
            result.success(value)
        }

        val key = try {
            loadKey()
        } catch (e: Exception) {
            null
        }
        if (key == null) {
            answer("not_enabled")
            return
        }
        val cipher = try {
            Cipher.getInstance(TRANSFORMATION).apply { init(Cipher.ENCRYPT_MODE, key) }
        } catch (e: KeyPermanentlyInvalidatedException) {
            // A fingerprint or face was added since the admin turned this on.
            deleteKey()
            answer("invalidated")
            return
        } catch (e: Exception) {
            answer("error")
            return
        }

        val executor = activity.mainExecutor
        val prompt = BiometricPrompt.Builder(activity)
            .setTitle(call.argument<String>("title") ?: "Unlock")
            .apply { call.argument<String>("subtitle")?.let { setSubtitle(it) } }
            .setAllowedAuthenticators(BIOMETRIC_STRONG)
            .setNegativeButton(call.argument<String>("negative") ?: "Use PIN", executor) { _, _ ->
                answer("fallback")
            }
            .setConfirmationRequired(false)
            .build()

        prompt.authenticate(
            BiometricPrompt.CryptoObject(cipher),
            CancellationSignal(),
            executor,
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(r: BiometricPrompt.AuthenticationResult) {
                    // Only a cipher the scan actually unlocked can encrypt.
                    val unlocked = try {
                        r.cryptoObject?.cipher?.doFinal(ByteArray(16)) != null
                    } catch (e: Exception) {
                        false
                    }
                    answer(if (unlocked) "success" else "error")
                }

                // Cancelled, timed out, too many tries: the PIN takes over.
                // (A single non-matching finger only calls onAuthenticationFailed
                // and the prompt stays up for another try.)
                override fun onAuthenticationError(code: Int, message: CharSequence) {
                    answer("fallback")
                }
            },
        )
    }

    @RequiresApi(Build.VERSION_CODES.R)
    private fun createKey() {
        deleteKey()
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        generator.init(
            KeyGenParameterSpec.Builder(
                ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setUserAuthenticationRequired(true)
                .setUserAuthenticationParameters(0, KeyProperties.AUTH_BIOMETRIC_STRONG)
                .setInvalidatedByBiometricEnrollment(true)
                .build(),
        )
        generator.generateKey()
    }

    private fun keyStore(): KeyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }

    private fun loadKey(): SecretKey? = keyStore().getKey(ALIAS, null) as SecretKey?

    private fun deleteKey() {
        try {
            keyStore().deleteEntry(ALIAS)
        } catch (e: Exception) {
            // Nothing to delete.
        }
    }
}
