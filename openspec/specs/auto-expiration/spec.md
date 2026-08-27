# Auto-Expiration Specification

## Purpose

Tự động xoá lịch sử clipboard sau khoảng thời gian chọn trước (1/7/30 ngày) — history clipboard là dữ liệu tạm thời, khác với snippet/folder (dữ liệu user, chỉ soft-delete). Item pinned được miễn xoá.

## Requirements

### Requirement: expires_at được set lúc insert

Mọi INSERT mới vào `clipboard_items` PHẢI có `expires_at = expiresAtOverride ?? now + expirationDays * 86400000` (file: `lib/repositories/clipboard_repository.dart`, hàm `save()`). Giá trị `expirationDays` đọc từ setting (default: 30 ngày).

#### Scenario: Setting đang là 7 ngày
- **GIVEN** `expiration_days` = 7
- **WHEN** capture nội dung mới lúc 10:00
- **THEN** row mới có `expires_at` = 10:00 bảy ngày sau.

### Requirement: Purge chạy khi reload danh sách

`ClipboardListController.reload()` PHẢI gọi `purgeExpired()` trước khi query danh sách: DELETE mọi row thỏa `expires_at < now AND is_pinned = 0 AND is_archived = 0`.

#### Scenario: Item hết hạn bị xoá khỏi UI và DB
- **GIVEN** item có expires_at đã quá 1 giờ, không pin
- **WHEN** app resume → capture → reload()
- **THEN** purgeExpired xoá row vật lý; item biến mất khỏi danh sách.

#### Scenario: Item pinned quá hạn vẫn sống
- **GIVEN** item PINNED có expires_at đã quá hạn
- **WHEN** purgeExpired chạy
- **THEN** row KHÔNG bị xoá.

### Requirement: Setting lựa chọn 1/7/30 ngày

Settings screen hiển thị dropdown "Tự xoá lịch sử sau" với đúng các giá trị `[1, 7, 30]` (từ `AppLimits.expirationOptionsDays`); thay đổi persist ngay vào `app_meta('expiration_days')`. Giá trị load từ DB không hợp lệ (ngoài danh sách) → fallback về 30.

#### Scenario: Đổi expiration sang 1 ngày
- **GIVEN** settings đang 30 ngày
- **WHEN** user chọn "1 ngày"
- **THEN** `app_meta('expiration_days')` = '1'; các item MỚI capture sau đó hết hạn sau 24 giờ (item cũ giữ expires_at cũ).

## Cần làm rõ

- Item đã có sẵn KHÔNG được cập nhật expires_at khi user đổi setting (chỉ áp dụng cho item mới). Đây là hành vi hiện tại — cần xác nhận đây là ý định đúng hay cần re-scan toàn bộ khi đổi setting?
- Item favorite nhưng không pin vẫn bị purge khi hết hạn. Có nên miễn favorite như pinned không?
