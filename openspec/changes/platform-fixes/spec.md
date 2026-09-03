# Platform Fixes — Remediation (plan12)

## Overview

Fix 4 known bugs/issues from plan12_final.md:
1. Backup Restore crash (content:// URI)
2. Dedup copy_count not incrementing
3. Pro gate missing (banner ads not gated)
4. Privacy claim mismatch in onboarding

Scope: bug fixes + minimal feature gating. No new features, no IME changes, no Vietnamese/Telex.

---

## 1. Backup Restore — Native content:// URI

### Problem
`ACTION_OPEN_DOCUMENT` returns `content://` URI, but `backup_service.dart` uses `dart:io File(path)` which can't read content:// URIs → crash.

### Fix
Add `copyUriToCacheFile()` in `MainActivity.kt` to copy content:// URI to a real file in cacheDir, return absolute path to Flutter.

### Files
- `android/app/src/main/kotlin/com/smartclip/smartclipboard/MainActivity.kt`

### Scenario
- GIVEN user exported a .scbak backup file
- WHEN user taps Restore and selects the .scbak file
- THEN restore succeeds without crash

---

## 2. Dedup copy_count

### Problem
Dedup branch in `clipboard_repository.dart` updates `last_used_at` and `updated_at` but misses `copy_count` and `is_archived` reset.

### Fix
Use `rawUpdate` with `copy_count = copy_count + 1, is_archived = 0` in dedup branch.

### Files
- `lib/repositories/clipboard_repository.dart`

### Scenario
- GIVEN an item exists in clipboard history
- WHEN user copies same content again
- THEN copy_count increments by 1 and item appears if previously archived

---

## 3. Pro Gate — Hide Banner Ads

### Problem
`BannerAdWidget` is always shown regardless of Pro status. Watching rewarded ad for Pro has no visible benefit.

### Fix
Wrap `BannerAdWidget` in `Consumer` that checks `isProActiveProvider` — hide when Pro active.

### Files
- `lib/screens/home_screen.dart`

### Scenario
- GIVEN Pro is inactive
- WHEN user watches rewarded ad
- THEN banner ads disappear immediately
- GIVEN Pro expires after 24h
- THEN banner ads reappear

---

## 4. Privacy Claim — Onboarding Text

### Problem
Onboarding claims "no internet" but app now has AdMob + Sentry SDK.

### Fix
Update onboarding text to accurately describe: clipboard data stays on device, network used only for ads and error reporting.

### Files
- `lib/screens/onboarding/onboarding_screen.dart`
- `lib/generated/l10n/app_localizations.dart` (l10n keys)

### Scenario
- GIVEN user sees onboarding screen
- WHEN reading privacy claims
- THEN claims match actual app behavior (AdMob + Sentry present)
