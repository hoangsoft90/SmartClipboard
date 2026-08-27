# Onboarding Flow Specification

## Purpose

Onboarding lần đầu mở app: giới thiệu định vị "Personal Text Memory" + cam kết privacy, hướng dẫn bật system keyboard (qua Direct Intent Settings), hướng dẫn battery optimization theo hãng máy phổ biến VN (MIUI/ColorOS/One UI — bắt buộc hiển thị, không block nếu user bỏ qua), và giới thiệu Share Sheet fallback. KHÔNG có Floating Widget trong MVP.

## Requirements

### Requirement: Chỉ hiện khi chưa hoàn thành

`RootGate` (file: `lib/main.dart`) render `OnboardingScreen` khi `app_meta('onboarding_done') == false` (sau khi settings load xong). Hoàn thành → set flag true, từ đó luôn vào Home.

#### Scenario: Lần đầu mở app
- **GIVEN** DB mới, onboarding_done chưa set
- **WHEN** app start
- **THEN** OnboardingScreen hiện ra ở trang 1 (trước cả HomeScreen).

#### Scenario: Mở app lần thứ N
- **GIVEN** onboarding_done = true
- **WHEN** app start
- **THEN** vào thẳng HomeScreen (hoặc LockGate nếu biometric bật).

### Requirement: Điều hướng PageView

4 trang theo đúng thứ tự: Intro privacy → Enable Keyboard → OEM Battery → Share Sheet. Nút "Tiếp" chuyển trang; nút "Bỏ qua" nhảy thẳng tới finish từ BẤT KỲ trang nào; trang cuối nút đổi thành "Bắt đầu dùng".

#### Scenario: Bỏ qua ngay trang đầu
- **GIVEN** đang ở trang Intro
- **WHEN** bấm "Bỏ qua"
- **THEN** onboarding_done = true, thoát khỏi onboarding mà không cần xem các trang còn lại (đáp ứng yêu cầu "không bắt buộc block").

### Requirement: Trang keyboard gọi native bridge stub

Nút "Enable Keyboard" gọi `NativeBridge.openKeyboardSettings()` (Phase 0 = no-op stub) rồi tự check `isKeyboardEnabled()` (stub trả false) hiển thị trạng thái: null → "Kiểm tra trạng thái", false → "⏳ Chưa bật — bạn có thể bật sau", true → "✅ Đã bật bàn phím".

#### Scenario: Phase 0 bấm Enable Keyboard
- **GIVEN** chưa có native implementation
- **WHEN** bấm nút rồi bấm "Kiểm tra trạng thái"
- **THEN** không crash (MissingPluginException được nuốt), hiển thị "Chưa bật".

### Requirement: Nội dung OEM battery VN

Trang 3 liệt kê hướng dẫn tĩnh: Cài đặt > Pin > Tối ưu hoá pin → Smart Clipboard → "Không giới hạn"; MIUI thêm bước bảo vệ khởi động tự động; kèm ghi chú "Bạn có thể bỏ qua bước này".
