package com.smartclip.smartclipboard

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.provider.Settings
import android.view.inputmethod.InputMethodManager
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * MainActivity — handles MethodChannel for:
 * 1. Keyboard IME integration
 * 2. SAF File Picker for Restore
 * 3. Share Sheet for Export
 *
 * FIX 1.1: Kế thừa FlutterFragmentActivity thay vì FlutterActivity
 * để local_auth (biometric) plugin hoạt động đúng.
 */
class MainActivity : FlutterFragmentActivity() {

    companion object {
        private const val CHANNEL = "smart_clipboard/native_bridge"
        private const val IME_PACKAGE = "com.smartclip.smartclipboard"
    }

    private var filePickerResult: MethodChannel.Result? = null

    // FIX: Use ActivityResultLauncher instead of onActivityResult
    private lateinit var filePickerLauncher: ActivityResultLauncher<Intent>

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)

        // Register activity result launcher BEFORE configureFlutterEngine
        filePickerLauncher = registerForActivityResult(
            ActivityResultContracts.StartActivityForResult()
        ) { result ->
            if (result.resultCode == Activity.RESULT_OK) {
                val uri = result.data?.data
                if (uri != null) {
                    filePickerResult?.success(uri.toString())
                } else {
                    filePickerResult?.success(null)
                }
            } else {
                // User cancelled
                filePickerResult?.success(null)
            }
            filePickerResult = null
        }
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
                    "isKeyboardActive" -> {
                        result.success(isSmartClipboardKeyboardActive())
                    }
                    "showKeyboardPicker" -> {
                        showInputMethodPicker()
                        result.success(null)
                    }
                    // SAF File Picker for Restore
                    "pickBackupFile" -> {
                        pickBackupFile(result)
                    }
                    // Share Sheet for Export
                    "shareFile" -> {
                        val path = call.arguments as? String
                        if (path != null) {
                            shareFile(path)
                            result.success(null)
                        } else {
                            result.error("INVALID_ARGS", "Path is required", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // ===========================================================================
    // SAF File Picker
    // ===========================================================================

    private fun pickBackupFile(result: MethodChannel.Result) {
        filePickerResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
        }
        filePickerLauncher.launch(intent)
    }

    // ===========================================================================
    // Share Sheet for Export
    // ===========================================================================

    private fun shareFile(filePath: String) {
        try {
            val file = java.io.File(filePath)
            if (!file.exists()) return

            val uri = androidx.core.content.FileProvider.getUriForFile(
                this,
                "${packageName}.fileprovider",
                file
            )

            val intent = Intent(Intent.ACTION_SEND).apply {
                type = "application/octet-stream"
                putExtra(Intent.EXTRA_STREAM, uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(Intent.createChooser(intent, "Share backup file"))
        } catch (_: Exception) {
            // Best-effort
        }
    }

    /**
     * Check if SmartClipboard IME is enabled in system settings.
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
     * Check if SmartClipboard IME is the CURRENTLY SELECTED input method
     * (không chỉ enabled). So sánh DEFAULT_INPUT_METHOD với package name.
     */
    private fun isSmartClipboardKeyboardActive(): Boolean {
        return try {
            val current = Settings.Secure.getString(
                contentResolver,
                Settings.Secure.DEFAULT_INPUT_METHOD
            )
            current?.startsWith(IME_PACKAGE) == true
        } catch (_: Exception) {
            false
        }
    }

    /**
     * Mở system IME picker để user chủ động chuyển sang Smart Clipboard.
     * KHÔNG tự set default bằng reflection — luôn để user chọn.
     */
    private fun showInputMethodPicker() {
        try {
            val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
            imm.showInputMethodPicker()
        } catch (_: Exception) {
            // Best-effort
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
            // Best-effort
        }
    }
}
