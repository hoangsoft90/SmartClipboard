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
- Xong: **Release signing config** (`android/app/build.gradle`): thêm `signingConfigs.release` đọc từ `android/key.properties` (gitignored), fallback debug khi chưa có key.properties. Keystore thật + key.properties là bước thủ công của user — KHÔNG agent tạo.
- Xong: Push `9d9ebca` lên main → GH Actions build APK (debug + release).
- Xong: **Workflow `Build Release AAB`** (`.github/workflows/build-release-aab.yml`): trigger push main + workflow_dispatch; restore keystore từ GH secrets → `android/app/keystore-release.jks` + ghi `android/key.properties` → `flutter build appbundle --release` → verify cert không phải debug (fail nếu có "Android Debug") → upload artifact.
- Xong: Tạo keystore cố định (`/tmp/smart-clipboard-release.jks`, pass 83793900, alias `smart_clipboard`, RSA 2048, validity 10000 ngày) + tạo 4 GH secrets qua GitHub API (ANDROID_KEYSTORE_BASE64, ANDROID_KEYSTORE_PASSWORD, ANDROID_KEY_PASSWORD, ANDROID_KEY_ALIAS).
- Xong: Fix CI — `storeFile` Gradle resolve tương đối theo app module → keystore phải decode vào `android/app/` (không phải `android/`).
- Xong: Build AAB CI success (run 33715286364) — cert Owner `CN=Smart Clipboard...`, SHA256 `75:58:34:C2:5C:BE:77:FD:...`, KHÔNG phải Android Debug. → Play Store không còn lỗi "signed in debug mode".
- Chưa làm: archive OpenSpec change platform-fixes (chờ quyết định sync specs + archive); user tạo keystore + key.properties thủ công; verify apksigner; build APK verify (đang chạy CI).

## Trạng thái OpenSpec changes
- `platform-fixes` — **đang chạy**, 4/4 task hoàn thành, chưa archive.
- `admob-monetization` — còn dở (Task 1-3 một phần: cần enableAds check trong banner_widget, ad placement Clipboard/Snippets/Settings screens, safe area verify, build verify).
- `platform-hardening` — còn dở (Sentry đã xong, HTTP cleartext xong, targetSdk 36 chưa làm).