# Smart Clipboard — Project-Specific Dev Skill

## General Flutter Android lessons → Xem `flutter-android-ci` + `flutter-android-debug`

---

## Project Overview
Smart Clipboard & Text Expander — Personal Text Memory app built with Flutter.

## Tech Stack
- **Framework**: Flutter 3.24.0
- **State Management**: Riverpod (thống nhất toàn app — STRICT RULE 18)
- **Database**: SQLite (sqflite) with WAL mode
- **Encryption**: AES-256-GCM via `encrypt` package
- **Platform**: Android (primary), Web (limited)

## Repository
- **URL**: `https://github.com/hoangsoft90/SmartClipboard`
- **Branch**: `main`

---

## QUY TẮC PHÁT TRIỂN

1. **KHÔNG build local** — luôn dùng GitHub Actions
2. **Luôn verify trên thiết bị thật** — compile pass ≠ app chạy được
3. **Push to main** → auto build trên GH Actions

## Project Structure
```
lib/
├── core/
│   ├── constants/       # AppLimits, sensitive_patterns
│   ├── database/        # AppDatabase, migrations, MetaDao
│   ├── native_bridge/   # MethodChannel stub (Phase 0)
│   └── utils/           # content_normalizer, entropy, pbkdf2
├── models/              # ClipboardItem, Snippet, Folder
├── repositories/        # ClipboardRepository, SnippetRepository
├── screens/
│   ├── clipboard/       # ClipboardHistoryScreen
│   ├── snippets/        # SnippetsScreen, SnippetEditScreen, FoldersScreen
│   ├── playground/      # PlaygroundScreen (P0 bắt buộc)
│   ├── settings/        # SettingsScreen
│   └── onboarding/      # OnboardingScreen (4 trang)
├── services/            # auth, backup, cache_sync, clipboard,
│                        # expansion_engine, metrics, privacy, share_intent
├── state/               # providers.dart (Riverpod — thống nhất toàn app)
└── widgets/             # lock_gate, privacy_banner, pro_upgrade_banner, save_snippet_dialog
```

## KEY FEATURES (Phase 0)
- Clipboard History with foreground capture (resume-only)
- Snippets & Folders management (free-limit: 15 snippet / 3 folder)
- Expander Playground (type `;trigger` + space → instant expand)
- Sensitive data heuristic (regex + Shannon entropy → score 0/1/2)
- Biometric app lock (local_auth)
- Encrypted backup/restore (AES-256-GCM, PBKDF2 150k iterations)
- Local-only metrics (6 counters, no text content)
- Onboarding 4 trang + MethodChannel stub

## Build Configuration
- **Android SDK**: API 34 (compileSdk), API 23 (minSdk)
- **Java/Kotlin**: JVM target 17
- **Gradle**: 8.3
- **Network**: HTTP cleartext allowed (network_security_config.xml)

## STRICT RULES (Master Spec)
1. Resume-only capture (không background service)
2. No BaaS (firebase, supabase, etc.)
3. WAL mode + migration trong transaction
4. No ads
6. Process boundary: sync chỉ qua file (không shared memory)
7. Zero log nội dung user
8. Local-first
9. Heuristic disclaimer ở mọi điểm chạm
12. PBKDF2 ≥100k iterations cho backup key
13. Cache regen sau MỌI CRUD snippet
14. Trigger prefix `;`, delimiter space, escape `;;`
17. Soft-delete (is_archived=1), KHÔNG xoá vật lý
18. Riverpod thống nhất toàn app
19. Chỉ 9 packages whitelist
20. Playground bắt buộc

## Packages Whitelist
1. flutter_riverpod
2. sqflite
3. path_provider
4. local_auth
5. in_app_purchase
6. encrypt
7. crypto
8. receive_sharing_intent
9. flutter_test (dev)

## Testing
```bash
flutter test
flutter analyze
```

## Quick Reference
```bash
# Push
git add -A && git commit -m "message" && git push origin main

# Check build
curl -s -H "Authorization: token $GH_TOKEN" \
  "https://api.github.com/repos/hoangsoft90/SmartClipboard/actions/runs?per_page=1"

# Debug phone
adb shell am force-stop com.smartclip.smartclipboard
adb logcat -c && adb shell am start -n com.smartclip.smartclipboard/.MainActivity
sleep 3 && adb logcat -d -t 300 | grep -i "flutter\|error"
```
