# Platform Fixes — Tasks

## Task 1: Backup Restore — Native content:// URI Fix
- [x] Add `copyUriToCacheFile(uri)` in `MainActivity.kt`
- [x] Update `filePickerLauncher` callback to use `copyUriToCacheFile` instead of raw URI string
- [x] Verify build compiles — `dart analyze` clean

## Task 2: Dedup copy_count Fix
- [x] Change dedup branch in `clipboard_repository.dart` `save()` method
- [x] Use `rawUpdate` with `copy_count = copy_count + 1, is_archived = 0`
- [x] `dart analyze` clean — no new errors

## Task 3: Pro Gate — Hide Banner Ads
- [x] Wrap `BannerAdWidget` in `Consumer` checking `isProActiveProvider` in `home_screen.dart`
- [x] `dart analyze` clean — no new errors

## Task 4: Privacy Claim — Onboarding Text
- [x] Updated `_IntroPage`: "Nội dung clipboard và snippet KHÔNG BAO GIỜ rời khỏi thiết bị của bạn."
- [x] Updated `_SecurityWarningPage`: clarified network usage (ads + error reporting only)
- [x] Updated password field claim: "Bàn phím không đọc/lưu nội dung ô mật khẩu hệ thống..."
- [x] `dart analyze` clean — no new errors

## Task 5: Release Signing — plan12 mục 3
- [x] `android/app/build.gradle`: add `keystoreProperties` loading from `android/key.properties` (gitignored)
- [x] `signingConfigs.release` reads keyAlias/keyPassword/storeFile/storePassword from key.properties
- [x] `release` buildType: fallback to debug signing when key.properties absent (dev machine), real keystore otherwise
- [ ] **MANUAL (user, NOT agent):** `keytool -genkey -v -keystore ~/smart-clipboard-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias smart_clipboard`
- [ ] **MANUAL (user):** create `android/key.properties` with storePassword/keyPassword/keyAlias/storeFile — never commit
- [ ] Verify: `apksigner verify --print-certs app-release.apk` shows real cert, not Android Debug
