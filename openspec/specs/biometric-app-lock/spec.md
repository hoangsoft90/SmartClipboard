# Biometric App Lock Specification

## Purpose

Khoá toàn bộ app bằng sinh trắc học (vân tay/khuôn mặt) qua package `local_auth`. Tính năng miễn phí bản Free. Thiết bị/platform không hỗ trợ phải degrade an toàn (không crash).

## Requirements

### Requirement: Bật lock chỉ khi thiết bị hỗ trợ

Switch "Khoá app bằng sinh trắc học" trong Settings: khi bật, kiểm tra `AuthService.canAuthenticate()` (`isDeviceSupported` + `canCheckBiometrics`, mọi exception → false) TRƯỚC; không hỗ trợ → snackbar lỗi, KHÔNG bật setting.

#### Scenario: Máy không có vân tay
- **GIVEN** emulator không enroll biometric
- **WHEN** bật Switch
- **THEN** snackbar "Thiết bị không hỗ trợ sinh trắc học..."; setting giữ false.

#### Scenario: Bật thành công
- **GIVEN** máy hỗ trợ biometric
- **WHEN** bật Switch
- **THEN** `app_meta('biometric_lock')` = '1'; từ lần mở app kế tiếp RootGate render LockGate thay vì HomeScreen.

### Requirement: Gate chặn UI tới khi xác thực thành công

`LockGate` (file: `lib/widgets/lock_gate.dart`) render màn hình khoá với icon + nút "Mở khoá"; tự động attempt xác thực một lần ngay khi mount (postFrameCallback). Chỉ khi `authenticate()` trả true thì child (HomeScreen) mới được render.

#### Scenario: Mở app khi lock bật
- **GIVEN** biometric_lock = true
- **WHEN** app start
- **THEN** hộp thoại biometric hệ thống hiện ra ("Xác thực để mở Smart Clipboard"); success → vào HomeScreen; fail/cancel → màn hình khoá với nút thử lại thủ công (KHÔNG retry vô hạn).

#### Scenario: authenticate throw exception nền tảng
- **GIVEN** biometric service lỗi hệ thống
- **WHEN** authenticate()
- **THEN** catch trả false — app vẫn ở màn khoá, không crash.

### Requirement: Authenticate cấu hình biometricOnly

`authenticate()` dùng `AuthenticationOptions(biometricOnly: true, stickyAuth: true)` — không cho fallback PIN/pattern hệ thống, sticky để không mất dialog khi app background ngắn.

## Cần làm rõ

- Lock CHỈ áp dụng lúc build LockGate (tức lúc khởi động app / rebuild RootGate). Khi user bấm Home rồi quay lại trong cùng session, app KHÔNG tự khoá lại (không có lifecycle listener resume→lock). Đây là hành vi chấp nhận hay cần auto-lock on resume?
- unlocked state là local state của `_LockGateState`: nếu widget tree rebuild sâu khiến LockGate remount, user có thể phải xác thực lại giữa chừng session. Chưa rõ ý định.
