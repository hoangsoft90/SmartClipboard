# In-App Text Expansion & Playground Specification

## Purpose

Chứng minh giá trị core "gõ tắt" NGAY TRONG APP trước khi có bàn phím hệ thống (Phase 1): ExpansionEngine xử lý trigger/delimiter/escape đúng rule mục 4.2 spec gốc; Expander Playground là màn hình bắt buộc cho user thấy "Aha Moment" và là nguồn metric product-market-fit sớm nhất (`playground_expansions`).

## Requirements

### Requirement: Chỉ expand khi trigger theo sau delimiter

`ExpansionEngine.processInput(input)` (file: `lib/services/expansion_engine.dart`) chỉ xét khi ký tự CUỐI buffer thuộc tập delimiter `' \n\t.,!?'`. Token được trích bằng regex `[^\s.,!?]+$` trên phần body (trước delimiter); chỉ token BẮT ĐẦU bằng prefix ';' được xét.

#### Scenario: Expand với Space
- **GIVEN** trigger map chứa `email → contact@company.com`
- **WHEN** processInput(';email ')
- **THEN** output 'contact@company.com ', changed = true, expandedTrigger = 'email'.

#### Scenario: Chưa gõ delimiter thì không expand
- **WHEN** processInput(';email')
- **THEN** changed = false, text giữ nguyên.

#### Scenario: Trigger dính liền từ phía trước
- **GIVEN** input 'user;email '
- **WHEN** processInput
- **THEN** token là 'user;email' (không bắt đầu bằng prefix) → KHÔNG expand — tránh phá email thật như user@email.com (instant mode bị loại khỏi MVP).

### Requirement: Escape bằng double prefix

Token bắt đầu bằng ';;' → bỏ MỘT dấu ';' ở đầu token, không expand.

#### Scenario: Gõ ;;email + space
- **WHEN** processInput(';;email ')
- **THEN** output ';email ' (một dấu ;), changed = true nhưng expandedTrigger = null.

### Requirement: Trigger lạ không đổi text

Token dạng ';xyz' không có trong map → unchanged (không xoá gì).

### Requirement: Playground thay thế buffer an toàn

PlaygroundScreen (file: `lib/screens/playground/playground_screen.dart`) gọi engine trong `onChanged`; nếu changed → set `TextEditingValue` mới với caret về cuối chuỗi. Việc thay thế dùng Dart string replaceRange — an toàn UTF-16 code unit với emoji/ký tự có dấu trong nội dung.

#### Scenario: Expand nội dung chứa emoji
- **GIVEN** snippet x → '😀 emoji 🇻🇳'
- **WHEN** gõ 'xinh ;x ' trong Playground TextField
- **THEN** TextField hiển thị 'xinh 😀 emoji 🇻🇳 ' với caret cuối; card kết quả hiện nội dung + nút Copy.

#### Scenario: Emoji dính liền prefix không expand
- **GIVEN** input '😀;x '
- **WHEN** processInput
- **THEN** token '😀;x' không bắt đầu bằng prefix → unchanged (token rule; test case tương ứng trong test/expansion_engine_test.dart).

### Requirement: Track metrics & usage khi expand thành công

Mỗi lần expand có matched snippet: tăng `m_expansion_count`, `m_playground_expansions`, markActiveToday, và `incrementUsage(snippetId)`.

#### Scenario: Expand lần đầu trong ngày
- **GIVEN** counters hiện tại, days_active chưa có hôm nay
- **WHEN** user expand ;email trong Playground
- **THEN** expansion_count +1, playground_expansions +1, days_active thêm ngày hôm nay, usage_count snippet +1.

### Requirement: Engine đọc state Riverpod realtime

`expansionEngineProvider` build lại map trigger→content/id từ danh sách snippet enabled (non-archived) mỗi khi danh sách thay đổi — không cần restart.

#### Scenario: Tạo snippet rồi quay lại Playground
- **GIVEN** vừa tạo snippet ;hello
- **WHEN** gõ ';hello ' trong Playground
- **THEN** expansion hoạt động ngay mà không cần khởi động lại app.
