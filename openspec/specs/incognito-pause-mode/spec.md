# Incognito / Pause Mode Specification

## Purpose

Cho phép user tạm dừng ghi Clipboard History bằng toggle một chạm — giải pháp UX tạo niềm tin thay vì cố đoán đúng dữ liệu nhạy cảm bằng heuristic. Không xoá/khóa gì dữ liệu cũ, chỉ ngừng ghi mới.

## Requirements

### Requirement: Toggle persist ngay

Toggle ở AppBar màn hình History và Switch trong Settings đều gọi `AppSettingsController.setCapturePaused()` (file: `lib/state/providers.dart`) → ghi `app_meta('capture_paused')` và cập nhật state Riverpod.

#### Scenario: Bật pause rồi restart app
- **GIVEN** user bật pause mode
- **WHEN** app khởi động lại
- **THEN** setting vẫn bật (load từ app_meta); AppBar History hiển thị icon pause đậm.

### Requirement: Khi bật, UI phải phản ánh trạng thái

Màn History hiện banner errorContainer "ĐANG TẠM DỪNG ghi lịch sử clipboard" phía trên danh sách khi mode bật.

#### Scenario: Banner hiển thị
- **GIVEN** capturePaused = true
- **WHEN** mở tab History
- **THEN** banner màu đỏ nhạt hiển thị ngay dưới AppBar.

### Requirement: Gate trong capture pipeline

`captureFromSystem()` kiểm tra pause flag ĐẦU TIÊN (trước cả đọc clipboard) và trả `CaptureResult.paused`; kết quả này KHÔNG sinh snackbar. Riêng luồng Share Sheet đang dùng `forceSave = true` nên BY-PASS gate này (đã ghi trong spec foreground-clipboard-capture, mục Cần làm rõ).

#### Scenario: Resume khi đang pause
- **GIVEN** pause bật, clipboard có text mới
- **WHEN** app resume
- **THEN** không có row mới, không metric tăng, không thông báo.
