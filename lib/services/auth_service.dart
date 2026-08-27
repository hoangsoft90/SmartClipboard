import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:local_auth/local_auth.dart';

/// Biometric App Lock — P0 Free (mục 8). Dùng `local_auth` trong whitelist.
///
/// Lưu ý Android: MainActivity phải kế thừa `FlutterFragmentActivity` và
/// manifest khai báo permission USE_BIOMETRIC (xem README bước flutter create).
class AuthService {
  final LocalAuthentication _auth = LocalAuthentication();

  /// Platform guard: biometric chỉ khả dụng trên mobile.
  bool get _isSupported => !kIsWeb;

  Future<bool> get canAuthenticate async {
    if (!_isSupported) return false;
    try {
      if (!await _auth.isDeviceSupported()) return false;
      return await _auth.canCheckBiometrics ||
          await _auth.isDeviceSupported();
    } catch (_) {
      // Không crash khi thiết bị/platform không hỗ trợ — app vẫn dùng được.
      return false;
    }
  }

  Future<bool> authenticate() async {
    if (!_isSupported) return false;
    try {
      return await _auth.authenticate(
        localizedReason: 'Xác thực để mở Smart Clipboard',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
