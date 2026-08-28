import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

/// Native Bridge — MethodChannel Dart-side.
///
/// ⚠️ PHASE 0 SCOPE: chỉ ĐỊNH NGHĨA INTERFACE Dart-side với stub trả về
/// false/no-op. PHẦN KOTLIN NATIVE (InputMethodManager check, Settings Intent)
/// thuộc PHASE 1 (Native IME prototype) — KHÔNG được viết code Kotlin nào ở
/// Phase 0 (giới hạn phạm vi prompt.md).
///
/// Khi Phase 1 triển khai, Kotlin side sẽ:
/// - `isKeyboardEnabled()`: InputMethodManager.getEnabledInputMethodList()
///   kiểm tra package name của IME này.
/// - `openKeyboardSettings()`: mở Intent ACTION_INPUT_METHOD_SETTINGS.
///
/// Web: Native bridge không khả dụng — trả false/no-op cho mọi trường hợp.
class NativeBridge {
  static const MethodChannel _channel =
      MethodChannel('smart_clipboard/native_bridge');

  /// Platform guard: native bridge chỉ khả dụng trên mobile.
  bool get _isSupported => !kIsWeb;

  /// Keyboard Smart Clipboard đã được enable trong System Settings chưa?
  /// Phase 0: stub luôn trả về false (MissingPluginException an toàn).
  /// Web: luôn trả false — keyboard system không áp dụng.
  Future<bool> isKeyboardEnabled() async {
    if (!_isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('isKeyboardEnabled') ?? false;
    } on MissingPluginException {
      return false; // native side chưa tồn tại (Phase 0)
    } on PlatformException {
      return false; // fallback an toàn — không bao giờ crash vì banner
    }
  }

  /// Mở trang cài đặt bàn phím hệ thống Android.
  Future<void> openKeyboardSettings() async {
    if (!_isSupported) return;
    try {
      await _channel.invokeMethod('openKeyboardSettings');
    } on MissingPluginException {
      // No-op nếu native side chưa tồn tại.
    } on PlatformException {
      // Best-effort.
    }
  }

  // ===========================================================================
  // FIX 3.2: SAF File Picker for Restore
  // ===========================================================================

  /// Mở SAF File Picker để user chọn file .scbak.
  /// Trả về đường dẫn file đã chọn, hoặc null nếu user hủy.
  Future<String?> pickBackupFile() async {
    if (!_isSupported) return null;
    try {
      return await _channel.invokeMethod<String>('pickBackupFile');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  // ===========================================================================
  // FIX 3.2: Share Sheet for Export
  // ===========================================================================

  /// Mở Android Share Sheet để user chia sẻ file backup.
  Future<void> shareFile(String filePath) async {
    if (!_isSupported) return;
    try {
      await _channel.invokeMethod('shareFile', filePath);
    } on MissingPluginException {
      // No-op.
    } on PlatformException {
      // Best-effort.
    }
  }
}
