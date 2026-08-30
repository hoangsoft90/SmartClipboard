# Native Bridge Specification

## Purpose

Định nghĩa interface Dart-side của MethodChannel `smart_clipboard/native_bridge`. Phase 0 chỉ có stub an toàn (trả false/no-op). Phase 1 (Kotlin IME) đã triển khai đầy đủ: `isKeyboardEnabled()`, `isKeyboardActive()`, `openKeyboardSettings()`, `showKeyboardPicker()`, `pickBackupFile()`, `shareFile()`. Web: mọi method đều guard bằng `kIsWeb` → trả false/null/no-op.

## Requirements

### Requirement: isKeyboardEnabled — kiểm tra IME đã được enable

`isKeyboardEnabled()` invoke method cùng tên; bắt `MissingPluginException` và `PlatformException` → đều trả về `false`. Trả về `true` khi SmartClipboard là một trong các IME được Android cho phép.

#### Scenario: Chạy trên build Phase 0 (chưa có Kotlin)
- **WHEN** UI gọi `keyboardEnabledProvider`
- **THEN** FutureProvider resolve false → banner "Bật bàn phím..." trên Home hiển thị.

#### Scenario: Đã enable SmartClipboard trong Settings > Language & Input
- **WHEN** user enable IME trong system settings
- **THEN** `isKeyboardEnabled()` trả về `true`.

### Requirement: openKeyboardSettings mở system settings

Invoke 'openKeyboardSettings'; mở Intent ACTION_INPUT_METHOD_SETTINGS. MissingPluginException/PlatformException đều bị nuốt im lặng.

#### Scenario: Bấm CTA bật keyboard
- **WHEN** user bấm banner/nút Enable Keyboard
- **THEN** system settings IME screen mở ra, user có thể enable SmartClipboard.

### Requirement: isKeyboardActive — kiểm tra IME đang active

`isKeyboardActive()` invoke method cùng tên; trả về `true` khi SmartClipboard là input method HIỆN TẠI đang được dùng để nhập liệu.

#### Scenario: SmartClipboard là keyboard hiện tại
- **WHEN** user đang dùng SmartClipboard để nhập text
- **THEN** `isKeyboardActive()` trả về `true`; banner trên Home ẩn (KeyboardActivationState.active).

### Requirement: showKeyboardPicker — mở system IME picker

`showKeyboardPicker()` mở dialog "Choose input method" của Android để user chuyển sang SmartClipboard trong 1 bước, không cần vào Settings.

### Requirement: pickBackupFile — SAF File Picker cho Restore

`pickBackupFile()` mở SAF (Storage Access Framework) file picker để user chọn file `.scbak`. Trả về đường dẫn file đã chọn, hoặc null nếu user hủy.

### Requirement: shareFile — Android Share Sheet cho Export

`shareFile(filePath)` mở Android Share Sheet để user chia sẻ file backup ra ứng dụng khác (Google Drive, Gmail, v.v.).

### Requirement: 3-state activation indicator

`KeyboardActivationState` enum gồm `disabled` (IME chưa enable), `enabledNotActive` (đã enable nhưng chưa là keyboard hiện tại), `active` (đang dùng). Banner Home và card Playground hiển thị trạng thái tương ứng, gợi ý hành động phù hợp.

### Requirement: Provider đọc trạng thái một lần mỗi session

`keyboardEnabledProvider` là FutureProvider — resolve một lần rồi cache; không poll. Banner Home chỉ hiện khi value = false VÀ user chưa dismiss (local state `_keyboardBannerDismissed`, mất khi restart app).

#### Scenario: Dismiss banner rồi rebuild Home
- **GIVEN** user đã bấm X trên banner
- **WHEN** switch tab đi rồi quay lại
- **THEN** banner vẫn ẩn trong session; mở lại app thì banner hiện trở lại.
