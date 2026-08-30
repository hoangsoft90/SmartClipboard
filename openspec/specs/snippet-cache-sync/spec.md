# Snippet Cache Sync Specification

## Purpose

Flutter App process và Android IME process là hai tiến trình OS độc lập, KHÔNG chia sẻ bộ nhớ. Cầu nối đồng bộ duy nhất giữa hai bên là file `snippets_cache.json` trên disk + marker `cache_version` trong bảng `app_meta`. Capability này định nghĩa việc sinh/cập nhật file cache đó. Android IME (SmartClipboardIME) đọc file cache này mỗi khi keyboard hiện ra, parses JSON, và render snippet toolbar.

## Requirements

### Requirement: regenerateSnippetCache ghi toàn bộ trigger đang enabled ra file

`CacheSyncService.regenerateSnippetCache()` (file: `lib/services/cache_sync_service.dart`) PHẢI:
1. Query bảng `snippets` với điều kiện `is_enabled = 1 AND is_archived = 0`.
2. Bump `cache_version` bằng monotonic counter (read current from `app_meta`, increment by 1, write back) — KHÔNG dùng timestamp để tránh lỗi clock skew.
3. Ghi JSON `{"cache_version": <int>, "triggers": {trigger → content}, "keyboard_bg_color": <hex>}` vào `<app_support>/snippets_cache.json` theo kiểu ghi file `.tmp` rồi rename (giảm nguy cơ IME đọc phải file dở dang). Keyboard background color được đọc từ `app_meta('keyboard_bg_color')` và included trong payload.

#### Scenario: User tạo snippet mới
- **GIVEN** cache file hiện có 5 trigger
- **WHEN** `SnippetRepository.create(...)` hoàn tất insert
- **THEN** repository gọi `regenerateSnippetCache()` ngay sau đó; file mới chứa đúng 6 trigger, `cache_version` mới lớn hơn cũ.

#### Scenario: Snippet disabled hoặc archived bị loại khỏi cache
- **GIVEN** snippet `;email` có `is_enabled = 0`
- **WHEN** cache regen chạy
- **THEN** `;email` KHÔNG xuất hiện trong map `triggers` của file.

### Requirement: Cache regen bắt buộc sau các sự kiện cụ thể

`regenerateSnippetCache()` PHẢI được gọi sau: (a) MỌI mutation snippet trong `SnippetRepository`: `create`, `update`, `setEnabled`, `archive`, `restoreAllArchived`, `deleteForever`; (b) sau khi migration thành công lúc mở app (gọi trong `main.dart`, bọc try/catch); (c) sau restore backup thành công (Settings screen). Riêng `incrementUsage()` KHÔNG regen (usage_count không nằm trong trigger map).

#### Scenario: Khởi động app
- **GIVEN** DB vừa mở xong với version mới nhất
- **WHEN** `main()` chạy tiếp
- **THEN** `CacheSyncService(db).regenerateSnippetCache()` được gọi trước `runApp`; nếu nó throw thì app vẫn chạy tiếp (cache cũ/hỏng được chấp nhận, IME phía Phase 1 phải tự fallback empty state).

#### Scenario: Toggle enabled snippet
- **GIVEN** snippet đang enabled
- **WHEN** user tắt Switch trên danh sách snippet (`setEnabled(id, false)`)
- **THEN** trigger tương ứng biến mất khỏi cache file ngay sau đó.

### Requirement: Xoá cache an toàn

`deleteCacheFile()` xoá file cache nếu tồn tại — dùng cho test/khôi phục hỏng. IME (Phase 1) phải fallback empty state khi file biến mất, không crash.

## Cần làm rõ

- `deleteCacheFile()` hiện KHÔNG được gọi bởi bất kỳ code production nào (chỉ dành cho test/khôi phục theo comment). Đây là dead code có chủ đích hay nên xoá?
- ~~Việc bump `cache_version` bằng timestamp: nếu đồng hồ hệ thống bị chỉnh lùi, version mới có thể nhỏ hơn version cũ.~~ **Đã giải quyết**: chuyển sang monotonic counter (read-increment-write trong SQLite transaction) — version luôn tăng, không phụ thuộc system clock.
