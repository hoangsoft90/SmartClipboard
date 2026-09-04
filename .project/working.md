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
- `platform-hardening` — còn dở (Sentry đã xong, HTTP cleartext xong, targetSdk 36 chưa làm).- [2026-09-03] Xong: Tạo `chplay.md` (Play Console listing đầy đủ: App Name 29/30 ký tự, Short Desc 69/80, Full Desc 1723/4000, category Productivity + 5 tags, ý tưởng 4 screenshots, feature graphic + icon idea, checklist App Content).
- [2026-09-03] Xong: Sinh `icon.png` (512x512) từ vector `ic_launcher_foreground.xml` (scripts/generate_play_assets.py, supersample 4x LANCZOS) — pixel-verify: board trắng + sparkle vàng + check xanh đều có.
- [2026-09-03] Xong: Sinh `feature_graphic.png` (1024x500) — gradient brand, headline, 3 feature bullets, icon tile trắng + chip ";email".
- [2026-09-03] Xong: Viết `docs/privacy-policy.html` (song ngữ VI/EN, contact haibasoftware@gmail.com, không nhắc GitHub, khai trung thực AdMob + Sentry + local-first).
- [2026-09-03] Xong: Host privacy policy lên branch `gh-pages` (commit 1b09979, push) — Pages đã bật sẵn cho branch gh-pages → URL live: https://hoangsoft90.github.io/SmartClipboard/ (HTTP 200).
- [2026-09-03] Xong: Viết `docs/user-guide.md` (hướng dẫn sử dụng cho người dùng cuối, tiếng Việt).
- [2026-09-03] Lỗi: JotBird publish chplay.md thất bại — API key trong skill (`~/.agents/skills/jotbird-publish/SKILL.md`) bị "Invalid API key" (hết hạn/revoke). Chờ user cung cấp key hợp lệ hoặc bỏ qua.
- [2026-09-03] Ghi chú: Các file mới (chplay.md, icon.png, feature_graphic.png, docs/, scripts/generate_play_assets.py) chưa commit trên main — chờ user quyết định.
- [2026-09-03] Quyết định user: BỎ QUA JotBird publish (key invalid) — chplay.md dùng trực tiếp từ repo.
- [2026-09-03] Xong: Privacy policy chuyển sang TIẾNG ANH (docs/privacy-policy.html bỏ hẳn section VI) — push gh-pages commit 1bdd44c, verify live: https://hoangsoft90.github.io/SmartClipboard/ HTTP 200, 0 remnant tiếng Việt.
- [2026-09-03] Xong: Tắt ads — `AppConfig.enableAds = false` (AdMob SDK không init, không load ads). Commit 5fd3798, push main.
- [2026-09-04] Xong: BẬT LẠI ads thật — `AppConfig.enableAds = true` + `testAds = false` → dùng real Ad Unit IDs (prod*), không phải Google test IDs.
- [2026-09-04] Xong: Fix lẫn lộn ngôn ngữ en/vi (task lớn, 16 file) — toàn bộ chuỗi UI hardcoded tiếng Việt/Anh chuyển sang l10n:
  - Thêm ~40 key mới vào `app_en.arb` + `app_vi.arb` (snippet edit, privacy banner, onboarding security/OEM/keyboard, playground, settings Pro/theme/colors/lang, backup errors, biometric reason), regenerate `flutter gen-l10n`.
  - `snippet_edit_screen.dart`: validation + delete confirm + appbar "Sửa snippet" + trigger helper → l10n.
  - `privacy_banner.dart`: tooltip heuristic → l10n.
  - `onboarding_screen.dart`: security warning, OEM battery tips, keyboard active/enabled cards, local-first/privacy/no-password → l10n.
  - `playground_screen.dart`: "Tap to switch", "Thử gõ ;email", "Switch" → l10n.
  - `settings_screen.dart`: Pro section (active/locked/watch ad/snackbars), theme picker, color labels, "System" lang, Appearance header → l10n.
  - `backup_service.dart`: `BackupException` giờ mang `BackupErrorCode` enum → settings map sang l10n (thay vì message VN hardcoded hiện lên UI).
  - `auth_service.dart` + `lock_gate.dart`: localizedReason biometric truyền từ l10n.
  - Kết quả: `dart analyze` 0 errors. `backup_crypto_test` (đã sửa theo BackupErrorCode) 9/9 PASS.
  - Ghi chú: 28 test fail khác (clipboard_repository/database/sensitive_flow/privacy_heuristic/content_normalizer/expansion_engine) là PRE-EXISTING trên HEAD — verify bằng git stash, không phải do thay đổi này; CI cũ bỏ qua vì `flutter test --no-pub || true`.
