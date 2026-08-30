# Content Deduplication via Hash Specification

## Purpose

Tránh trùng lặp lịch sử clipboard: cùng một nội dung copy nhiều lần chỉ tạo MỘT bản ghi, các lần sau chỉ cập nhật thời gian sử dụng. Hash PHẢI tính trên nội dung đã normalize để "hello world", " hello world " hay biến thể Unicode (é single code point vs e + combining mark) ra cùng một hash.

## Requirements

### Requirement: Normalize trước khi hash

`normalizeContent(raw)` (file: `lib/core/utils/content_normalizer.dart`) PHẢI: trim hai đầu, collapse mọi run whitespace (`\s+`) thành một space, rồi áp dụng NFC xấp xỉ (bảng compose ~170 cặp Latin-1 + tiếng Việt, vì Dart stdlib không có `String.normalize()`). `contentHash(raw)` = SHA256 hex của UTF-8 bytes của chuỗi đã normalize.

#### Scenario: Whitespace thừa không đổi hash
- **GIVEN** hai lần capture lần lượt là `"Hello   World"` và `" hello world "`
- **WHEN** tính content_hash
- **THEN** hai hash bằng nhau.

#### Scenario: Tiếng Việt decomposed == precomposed
- **GIVEN** chuỗi `'ế'` precomposed (U+1EBF) và chuỗi decomposed `'e' + U+0302 + U+0301`
- **WHEN** normalize cả hai
- **THEN** kết quả giống nhau (dedup coi là một nội dung).

### Requirement: Dedup logic khi lưu clipboard

`ClipboardRepository.save()` (file: `lib/repositories/clipboard_repository.dart`): nếu `content_hash` đã tồn tại → UPDATE `last_used_at` + `updated_at` = now trên bản ghi cũ và trả về `wasDeduplicated = true`; ngược lại INSERT bản ghi mới với hash, content_type từ heuristic, expires_at, risk score.

#### Scenario: Copy lại nội dung đã có
- **GIVEN** history có bản ghi hash H với `copy_count = 3`
- **WHEN** `save(content)` với nội dung có hash H
- **THEN** KHÔNG có INSERT mới; bản ghi cũ có `last_used_at` mới; result báo `wasDeduplicated = true`.

#### Scenario: Nội dung mới
- **GIVEN** hash chưa tồn tại
- **WHEN** `save(content)`
- **THEN** INSERT row mới; unique index `idx_clipboard_hash` đảm bảo không bao giờ có 2 row cùng hash.

## Cần làm rõ

- **Hành vi đã chốt**: `copy_count` CHỈ tăng khi user chủ động copy item từ history UI (`markUsed()`), KHÔNG tăng khi capture trùng (dedup). Dedup chỉ cập nhật `last_used_at`/`updated_at` + metric `clipboard_items_reused`. Lý do: copy_count đo "mục đích sử dụng lại từ app", không phải "số lần clipboard system bị trùng".
- NFC xấp xỉ chỉ phủ Latin-1 + tiếng Việt; ký tự Unicode khác (Hàn, Emoji ZWJ sequence) chưa compose. **Đã chấp nhận làm technical debt** —_full NFC yêu cầu package ngoài whitelist, chưa cần thiết cho thị trường VN.
