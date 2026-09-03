# Operating Rules — Smart Clipboard

> Chỉ chứa RULE RIÊNG của project (không lặp lại nội dung AGENTS.md). Rút gọn từ Master Spec §15 — xem đầy đủ trong `smart_clipboard_master_spec.md`.

1. **NO BACKGROUND SPY**: Không Background Service nghe lén clipboard 24/7 — chỉ capture khi app foreground (resume).
2. **NO SERVER SDK**: Không SDK Server/BaaS đẩy nội dung text ra ngoài thiết bị.
3. **WAL MODE**: BẮT BUỘC `PRAGMA journal_mode=WAL` khi init SQLite.
4. **NO INTERSTITIAL**: Không interstitial ads ở bất kỳ luồng nào.
5. **NO SQLITE ON HOT PATH (IME)**: Native IME không query SQLite trên key event — chỉ in-memory HashMap từ file cache.
6. **PROCESS BOUNDARY**: IME và App là 2 tiến trình độc lập; sync CHỈ qua file (`snippets_cache.json` + `cache_version`).
7. **NO LOGGING SENSITIVE DATA**: Clipboard/Snippet/Password/OTP không bao giờ vào Logcat/Analytics/Crashlytics/debug output.
8. **CACHE REGEN**: Sau MỌI CRUD snippet + MỌI migration thành công → gọi `regenerateSnippetCache()`.
9. **TRIGGER RULE**: Snippet expand khi trigger + delimiter (Space/Enter/Tab/`.,!?`); escape `;;`; chỉ xét sau composition Telex/VNI kết thúc.
10. **UTF-16 OFFSET**: Logic xoá trigger tính offset theo UTF-16 code unit — có test với dấu phức tạp + emoji.
11. **SOFT DELETE**: Vượt Free limit → `is_archived=1`, không xoá vật lý; restore khi mua Pro.
12. **STATE MANAGEMENT**: Riverpod thống nhất toàn app, không trộn setState tự do ở màn hình chính.
13. **DEPENDENCY WHITELIST**: Chỉ package trong Master Spec §14 (đã mở rộng: `sentry_flutter`, `google_mobile_ads`). Không tự ý thêm package.
14. **PRIVACY CLAIM**: Onboarding/store text phải khớp thực tế SDK — hiện đã có AdMob + Sentry nên không claim "không có quyền Internet".
15. **AdMob**: `AppConfig.enableAds` kiểm soát init SDK; `testAds=true` dùng test IDs (ca-app-pub-3940...) khi dev; banner ẩn khi Pro active.