# Snippet & Folder Management Specification

## Purpose

CRUD cho Snippets (gõ tắt `;trigger` → content) và Folders (nhóm snippet). Mọi mutation snippet kéo theo cache regen (xem spec snippet-cache-sync). Free tier giới hạn 15 active snippet / 3 folder — enforcement chi tiết nằm ở spec free-tier-soft-delete.

## Requirements

### Requirement: Tạo snippet với trigger hợp lệ

`SnippetRepository.create()` (file: `lib/repositories/snippet_repository.dart`): trigger được clean whitespace trước khi lưu (`trim()` + bỏ mọi ký tự `\s`); prefix mặc định ';'; usage_count khởi tạo 0. Form tạo/sửa (file: `lib/screens/snippets/snippet_edit_screen.dart`) chặn thêm: trigger rỗng, chứa space hoặc dấu câu `.,!?` (vì các ký tự đó là delimiter kích hoạt expansion); formatter chặn gõ whitespace realtime.

#### Scenario: Tạo snippet ;email
- **GIVEN** form điền title "Email công việc", trigger "email", nội dung hợp lệ
- **WHEN** bấm "Tạo snippet"
- **THEN** row mới trong bảng snippets với prefix ';' , is_enabled = 1; cache regen; snackbar xác nhận ";email".

#### Scenario: Trigger chứa dấu cách bị chặn
- **GIVEN** user nhập trigger "my email"
- **WHEN** validate
- **THEN** hiển thị error "Trigger chỉ gồm chữ/số/ký hiệu liền mạch"; nút Lưu không thực thi.

### Requirement: Sửa / bật-tắt / xoá snippet

- `update(snippet)`: ghi đè các field + updated_at + cache regen.
- Toggle Switch trên tile → `setEnabled(id, bool)` + cache regen (disabled snippet biến mất khỏi cache).
- "Xoá vĩnh viễn" từ edit screen: confirm dialog bắt buộc → DELETE vật lý + cache regen.
- Menu/archive: `archive(id)` soft-delete + cache regen.

#### Scenario: Disable snippet
- **GIVEN** snippet ;addr đang enabled
- **WHEN** tắt Switch
- **THEN** `is_enabled = 0`; expansion engine (đọc từ provider) không còn map ;addr; cache file không chứa addr.

### Requirement: usage_count chỉ tăng qua incrementUsage

`incrementUsage(id)` chạy raw UPDATE `usage_count + 1` và KHÔNG regen cache (field không thuộc trigger map). Gọi từ Playground khi expansion xảy ra.

#### Scenario: Expand trong Playground
- **GIVEN** snippet id X usage_count = 10
- **WHEN** playground expand thành công snippet X
- **THEN** usage_count = 11; cache_version không đổi.

### Requirement: Folder CRUD với FK SET NULL

- `createFolder(name)`: chỉ cho phép khi tổng folder < 3 (`canCreateFolder()`); UI hiện dialog Pro thay vì tạo khi vượt.
- `renameFolder(id, name)`.
- `deleteFolder(id)`: DELETE row folder; nhờ `PRAGMA foreign_keys=ON` + `ON DELETE SET NULL`, mọi snippet thuộc folder đó giữ nguyên dữ liệu với `folder_id = NULL`.

#### Scenario: Xoá folder chứa 4 snippet
- **GIVEN** folder F có 4 snippet
- **WHEN** chọn "Xoá" trong popup menu FoldersScreen
- **THEN** folder F mất khỏi DB; 4 snippet vẫn tồn tại, folder_id = NULL (hiển thị không gán folder).

#### Scenario: Tạo folder thứ 4 ở bản Free
- **GIVEN** đã có đúng 3 folder, proStatus = false
- **WHEN** bấm "Folder mới"
- **THEN** dialog "Giới hạn bản Free" hiện ra, không tạo folder mới.

## Cần làm rõ

- Trigger UNIQUE ở mức schema (`trigger TEXT UNIQUE NOT NULL`): việc create trigger trùng sẽ throw DatabaseException thô chứ không có error message thân thiện trong form. Cần catch và hiện lỗi "Trigger đã tồn tại"?
- `_cleanTrigger` strip mọi whitespace NHƯNG form validator chỉ chặn space/dấu câu — ký tự tab/newline bị strip im lặng lúc save thay vì báo lỗi. Có nhất quán được không?
