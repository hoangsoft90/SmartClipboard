# Encrypted Backup & Restore Specification

## Purpose

Export/import toàn bộ dữ liệu app ra file mã hoá để chuyển máy/khôi phục. Key mã hoá derive từ passphrase USER TỰ NHẬP (Phương án A — không dùng Keystore, cho phép khôi phục trên máy khác): AES-256-GCM + PBKDF2-HMAC-SHA256 ≥ 100k iterations, salt ngẫu nhiên lưu cùng file, nonce GCM ngẫu nhiên mỗi lần export.

## Requirements

### Requirement: PBKDF2 đủ mạnh, không hardcode key

`pbkdf2HmacSha256()` (file: `lib/core/utils/pbkdf2.dart`) tự triển khai RFC 2898 trên HMAC-SHA256 của package `crypto`; assert `iterations >= 100000`. `BackupService.kdfIterations = 150000`, salt 16 bytes và nonce 12 bytes sinh bằng `Random.secure()` MỖI lần export. KHÔNG hardcode key, KHÔNG derive từ device ID.

#### Scenario: Export hai lần liên tiếp
- **GIVEN** cùng passphrase
- **WHEN** export hai file backup
- **THEN** salt và nonce trong hai envelope KHÁC nhau; ciphertext khác nhau dù plaintext giống.

### Requirement: Định dạng file backup

File `.scbak` trong thư mục Documents, JSON envelope: `{format: 'smart_clipboard_backup', version: 1, kdf: {algo, iterations, salt(b64)}, nonce(b64), ciphertext(b64)}`. Plaintext payload: `{exported_at, folders[], snippets[], clipboard_items[]}` — BAO GỒM cả row archived; KHÔNG chứa app_meta (metrics/settings không backup).

#### Scenario: Backup gồm cả item đã archive
- **GIVEN** 5 snippet archived
- **WHEN** export
- **THEN** mảng snippets trong payload có đủ 20 row (15 active + 5 archived).

### Requirement: Restore validate rồi thay thế toàn bộ

`restoreFrom(path, passphrase)` (file: `lib/services/backup_service.dart`): file không tồn tại / JSON sai / format sai → `BackupException` với message rõ; iterations < 100000 → từ chối; decrypt fail (sai passphrase/file hỏng — GCM auth tag fail) → exception "Sai passphrase hoặc file bị hỏng". Thành công → transaction: DELETE sạch 3 bảng data rồi INSERT lại từ payload. Caller (Settings) sau đó bắt buộc gọi `regenerateSnippetCache()` và reload các list provider.

#### Scenario: Sai passphrase
- **GIVEN** file backup hợp lệ
- **WHEN** restore với passphrase sai
- **THEN** BackupException "Sai passphrase..."; dữ liệu hiện tại trong DB GIỮ NGUYÊN (không xoá vì decrypt fail trước transaction).

#### Scenario: Restore thành công
- **GIVEN** DB đang có 10 snippet, backup có 20
- **WHEN** restore đúng passphrase
- **THEN** trong một transaction: 3 bảng bị xoá sạch rồi ghi lại đúng như payload; cache file regen; danh sách UI reload hiển thị 20 snippet.

### Requirement: UX passphrase an toàn tối thiểu

Dialog export yêu cầu passphrase ≥ 8 ký tự mới enable nút; cảnh báo "QUÊN PASSPHRASE = KHÔNG THỂ RESTORE". Dialog restore cảnh báo "Restore sẽ THAY THẾ toàn bộ data hiện tại". Passphrase KHÔNG được lưu ở bất kỳ đâu.

#### Scenario: Passphrase quá ngắn
- **GIVEN** user nhập 5 ký tự
- **WHEN** dialog export mở
- **THEN** nút Export không thực thi (chỉ pop khi length >= 8).
