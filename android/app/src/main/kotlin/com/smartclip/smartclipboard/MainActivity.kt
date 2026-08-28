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
import io.flutter.plugin.common.PluginRegistry

/**
 * MainActivity — handles MethodChannel for:
 * 1. Keyboard IME integration
 * 2. FIX 3.2: SAF File Picker for Restore
 * 3. FIX 3.2: Share Sheet for Export
 *
 * FIX 1.1: Kế thừa FlutterFragmentActivity thay vì FlutterActivity
 * để local_auth (biometric) plugin hoạt động đúng.
 */
class MainActivity : FlutterFragmentActivity(), PluginRegistry.ActivityResultListener {

    companion object {
        private const val CHANNEL = "smart_clipboard/native_bridge"
        private const val IME_PACKAGE = "com.smartclip.smartclipboard"
        private const val REQUEST_CODE_PICK_FILE = 1001
    }

    private var filePickerResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Register for activity results
        addActivityResultListener(this)

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
                    // FIX 3.2: Mở SAF File Picker để chọn file .scbak
                    "pickBackupFile" -> {
                        pickBackupFile(result)
                    }
                    // FIX 3.2: Mở Share Sheet để export file
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
    // FIX 3.2: SAF File Picker
    // ===========================================================================

    private fun pickBackupFile(result: MethodChannel.Result) {
        filePickerResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*" // Chọn bất kỳ file nào (SAF không filter theo extension tốt)
            // Có thể thêm MIME type nếu cần: type = "application/octet-stream"
        }
        startActivityForResult(intent, REQUEST_CODE_PICK_FILE)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == REQUEST_CODE_PICK_FILE) {
            if (resultCode == Activity.RESULT_OK && data?.data != null) {
                // Lấy đường dẫn thực tế từ content URI
                val uri = data.data!!
                // Chuyển content:// URI thành đường dẫn file thực
                val path = getPathFromUri(uri)
                filePickerResult?.success(path)
            } else {
                // User hủy chọn file
                filePickerResult?.success(null)
            }
            filePickerResult = null
        }
    }

    private fun getPathFromUri(uri: android.net.Uri): String {
        // Với SAF, uri là content:// URI. Cần copy file ra cache để đọc.
        // Trả về URI string để Dart side xử lý.
        return uri.toString()
    }

    // ===========================================================================
    // FIX 3.2: Share Sheet for Export
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
