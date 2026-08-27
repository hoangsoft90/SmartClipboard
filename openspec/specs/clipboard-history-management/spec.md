# Clipboard History Management Specification

## Purpose

UI và repository cho danh sách lịch sử clipboard: xem, tái sử dụng (copy lại), tổ chức (pin/favorite), và các kiểu xoá (ẩn soft-delete vs xoá vật lý do user chủ động).

## Requirements

### Requirement: Thứ tự hiển thị danh sách active

`getActive()` trả về các row `is_archived = 0`, sắp xếp `is_pinned DESC, created_at DESC` (pinned trước, rồi mới nhất lên đầu).

#### Scenario: Danh sách có item pinned cũ hơn item thường mới
- **GIVEN** item A pinned (created 1 ngày trước), item B thường (created 1 phút trước)
- **WHEN** load danh sách
- **THEN** A đứng trước B.

### Requirement: Tái sử dụng item

Tap vào item → `copyToSystem()`: set system clipboard bằng content, UPDATE `last_used_at`/`updated_at`/`copy_count + 1` trên item, tăng metric `m_clipboard_items_reused`, markActiveToday, reload list, snackbar "Đã copy".

#### Scenario: Copy lại item lần thứ 5
- **GIVEN** item có copy_count = 4
- **WHEN** user tap item
- **THEN** system clipboard chứa nội dung item; copy_count = 5.

### Requirement: Pin / Favorite

Menu item cho phép toggle `is_pinned` / `is_favorite` (persist ngay qua `setPinned/setFavorite` kèm updated_at). Item pinned/favorite được MIỄN KHỎI archive khi enforce free limit và miễn purge expired.

### Requirement: Ba kiểu xoá phân biệt rõ

1. **Ẩn khỏi lịch sử** (`archive`) — soft-delete, `is_archived = 1`, dữ liệu còn nguyên.
2. **Xoá vĩnh viễn** (`deleteForever`) — DELETE vật lý, CHỈ khi user chủ động chọn menu.
3. **Purge hết hạn** (`purgeExpired`) — DELETE vật lý tự động, chỉ áp dụng item có `expires_at < now` VÀ không pin VÀ không archived (xem spec auto-expiration).

#### Scenario: User xoá vĩnh viễn
- **GIVEN** item đang hiển thị
- **WHEN** user chọn "Xoá vĩnh viễn" từ popup menu
- **THEN** row bị DELETE khỏi DB, list reload, không còn cách khôi phục.

### Requirement: Gợi ý xoá sau 24h cho item nghi vấn

Item có `privacy_risk_score >= 1` hiển thị thêm menu "Xoá sau 24h ⚠️ heuristic": set `expires_at = now + 24h` qua `setExpiry()`.

#### Scenario: Item score 1 được đặt expiry
- **GIVEN** item có risk score 1, expires_at = null
- **WHEN** user chọn "Xoá sau 24h"
- **THEN** `expires_at` = now + 24h; item sẽ bị purge khi quá hạn (lần reload kế tiếp).
