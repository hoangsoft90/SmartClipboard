package com.smartclip.smartclipboard

import android.content.Context
import android.content.Intent
import android.provider.Settings
import android.view.inputmethod.InputMethodManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * MainActivity — Phase 1: handles MethodChannel for keyboard IME integration.
 *
 * FIX 1.1: Kế thừa FlutterFragmentActivity thay vì FlutterActivity
 * để local_auth (biometric) plugin hoạt động đúng.
 * FlutterActivity không hỗ trợ Fragment lifecycle cần thiết cho
 * biometric prompt.
 *
 * STRICT RULE 6: Flutter App process và Android IME process là hai tiến trình
 * OS độc lập, KHÔNG chia sẻ bộ nhớ. Sync chỉ qua file cache.
 */
class MainActivity : FlutterFragmentActivity() {

    companion object {
        private const val CHANNEL = "smart_clipboard/native_bridge"
        private const val IME_PACKAGE = "com.smartclip.smartclipboard"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isKeyboardEnabled" -> {
                        result.success(isSmartClipboardKeyboardEnabled())
                    }
                    "openKeyboardSettings" -> {
                        openInputMethodSettings()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Check if SmartClipboard IME is enabled in system settings.
     * Uses InputMethodManager.getEnabledInputMethodList() to check
     * if our package is in the enabled list.
     */
    private fun isSmartClipboardKeyboardEnabled(): Boolean {
        return try {
            val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
            val enabledImes = imm.enabledInputMethodList
            enabledImes.any { it.packageName == IME_PACKAGE }
        } catch (_: Exception) {
            false
        }
    }

    /**
     * Open Android Input Method Settings so user can enable SmartClipboard IME.
     */
    private fun openInputMethodSettings() {
        try {
            val intent = Intent(Settings.ACTION_INPUT_METHOD_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
        } catch (_: Exception) {
            // Best-effort — silently fail
        }
    }
}
