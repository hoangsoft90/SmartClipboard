# Local-Only Metrics Specification

## Purpose

Đo lường habit Text Expander để quyết định Go/No-Go đầu tư Native IME (Phase 1). Metric quan trọng nhất: `expansion_count / days_active ≥ 1`. Toàn bộ counter nằm trong bảng `app_meta` trên thiết bị, KHÔNG chứa nội dung text của user, KHÔNG gửi đi đâu (local-first 100%).

## Requirements

### Requirement: Sáu counter chuẩn

`MetricsService` (file: `lib/services/metrics_service.dart`) quản lý đúng các key: `m_snippets_created`, `m_expansion_count`, `m_clipboard_items_saved`, `m_clipboard_items_reused`, `m_playground_expansions`, `m_days_active` (dạng chuỗi ngày ISO yyyy-MM-dd phân tách dấu phẩy).

#### Scenario: Counter tăng đơn điệu
- **GIVEN** m_clipboard_items_saved = 41
- **WHEN** capture nội dung mới thành công
- **THEN** giá trị lưu là '42' (read-modify-write qua MetaDao).

### Requirement: Điểm ghi metric

| Sự kiện | Metric |
|---|---|
| Capture nội dung MỚI | clipboard_items_saved +1 |
| Capture trùng (dedup) | clipboard_items_reused +1 |
| Copy lại từ history | clipboard_items_reused +1 |
| Tạo snippet | snippets_created +1 |
| Expand trong Playground | expansion_count +1, playground_expansions +1 |

Mọi điểm ghi đều kèm `markActiveToday()` (idempotent theo ngày).

#### Scenario: Ngày thứ 3 sử dụng
- **GIVEN** days_active = "2026-08-24,2026-08-25"
- **WHEN** ngày 26/08 user expand một lần
- **THEN** days_active = "2026-08-24,2026-08-25,2026-08-26"; activeDays() = 3.

### Requirement: Tính ratio Go/No-Go

`expansionsPerActiveDay()` = expansion_count / activeDays; days_active = 0 → trả 0 (tránh chia 0). Settings hiển thị text kèm giải thích ngưỡng ≥ 1.

#### Scenario: Chưa active ngày nào
- **GIVEN** app mới cài, chưa capture gì
- **WHEN** mở Settings
- **THEN** ratio hiển thị "0" mà không lỗi.

### Requirement: Metrics không backup, không log

Payload backup KHÔNG chứa app_meta → metrics reset khi restore. Không có bất kỳ đường dẫn nào đưa metric ra ngoài thiết bị hay vào logcat.

## Cần làm rõ

- `markActiveToday()` parse chuỗi comma-separated mỗi lần gọi và append nếu thiếu — với usage dài nhiều năm chuỗi sẽ dài dần (vẫn hoạt động nhưng O(n)). **Đã chấp nhận**: với usage thực tế (3-5 lần/tuần, mỗi lần 1 ngày), chuỗi sẽ dài ~300 entries sau 5 năm (~1.5KB) — không đáng kể.
- Settings summary dùng FutureBuilder đọc trực tiếp `ref.read(metricsProvider).summary()` mỗi build — không tự refresh khi metric thay đổi khi đang mở tab (phải vào lại tab). **Đã chấp nhận**: user cần vào lại tab hoặc restart app để thấy metric mới nhất.
