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
  /// Phase 0: no-op stub. Web: no-op.
  Future<void> openKeyboardSettings() async {
    if (!_isSupported) return;
    try {
      await _channel.invokeMethod('openKeyboardSettings');
    } on MissingPluginException {
      // Phase 0: chưa có native side — no-op.
    } on PlatformException {
      // Im lặng: banner CTA là best-effort, không phá UX.
    }
  }
}
