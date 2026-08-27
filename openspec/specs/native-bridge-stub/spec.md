# Native Bridge Stub (Phase 0) Specification

## Purpose

Định nghĩa interface Dart-side của MethodChannel `smart_clipboard/native_bridge` mà Phase 1 (Kotlin IME) sẽ implement. Phase 0 chỉ có stub an toàn: không bao giờ crash dù native side không tồn tại. TUYỆT ĐỐI không có code Kotlin trong scope này.

## Requirements

### Requirement: isKeyboardEnabled fallback false

`isKeyboardEnabled()` (file: `lib/core/native_bridge/native_bridge.dart`) invoke method cùng tên; bắt `MissingPluginException` (native chưa có) và `PlatformException` → đều trả về `false`.

#### Scenario: Chạy trên build không có Kotlin handler
- **WHEN** UI gọi `keyboardEnabledProvider`
- **THEN** FutureProvider resolve false → banner "Bật bàn phím..." trên Home hiển thị (vì coi như chưa enabled).

### Requirement: openKeyboardSettings no-op im lặng

Invoke 'openKeyboardSettings'; MissingPluginException/PlatformException đều bị nuốt im lặng — banner CTA là best-effort.

#### Scenario: Phase 0 bấm CTA bật keyboard
- **WHEN** user bấm banner/nút Enable Keyboard
- **THEN** không có gì xảy ra về mặt hệ thống, không exception lộ ra UI.

### Requirement: Provider đọc trạng thái một lần mỗi session

`keyboardEnabledProvider` là FutureProvider — resolve một lần rồi cache; không poll. Banner Home chỉ hiện khi value = false VÀ user chưa dismiss (local state `_keyboardBannerDismissed`, mất khi restart app).

#### Scenario: Dismiss banner rồi rebuild Home
- **GIVEN** user đã bấm X trên banner
- **WHEN** switch tab đi rồi quay lại
- **THEN** banner vẫn ẩn trong session; mở lại app thì banner hiện trở lại.
