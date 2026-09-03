# Project Context — Smart Clipboard & Text Expander

> Tài liệu tương đối tĩnh. Cập nhật khi có thay đổi lớn về bản chất project.

## Mục đích
**Personal Text Memory — Save Once, Paste Anywhere.** 100% local-first, zero cloud.
Clipboard History là entry point; Text Expander (Snippets + Trigger) là killer feature.
Nền tảng: Android trước (MVP), iOS sau (Phase 3).

## Tech Stack
- **Flutter/Dart** (Android primary)
- **Riverpod** — state management thống nhất toàn app (STRICT RULE 18)
- **SQLite** (`sqflite`, WAL mode) — nguồn sự thật duy nhất
- **File-based sync** — Flutter ↔ IME qua `snippets_cache.json` + `cache_version`
- **AES-256-GCM + PBKDF2** — encrypted backup (passphrase-derived key)
- **Sentry** (`sentry_flutter`) — error monitoring
- **AdMob** (`google_mobile_ads`) — banner + rewarded ads → Pro unlock

## Cấu trúc thư mục chính
```
lib/
├── core/          # constants (AppConfig, AppLimits), database (AppDatabase, migrations),
│                  # native_bridge (MethodChannel), utils (normalizer, entropy, PBKDF2)
├── models/        # ClipboardItem, Snippet, Folder
├── repositories/  # ClipboardRepository, SnippetRepository
├── screens/       # home, clipboard, snippets, playground, settings, onboarding
├── services/      # clipboard, privacy, backup, expansion, metrics, cache_sync,
│                  # auth, entitlement, rewarded_ad, share_intent
├── state/         # providers.dart (Riverpod)
└── widgets/       # banner_ad_widget, lock_gate, save_snippet_dialog
android/           # MainActivity.kt (MethodChannel + SAF picker), IME (VietnameseTelexProcessor.kt)
openspec/          # specs/ (main specs), changes/ (active + archive)
.plan/             # plan1..plan12_final.md (lịch sử kế hoạch/remediation)
```

## Quyết định kiến trúc quan trọng
- **Process boundary**: Flutter App và Android IME là 2 tiến trình độc lập; sync CHỈ qua file trên disk, không chia sẻ RAM.
- **IME không query SQLite** trên hot path — chỉ dùng in-memory HashMap dựng từ file cache.
- **Cache sync**: polling 2–3s khi keyboard visible (technical debt có chủ đích, upgrade FileObserver sau).
- **Backup key**: passphrase-derived qua PBKDF2 ≥100k iterations — KHÔNG hardcode, KHÔNG derive từ device ID.
- **Monetization**: Rewarded Ad → Pro 24h rolling (EntitlementService, `pro_expiry` trong app_meta). Banner ads ẩn khi Pro active.
- **Soft-delete**: vượt Free limit → `is_archived=1`, không xoá vật lý; restore khi mua Pro.
- **AdMob/Sentry** bổ sung sau Master Spec gốc (chấp nhận có network SDK — onboarding claim đã sửa cho khớp thực tế).

## Nguồn tham chiếu
- `smart_clipboard_master_spec.md` — spec gốc (15 Strict Rules)
- `README.md` — quick start + architecture
- `openspec/specs/` — main specs đã archive