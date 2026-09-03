# Working Log — Smart Clipboard

> Nhật ký làm việc. Mục cũ quá 1–2 tuần sẽ dọn (nội dung đã nằm trong AgentMemory/ADR).

## [2026-09-03] — Session: Remediation plan12 + platform-fixes
- Xong: Đọc lại toàn bộ context project (README, master spec, openspec, plan12_final).
- Xong: Tạo OpenSpec change `openspec/changes/platform-fixes/` (spec.md + tasks.md, 4 tasks) từ plan12_final.md.
- Xong: **Task 1 — Backup Restore fix** (`android/.../MainActivity.kt`): thêm `copyUriToCacheFile()` copy content:// URI → file tạm trong cacheDir, trả absolute path cho dart:io. Fix crash chắc chắn khi restore qua SAF picker.
- Xong: **Task 2 — Dedup copy_count fix** (`lib/repositories/clipboard_repository.dart`): nhánh dedup dùng `rawUpdate` với `copy_count = copy_count + 1, is_archived = 0` (atomic, unarchive item bị ẩn).
- Xong: **Task 3 — Pro gate** (`lib/screens/home_screen.dart`): `BannerAdWidget` wrap trong `Consumer` — ẩn banner khi `isProActiveProvider` = true.
- Xong: **Task 4 — Privacy claim** (`lib/screens/onboarding/onboarding_screen.dart`): sửa 3 claim cho khớp thực tế AdMob/Sentry (nội dung không rời thiết bị, mạng chỉ cho ads + error reporting, claim password field chính xác hơn).
- Xong: `dart analyze` toàn bộ file thay đổi — 0 errors.
- Xong: Code review toàn bộ diff (skill code-review) — 4/4 PASS, fix 1 lỗi cosmetic (line concat trong clipboard_repository.dart).
- Chưa làm: archive OpenSpec change platform-fixes (chờ quyết định sync specs + archive); release signing (keystore — bước thủ công của user); build APK verify.

## Trạng thái OpenSpec changes
- `platform-fixes` — **đang chạy**, 4/4 task hoàn thành, chưa archive.
- `admob-monetization` — còn dở (Task 1-3 một phần: cần enableAds check trong banner_widget, ad placement Clipboard/Snippets/Settings screens, safe area verify, build verify).
- `platform-hardening` — còn dở (Sentry đã xong, HTTP cleartext xong, targetSdk 36 chưa làm).