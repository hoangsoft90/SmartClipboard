# SQLite Schema & Migrations Specification

## Purpose

SQLite là nguồn sự thật DUY NHẤT của toàn bộ dữ liệu app (không có storage song song kiểu Hive/file data). Capability này bao gồm: khởi tạo database với WAL mode, schema v1 (4 bảng: `clipboard_items`, `snippets`, `folders`, `app_meta`), migration runner chạy theo transaction, và DAO nhỏ (`MetaDao`) đọc/ghi bảng key-value `app_meta` cho settings/metrics/cache_version.

## Requirements

### Requirement: WAL mode bắt buộc khi khởi tạo

Hệ thống PHẢI bật `PRAGMA journal_mode=WAL` trong bước `onConfigure` của `AppDatabase.open()` (file: `lib/core/database/app_database.dart`).

#### Scenario: Mở database lần đầu
- **GIVEN** app khởi động qua `main()`
- **WHEN** `AppDatabase.open()` được gọi
- **THEN** `onConfigure` thực thi `PRAGMA journal_mode=WAL` trước mọi thao tác khác, đồng thời bật `PRAGMA foreign_keys=ON` để FK `snippets.folder_id ON DELETE SET NULL` hoạt động.

### Requirement: Migration chạy theo transaction

Mọi migration (onCreate/onUpgrade) PHẢI đi qua `DbMigrations.runInTransaction()` — một transaction duy nhất chứa toàn bộ statement của các version bị bỏ qua (file: `lib/core/database/migrations.dart`).

#### Scenario: Cài mới (version 0 → 1)
- **GIVEN** database chưa tồn tại
- **WHEN** `openDatabase` gọi `onCreate` với version = 1
- **THEN** toàn bộ 10 statement của v1 (4 bảng + 6 index) chạy trong MỘT transaction; nếu statement nào fail, transaction rollback toàn bộ.

#### Scenario: Nâng version tương lai
- **GIVEN** DB ở version 1, code build với `targetVersion` cao hơn
- **WHEN** `onUpgrade(db, from, to)` được gọi
- **THEN** chỉ các khối migration `if (from < N && to >= N)` tương ứng chạy, vẫn trong transaction.

### Requirement: MetaDao đọc/ghi bảng app_meta

`MetaDao` (file: `lib/core/database/app_database.dart`) cung cấp `get/set/getInt/getBool/setBool` trên bảng `app_meta` (key TEXT PRIMARY KEY, value TEXT NOT NULL) với `ConflictAlgorithm.replace`. Bảng này lưu: settings (`expiration_days`, `capture_paused`, `biometric_lock`, `onboarding_done`), `cache_version`, và metrics local-only (prefix `m_`). KHÔNG lưu nội dung text của user.

#### Scenario: Ghi đè giá trị key đã có
- **GIVEN** `app_meta` có row `('capture_paused', '0')`
- **WHEN** `setBool('capture_paused', true)`
- **THEN** row được replace thành `'1'`; `getBool('capture_paused')` trả về `true`.

#### Scenario: Đọc key chưa tồn tại
- **WHEN** `getInt('expiration_days')` trên DB mới (không fallback)
- **THEN** trả về `0` (fallback mặc định).

## Cần làm rõ

- Nếu `AppDatabase.open()` throw (vd: migration fail), `main()` sẽ crash ngay trước `runApp` — không có màn hình lỗi/fallback nào. Spec gốc mục 2.2 chỉ yêu cầu "IME không được hoạt động với cache cũ" nhưng không nói rõ hành vi mong muốn khi chính app không mở được DB. Cần quyết định: crash trắng hay hiện error screen có retry?
