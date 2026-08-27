# Smart Clipboard — Development Skill

## Project Overview
Smart Clipboard & Text Expander — Personal Text Memory app built with Flutter.

## Tech Stack
- **Framework**: Flutter 3.24.0
- **State Management**: Riverpod ( thống nhất toàn app — STRICT RULE 18)
- **Database**: SQLite (sqflite) with WAL mode
- **Encryption**: AES-256-GCM via `encrypt` package
- **Platform**: Android (primary), Web (limited)

## Repository
- **URL**: `https://github.com/hoangsoft90/SmartClipboard`
- **Branch**: `main`

---

## QUY TẮC PHÁT TRIỂN (PHẢI TUÂN THỦ)

### 1. KHÔNG BAO GIỜ build local
User nói rõ: "Tuyệt đối ko build apk trên local, xoá hết android dev tools ở local"
→ Luôn dùng GitHub Actions

### 2. Luôn verify trên thiết bị thật
Code compile pass ≠ app chạy được. PHẢI cài APK lên phone + check logcat.

### 3. Debug qua adb
```bash
# Clear log, start app, capture logs
adb shell am force-stop com.smartclip.smartclipboard
adb logcat -c
adb shell am start -n com.smartclip.smartclipboard/.MainActivity
sleep 3
adb logcat -d -t 300 | grep -i "flutter\|error\|exception"
```

---

## CODE PATTERNS (PHẢI LÀM THEO)

### Model classes
- Luôn có `fromMap()`, `toMap()`, `copyWith()`
- Luôn import `package:sqflite/sqflite.dart` nếu dùng `Database` type

```dart
class Snippet {
  // ... fields ...
  
  factory Snippet.fromMap(Map<String, Object?> map) => Snippet(...);
  Map<String, Object?> toMap() => {...};
  
  // BẮT BUỘC có copyWith — thiếu sẽ compile error
  Snippet copyWith({String? id, String? title, ...}) =>
      Snippet(id: id ?? this.id, title: title ?? this.title, ...);
}
```

### SQLite PRAGMA (Android-specific)
```dart
// SAI — crash trên Android sqflite
await db.execute('PRAGMA journal_mode=WAL');

// ĐÚNG — PHẢI dùng rawQuery
await db.rawQuery('PRAGMA journal_mode=WAL');
```

### AsyncValue handling
```dart
// SAI — AsyncValue<int> không phải int
final total = count + snippetArchived;

// ĐÚNG — extract .value trước
final snippetCount = snippetArchived.value ?? 0;
final total = count + snippetCount;
```

### encrypt package — IV constructor
```dart
// SAI
enc.IV.fromBytes(nonce)

// ĐÚNG
enc.IV(nonce)  //接受 Uint8List
```

### AppSettings / State classes
```dart
// SAI — const constructor với List.last không phải constant expression
const AppSettings({this.expirationDays = AppLimits.expirationOptionsDays.last});

// ĐÚNG — dùng factory constructor
const AppSettings._({required this.expirationDays, ...});
factory AppSettings({int? expirationDays, ...}) =>
    AppSettings._(expirationDays: expirationDays ?? 30, ...);

// AppSettingsController: KHÔNG dùng const khi gọi factory
super(const AppSettings())  // SAI — factory không phải const
super(AppSettings())         // ĐÚNG
```

---

## PROJECT STRUCTURE
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
- **Java/Kotlin**: JVM target 17 (CẢ HAI phải match)
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

## Packages Whitelist (mục 14)
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
flutter test          # Chạy test logic thuần
flutter analyze       # Kiểm tra type errors
```

## Common Issues & Fixes

### App crash khi mở trên phone thật
1. Check logcat: `adb logcat | grep flutter`
2. Nguyên nhân hay gặp:
   - PRAGMA SQLite dùng `execute()` thay vì `rawQuery()`
   - Thiếu import `sqflite` → `'Database' isn't a type`
   - AsyncValue không extract `.value` trước khi dùng

### Build fails trên GH Actions
Xem skill `smart-clipboard-build` — có13 bài học chi tiết

### APK không có trong Artifacts
- Check upload paths trong workflow
- `rootProject.buildDir = "../build"` redirect output

---

## QUICK REFERENCE

### Push + Build
```bash
git add -A && git commit -m "message" && git push origin main
```

### Check Build Status
```bash
curl -s -H "Authorization: token $GH_TOKEN" \
  "https://api.github.com/repos/hoangsoft90/SmartClipboard/actions/runs?per_page=1"
```

### Debug on Phone
```bash
adb shell am force-stop com.smartclip.smartclipboard
adb logcat -c && adb shell am start -n com.smartclip.smartclipboard/.MainActivity
sleep 3 && adb logcat -d -t 300 | grep -i "flutter\|error"
```

### Download APK
1. Go to: `https://github.com/hoangsoft90/SmartClipboard/actions`
2. Click latest workflow run → Artifacts → Download
