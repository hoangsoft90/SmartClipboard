# Foreground Clipboard Capture Specification

## Purpose

Lưu nội dung clipboard hệ thống vào lịch sử khi app lên foreground. Đây là cơ chế capture DUY NHẤT của app — tuyệt đối không có background service nghe lén nền.

## Requirements

### Requirement: Capture chỉ xảy ra khi app chuyển sang resumed

`HomeScreen` (file: `lib/screens/home_screen.dart`) đăng ký `WidgetsBindingObserver`; khi `didChangeAppLifecycleState == resumed` → gọi `ClipboardService.captureFromSystem()` (file: `lib/services/clipboard_service.dart`). Không có bất kỳ listener/timer nào chạy khi app ở background.

#### Scenario: User switch app rồi quay lại
- **GIVEN** Pause Mode đang TẮT, clipboard chứa text "abc"
- **WHEN** app nhận lifecycle event `resumed`
- **THEN** "abc" được lưu vào history (hoặc dedup nếu đã có), danh sách được reload, snackbar "Đã lưu vào lịch sử" hiển thị (chỉ khi kết quả là `saved`).

### Requirement: Tôn trọng Incognito/Pause Mode

Nếu `app_meta('capture_paused') == true` và không phải `forceSave`, `captureFromSystem()` PHẢI trả về `CaptureResult.paused` mà KHÔNG đọc/ghi gì.

#### Scenario: Pause mode bật
- **GIVEN** user bật toggle "Tạm dừng ghi" trong Settings hoặc AppBar History
- **WHEN** app resume
- **THEN** clipboard KHÔNG được lưu; không hiển thị snackbar báo lỗi (im lặng theo thiết kế).

### Requirement: Chặn lưu khi heuristic nghi vấn cao (score = 2)

Trước khi lưu, `PrivacyService.assess()` chạy trên nội dung; nếu risk score = 2 và không phải `forceSave` → trả về `blockedHighRisk`. HomeScreen hiện dialog hỏi user: "Không lưu" hoặc "Lưu & xoá sau 24h". Lựa chọn sau gọi `confirmSaveBlockedContent()` — lưu với `expires_at` = now + 24h.

#### Scenario: Clipboard chứa OTP 6 số
- **GIVEN** clipboard là "Mã OTP là 483920"
- **WHEN** app resume
- **THEN** dialog cảnh báo xuất hiện với disclaimer heuristic; nếu user chọn lưu → item được tạo với risk score 2 và expires_at sau 24 giờ.

### Requirement: Bỏ qua clipboard rỗng

Nếu clipboard null hoặc trim rỗng → trả về `empty`, không ghi DB, không metric.

### Requirement: Cập nhật metrics sau capture thành công

Sau khi save thành công: increment `m_clipboard_items_saved` (nội dung mới) hoặc `m_clipboard_items_reused` (dedup), và `markActiveToday()`. Metrics KHÔNG chứa nội dung text.

#### Scenario: Capture trùng nội dung lần 3
- **GIVEN** nội dung đã tồn tại trong history
- **WHEN** capture hoàn tất
- **THEN** counter `m_clipboard_items_reused` tăng thêm 1, `m_clipboard_items_saved` giữ nguyên.

## Cần làm rõ

- ~~Field `_lastCapturedHash` trong `ClipboardService`~~ **Đã xóa**: field này chưa từng tồn tại trong code production — chỉ là ghi chú thiết kế ban đầu, đã được loại bỏ.
- ~~Luồng Share Sheet~~ **Đã giải quyết**: Share sheet gọi `saveContent(text, forceSave: true)` trực tiếp (KHÔNG qua `captureFromSystem`) — bypass pause mode và score=2 block. Đây là hành vi đúng: user chủ động share thì app nên lưu ngay. `forceSave` chỉ dùng trong luồng Share Sheet.
- Capture trên Android 10+ chỉ đọc được clipboard khi app ở foreground — đúng hành vi mong muốn. Android 12+ có thể hiện toast "app đã dán từ clipboard" — đây là hành vi hệ thống, không cần giải thích trong onboarding.
