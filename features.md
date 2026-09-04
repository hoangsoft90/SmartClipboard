# Smart Clipboard & Text Expander — Danh sách tính năng & UI

> **App:** Smart Clipboard — "Save Once, Paste Anywhere" · 100% local-first, zero cloud.
> **Stack:** Flutter · Riverpod · SQLite (sqflite, WAL) · AdMob · Sentry · local_auth · AES-256-GCM backup.
> **Ngôn ngữ UI:** Tiếng Việt & English (l10n, ARB) — user tự chọn hoặc theo hệ thống.

---

## 1. Tổng quan luồng app

```
Khởi động
  → Sentry init (error monitoring)
  → MobileAds init (chỉ khi enableAds = true)
  → Open + migrate SQLite (WAL) → regenerate snippet cache
  → RootGate:
      ├─ splash (đang load settings)
      ├─ Onboarding (lần đầu) — 5 trang
      ├─ Biometric Lock (nếu bật) — LockGate
      └─ HomeScreen (4 tab) — Clipboard · Snippets · Playground · Settings
```

**Navigation:** Bottom `NavigationBar` 4 tab (IndexedStack giữ trạng thái mỗi tab).
**Safe Back:** nhấn Back 1 lần → SnackBar "Quay lại"; nhấn lần 2 trong 2s → thoát app.

---

## 2. Màn hình & tính năng theo tab

### 2.1 Tab Clipboard — Lịch sử Clipboard

**Tự động lưu khi app về foreground (resume-only, KHÔNG nghe lén nền):**
- Đọc clipboard hệ thống khi app resume → heuristic phân loại → lưu / dedup / chặn.
- SnackBar "Đã lưu vào lịch sử" khi lưu mới thành công.

**Incognito / Pause Mode (toggle 1 chạm trên AppBar):**
- Dừng ghi lịch sử tức thời; banner đỏ "ĐANG TẠM DỪNG ghi lịch sử clipboard".
- Là giải pháp thật cho niềm tin privacy (không phụ thuộc heuristic).

**Danh sách item (ListView + RefreshIndicator kéo để tải lại):**
- Title = nội dung (max 3 dòng, ellipsis) · Subtitle = thời gian tương đối ("5m ago"), copy_count nếu >1 (icon repeat), content_type (url/email/phone) nếu khác text.
- Leading = PrivacyRiskBadge khi risk score ≥ 1 (tooltip heuristic, chỉ dự đoán).
- **Tap item** → copy lại ra hệ thống clipboard + SnackBar "Đã copy" + tăng copy_count.
- **Trailing buttons:** Pin ⏱ / Favorite ⭐ + PopupMenu (⋯):
  - Pin / Unpin
  - Favorite / Unfavorite
  - Copy lại
  - Lưu thành Snippet (mở dialog tạo snippet, điền sẵn nội dung)
  - Xoá sau 24h (chỉ hiện khi risk score ≥ 1 — gợi ý heuristic)
  - Ẩn khỏi lịch sử (soft-delete archive)
  - Xoá vĩnh viễn

**Tìm kiếm + filter:**
- Search bar (debounce 300ms) — lọc theo nội dung.
- Filter chips: **Tất cả / Yêu thích / Đã ghim** (kết hợp được với search).

**Auto-Expiration Engine (P0):**
- Mỗi item mới được gán `expires_at` theo setting (1/7/30 ngày, mặc định 30).
- Khi load danh sách: item hết hạn bị **xoá vật lý tự động** (pinned được miễn).
- Thay đổi setting chỉ áp dụng cho item MỚI (item cũ giữ nguyên expiration).

**Dialog "Nội dung có thể nhạy cảm ⚠️" (heuristic score = 2):**
- Khi clipboard trông giống OTP/password/API key → chặn tự lưu, hỏi user:
  - "Không lưu" → bỏ qua hoàn toàn.
  - "Lưu & xoá sau 24h" → lưu với expires_at = now + 24h.

**ProUpgradeBanner:** placeholder hiện tại render `SizedBox.shrink()` (Free limits đã gỡ, sẽ dùng lại khi Pro Rewarded Ad hoàn thiện).

### 2.2 Tab Snippets — Gõ tắt (Text Expander)

**Danh sách snippet:**
- Title = tên snippet · Subtitle = `;trigger` (monospace) · trailing = usage_count + PopupMenu.
- PopupMenu (⋯): **Bật/Tắt** · **Sửa** (mở SnippetEditScreen) · **Xoá** (soft-delete archive).
- Search bar (debounce 300ms) — lọc theo title / trigger / content.
- Filter chips: **Tất cả / Đang bật / Đã tắt**.
- FAB "+ Snippet mới" → SnippetEditScreen.

**SnippetEditScreen (tạo / sửa):**
- Fields: Tên (tuỳ chọn — tự lấy trigger nếu bỏ trống) · Trigger (không space/dấu câu — validate inline) · Nội dung (multiline) · Folder (tuỳ chọn dropdown).
- Trigger field: prefix `;` cố định, helperText "Gõ ;trigger + dấu cách để mở rộng", input formatter chặn khoảng trắng.
- PopScope: thoát khi chưa lưu → dialog "Thoát without saving?" (Ở lại / Thoát).
- Nút Lưu → SnackBar "Đã tạo snippet ;trigger" (hoặc "Đã tạo snippet. N bị ẩn..." khi vượt Free limit).
- Nút Xoá (chỉ khi sửa) → dialog xác nhận "Xoá snippet này? Không thể hoàn tác."

**Folders (quản lý thư mục):**
- Icon folder trên AppBar Snippets → FoldersScreen.
- Danh sách folder → PopupMenu: **Đổi tên** / **Xoá** (snippet trong folder bị xoá → folder_id về NULL, dữ liệu giữ nguyên).
- FAB "+ Folder mới" → dialog nhập tên.
- Folder gán cho snippet qua dropdown "Folder (tuỳ chọn)" ở edit screen & dialog tạo nhanh.

**Tạo snippet nhanh từ Clipboard:** Popup "Lưu thành Snippet" → SaveSnippetDialog (title, trigger với prefix `;`, content điền sẵn, folder optional).

### 2.3 Tab Playground — Thử Expansion Engine (trong app)

- TextField multiline — gõ `;trigger` + Space/Enter/Tab/dấu câu (. , ! ?) → tự thay thành nội dung snippet.
- **Escape:** `;;email` → xuất ra `;email` (không expand).
- Card kết quả: "Đã mở rộng {trigger}" + nút copy kết quả → SnackBar "Đã copy".
- Card trạng thái keyboard:
  - **Disabled:** "💡 Bật keyboard Smart Clipboard..." + nút Bật → mở Settings IME hệ thống.
  - **EnabledNotActive:** "Bàn phím đã bật — chạm để chuyển" + nút Switch → mở IME picker.
  - **Active:** "Bàn phím Smart Clipboard đã bật — thử gõ ;email + Space ở Telegram" (không nút).
- Hint về prefix mặc định `;` (Pro: cho phép đổi — chưa implement).
- Empty state: hướng dẫn tạo snippet trước.
- Expansion chỉ hoạt động trên snippet **enabled + không archived**; đếm usage_count + metrics local.

### 2.4 Tab Settings — Cài đặt

**Logging (Ghi lịch sử):**
- Switch "Tạm dừng ghi Clipboard History" (Incognito/Pause Mode).
- "Tự xoá lịch sử sau" — dropdown **1 / 7 / 30 ngày**.

**Security (Bảo mật):**
- Switch "Khoá app bằng sinh trắc học" (fingerprint/face — kiểm tra thiết bị hỗ trợ trước khi bật; SnackBar nếu không hỗ trợ).
- Mục "Phát hiện dữ liệu nhạy cảm" — giải thích CHỈ heuristic (regex + entropy), không phải bảo đảm bảo mật.

**Pro (Rewarded Ad):**
- **Đang Pro:** "✨ Pro Active" + "Khả dụng đến HH:MM" (rolling 24h).
- **Chưa Pro:** "✨ Unlock Pro for today" + "Xem một quảng cáo ngắn..." + nút **Watch Ad**.
  - Xem xong → SnackBar "✨ Pro unlocked for 24 hours!"; fail → "Ad failed to load...".
  - Khi Pro active: **banner ads trên Home ẩn** (Pro gate).

**Backup & Restore (Sao lưu mã hoá AES-256-GCM):**
- **Export:** dialog nhập passphrase (≥8 ký tự) → mã hoá toàn bộ DB (folders, snippets kể cả archived, clipboard_items) → file `.scbak` → mở **Share Sheet Android** để lưu/chia sẻ.
  - Key = PBKDF2-HMAC-SHA256 (150k iterations, salt ngẫu nhiên) — quên passphrase = không restore được.
- **Restore:** mở **SAF File Picker** (content:// → copy sang cacheDir để dart:io đọc — đã fix) → dialog xác nhận path + passphrase → giải mã → thay thế toàn bộ data → regenerate cache + reload mọi list.
  - Lỗi được localize theo mã (file không tồn tại, sai format, sai passphrase, KDF invalid...).

**Language (Ngôn ngữ):**
- Dropdown: **🌐 System / Tiếng Việt / English** — lưu `app_language` trong DB, MaterialApp locale phản ứng tức thì.

**Appearance (Giao diện):**
- Theme: **System / Light / Dark** (RadioListTile) — lưu + sync vào snippet cache cho IME.
- **Màu nền bàn phím:** 4 preset swatch (White / Gray / Blue / Black) — sync cho native IME.

**Statistics (local only):**
- Chips: Snippets đã tạo · Lần mở rộng · Clipboard đã lưu · Clipboard tái dùng · Playground expansions · Ngày active.
- Dòng metric Go Phase 1: "Mở rộng / ngày active ≥ 1 → thói quen hình thành".
- **KHÔNG chứa nội dung text user** (chỉ counter).

---

## 3. Onboarding (lần đầu mở app — 5 trang, swipe + nút Tiếp theo/Bỏ qua)

1. **Smart Clipboard** — "Lưu một lần. Dán ở bất cứ đâu." + 100% Local-first (nội dung KHÔNG bao giờ rời thiết bị).
2. **Bật bàn phím** — hướng dẫn bật IME; card trạng thái (amber/orange/green) theo trạng thái keyboard; nút bật/chuyển IME.
3. **Cảnh báo bảo mật Android** — giải thích cảnh báo hệ thống cho mọi IME + claim privacy thật (mạng chỉ cho ads + error reporting ẩn danh) + "Bàn phím không đọc/lưu ô mật khẩu hệ thống".
4. **Mẹo máy Xiaomi/Oppo/Samsung** — hướng dẫn gỡ giới hạn pin (MIUI/ColorOS/One UI) cho IME.
5. **Chia sẻ (Share Sheet)** — "Bảo mật trước tiên" — gửi text từ app khác vào Smart Clipboard.

---

## 4. Tính năng xuyên tab / toàn app

### 4.1 Share Intent (nhận text từ app khác)
- Manifest intent-filter `ACTION_SEND` text/plain → chọn "Smart Clipboard" trong sharesheet.
- Bottom sheet: **"Nhận text được chia sẻ (N ký tự)"** + 2 hành động:
  - **Lưu vào lịch sử Clipboard** (force-save, bỏ qua pause).
  - **Tạo Snippet với trigger** (mở SaveSnippetDialog, content điền sẵn).

### 4.2 Keyboard Enable Banner (Home)
- Banner đầu màn hình khi keyboard chưa active: trạng thái disabled (đỏ) / enabled-not-active (vàng) → tap mở Settings IME hoặc IME picker; nút ✕ để đóng (1 session).

### 4.3 Native IME — SmartClipboardIME (Phase 1 prototype, Kotlin)
> Bàn phím hệ thống riêng, chạy trong process độc lập; sync qua file `snippets_cache.json` (poll cache_version mỗi 3s).

- **Text expansion thật trong mọi app:** gõ `;trigger` + Space/Enter/Tab → thay bằng nội dung snippet; escape `;;` → `;`.
- Suggestion strip hiển thị 5 trigger khớp tiền tố (tap → commit **content**).
- Quick toolbar: `;` `@` `.com` · 😀 emoji tray (50 emoji phổ biến) · 🌐 switch keyboard.
- Hành vi gõ thông minh: auto-capitalize sau `. ! ? \n`, double-space → ". ", key preview popup, backspace xử lý selection đúng.
- **Password field guard:** không expand, gõ thẳng (không lưu nội dung).
- Chỉ hiện cho text/number/phone/datetime fields (guard PLAN 11 P0-1).
- **Language:** hiện cố định EN (VI Telex đã freeze — code giữ enum nhưng không dùng).
- Theme sync từ app (dark/light theo `app_theme_mode`) + màu nền keyboard từ setting.
- Đọc cache `snippets_cache.json` (triggers, keyboard_bg_color, app_theme_mode); lỗi cache → empty state, không crash.

### 4.4 Biometric App Lock (LockGate)
- Bật trong Settings → mở app yêu cầu xác thực fingerprint/face trước khi vào.
- Re-lock khi app về background (lifecycle observer).
- Reason dialog localize theo ngôn ngữ app.

### 4.5 Metrics local-only (mục tiêu Go Phase 1)
- Counter: snippets created, expansions, clipboard saved/reused, playground expansions, active days — lưu trong `app_meta`, không bao giờ chứa nội dung text, không đồng bộ đi đâu.

---

## 5. Monetization (AdMob)

| Mục | Trạng thái | Ghi chú |
|---|---|---|
| Banner ad (Home, bottom) | ✅ BẬT | `enableAds = true` — ẩn khi Pro active (Consumer + isProActiveProvider) |
| Rewarded Ad → Pro 24h | ✅ BẬT | `RewardedAdService.showAd` → `entitlement.unlockFromRewardedAd()` (rolling 24h) |
| Test/Real ad unit | 🔴 **REAL** | `testAds = false` → dùng prod IDs (`ca-app-pub-6917313063209470/...`) |
| AdMob App ID (manifest) | ⚠️ Test ID | Manifest value là `ca-app-pub-3940256099942544~3347511713` (test) — cần đổi sang prod `~4788568410` khi release |
| Interstitial | 📦 Có ID nhưng chưa dùng | `prodInterstitialAdUnitId` tồn tại trong AppConfig |
| Free limits / ProUpgradeBanner | 🔄 Đã gỡ (Plan 11 P0-2) | migration v2 unarchive tất cả; banner placeholder shrink |

**Pro (EntitlementService):**
- Trạng thái = `pro_expiry` (UTC epoch) trong `app_meta` — rolling 24h từ lúc xem ad.
- `isProActiveProvider` → ẩn banner ad trên Home; Settings hiển thị "Pro Active" + thời gian hết hạn.
- **Chưa gate bất kỳ tính năng nào** (Free limits đã gỡ — remediation mục 4 plan12).

---

## 6. Privacy & Data (local-first)

- **100% local-first:** SQLite là nguồn sự thật duy nhất; KHÔNG cloud, KHÔNG đồng bộ dữ liệu user.
- **KHÔNG background spy:** chỉ đọc clipboard khi app resume (STRICT RULE 1).
- **Heuristic nhạy cảm (score 0/1/2):** regex (OTP/API key/số thẻ/GitHub token/AWS...) + Shannon entropy + char class → gợi ý xoá 24h / chặn lưu. Chỉ là *gợi ý*, không phải bảo đảm bảo mật.
- **Auto-expiration:** item mới tự xoá sau 1/7/30 ngày (pinned miễn).
- **Backup mã hoá:** AES-256-GCM + PBKDF2 150k iterations, passphrase user tự đặt.
- **Permissions Android:** INTERNET (AdMob + Sentry), ACCESS_NETWORK_STATE, USE_BIOMETRIC/USE_FINGERPRINT. Không có background clipboard service (Phase 0).
- **Error monitoring:** Sentry (DSN) — tracesSampleRate = 0.

---

## 7. Kiến trúc kỹ thuật (tóm tắt)

- **State:** Riverpod thống nhất — `StateNotifierProvider` cho settings/lists/locale/theme, `FutureProvider` cho Pro/keyboard status, `Provider` phái sinh cho filter/visible items.
- **DB:** SQLite WAL, migration versioned (hiện v2), bảng: `clipboard_items`, `snippets`, `folders`, `app_meta`.
- **Dedup clipboard:** `content_hash` (SHA256 normalize) — trùng hash → UPDATE `copy_count+1` + unarchive, không insert mới.
- **Soft-delete:** archive (ẩn) thay vì xoá vật lý (trừ purgeExpired tự động + user chọn xoá vĩnh viễn).
- **Cache sync cho IME:** file `snippets_cache.json` + `cache_version` monotonic — regenerate sau mọi CRUD snippet & migration.
- **Native bridge:** MethodChannel `smart_clipboard/native_bridge` — keyboard check/settings/picker, SAF file picker, share file.
- **L10n:** ARB en/vi, `flutter gen-l10n`, ~150+ keys.
- **Nền tảng hỗ trợ:** Android chính (IME native); Web: các feature hệ thống tự disable an toàn (share intent, biometric, backup, cache file, clipboard capture).

---

## 8. Điểm cần lưu ý / việc chưa xong

1. **AdMob App ID trong manifest vẫn là test ID** — đổi thành `ca-app-pub-6917313063209470~4788568410` khi release thật.
2. **Pro chưa gate tính năng** nào (Free limits đã bỏ) — chỉ ẩn banner ad.
3. **IME Vietnamese Telex bị freeze** (EN-only) — enum còn nhưng không dùng.
4. **ProUpgradeBanner** placeholder (shrink) — sẽ dùng lại khi cần upsell.
5. **Prefix trigger `;` cố định** (Pro: cho phép đổi — chưa implement).
6. **28 test fail pre-existing** — thiếu `sqfliteFfiInit()` trong 6 test file (CI cũ dùng `--no-pub || true` nên không phát hiện).
7. Release signing đã cấu hình (keystore + GH secrets) — build release AAB signed.