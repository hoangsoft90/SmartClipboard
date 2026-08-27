# Smart Clipboard & Text Expander — MASTER SPEC (FINAL v1.0)
### "Personal Text Memory: Save Once, Paste Anywhere"

> Tài liệu này là bản tổng hợp cuối cùng, gộp `plan1_final.md` + 6 vòng phản biện độc lập
> (`review1`–`review6`). Đây là bản **duy nhất** cần đưa cho AI Coding Agent — không cần
> đọc lại các file review gốc. Mọi mâu thuẫn giữa các review đã được xử lý và chốt quyết định
> ở đây (xem mục 11 — Quyết định thay cho tranh luận).

---

## 0. Tóm tắt định vị sản phẩm

- **KHÔNG PHẢI**: "Clipboard Manager" nghe lén clipboard nền 24/7 (bất khả thi trên Android 10+/iOS 16+).
- **LÀ**: **Personal Text Memory** — Text Expander (Snippets + Trigger) là killer feature & moat.
  Clipboard History là entry point / discovery tool, không phải core value.
- **Luồng giá trị**: Clipboard History (khám phá text hữu ích) → Lưu thành Snippet → Gán Trigger →
  Dùng lại nhiều lần → Text Expansion trở thành **habit loop** = retention + monetization thật sự.
- **Kiến trúc**: 100% Local-first. Không backend, không cloud, không thu thập nội dung.
- **Nền tảng**: Android trước (MVP), iOS sau (Phase 3, không nằm trong MVP).

---

## 1. Kiến trúc tổng thể (đã sửa theo phản biện Critical)

```
                             SMART CLIPBOARD
                                   │
                  ┌────────────────┼────────────────┐
                  │                │                │
                  ▼                ▼                ▼
            Clipboard         Snippets          Text Expander
             History           Manager           (In-App)
                  │                │                │
                  └───────────────┬────────────────┘
                                  ▼
                          SQLite (WAL mode)
                        [Flutter App process]
                                  │
                                  ▼
                          Privacy/Sanitizer Engine
                                  │
                                  ▼
                   regenerateSnippetCache() → snippets_cache.json
                        (file trên disk, KHÔNG phải RAM chung)
                                  │
                          ═══════ process boundary ═══════
                                  │
                                  ▼
                    [Android IME process — Kotlin]
                     Đọc file cache → tự dựng HashMap
                          riêng của process này
                                  │
                                  ▼
                   Trigger lookup O(1) trên RAM, KHÔNG query DB
```

### 1.1. ⚠️ Nguyên tắc nền tảng bắt buộc hiểu đúng: Process Boundary

**Flutter App và Native IME là HAI TIẾN TRÌNH HỆ ĐIỀU HÀNH HOÀN TOÀN ĐỘC LẬP** (trừ khi khai
báo chung `android:process`, điều này **không được làm** vì lý do ổn định — 1 process crash
không được kéo process kia sập theo).

Hệ quả: **không có chuyện "chia sẻ chung một object HashMap trong RAM"**. Mỗi process tự đọc
file cache trên disk và **tự dựng HashMap của riêng mình**. Đồng bộ hai bên **chỉ được thực hiện
qua file trên disk** (JSON nhỏ) — không qua static object, không qua Dart isolate chia sẻ,
không qua bất kỳ cơ chế in-memory IPC nào khác trong MVP.

> **STRICT RULE**: Không được viết code giả định rằng object Dart hoặc Kotlin nào đó tồn tại
> chung giữa Flutter App process và IME process. Đồng bộ chỉ qua file (`snippets_cache.json`)
> + `cache_version` marker.

### 1.2. Native IME TUYỆT ĐỐI KHÔNG query SQLite trên hot path

Bàn phím cần độ trễ dưới **16ms/keystroke**. Query SQLite (dù có WAL) trên mỗi lần bấm phím
sẽ gây lag/giật. Rule:

```
Flutter App ──(CRUD)──> SQLite ──(serialize)──> snippets_cache.json (+ cache_version)
                                                          │
                                     Android IME process đọc file này
                                     → dựng HashMap<String,String> riêng trong RAM
                                     → lookup trigger = O(1), zero-latency
```

### 1.3. Cơ chế đồng bộ cache (Cache Sync) — chi tiết kỹ thuật bắt buộc

**Vấn đề cần giải quyết**: IME chỉ load cache 1 lần lúc khởi tạo → user tạo snippet mới
nhưng IME không biết → UX tệ.

**Giải pháp MVP (đã chốt)**:

1. Sau **mọi thao tác CRUD snippet** hoặc **hoàn tất migration schema**, Flutter App phải gọi
   `regenerateSnippetCache()`:
   - Ghi đè file `snippets_cache.json` (JSON nhỏ, vài KB) chứa toàn bộ `trigger → content` đang
     `is_enabled = 1`.
   - Cập nhật `cache_version` (long timestamp hoặc integer tăng dần) vào file meta riêng hoặc
     `SharedPreferences`.
2. Native IME:
   - Load cache lúc `onStartInput` / `onStartInputView`.
   - Trong lúc bàn phím đang **hiển thị** (visible), dùng `Handler` poll `cache_version` mỗi
     **2–3 giây** — **CHỈ khi visible**, không poll khi ẩn (tiết kiệm pin/CPU).
   - Nếu `cache_version` thay đổi → reload lại toàn bộ HashMap (đọc file JSON nhỏ, < 1ms).
3. **Fallback an toàn**: Nếu file cache không tồn tại / parse lỗi → IME hoạt động ở trạng thái
   `no snippets` (bàn phím bình thường, không suggestion), **tuyệt đối không crash**.

> **Ghi chú kỹ thuật nợ (technical debt có chủ đích)**: Polling 2–3s là giải pháp chấp nhận được
> cho MVP, KHÔNG phải kiến trúc tối ưu cuối cùng. Phiên bản sau nên thay bằng
> `FileObserver` (Android API lắng nghe sự kiện ghi file, trigger reload gần như tức thời,
> không tốn CPU liên tục) hoặc `ContentObserver` nếu expose qua ContentProvider. Agent
> **không được coi polling là thiết kế cuối cùng đã tối ưu** khi viết comment/doc trong code.

---

## 2. SQLite Data Schema (Production-Ready, đã chốt)

```sql
PRAGMA journal_mode=WAL;

-- 1. Bảng Lịch sử Clipboard
CREATE TABLE clipboard_items (
    id TEXT PRIMARY KEY,
    content TEXT NOT NULL,
    content_hash TEXT NOT NULL,           -- SHA256(normalize(content)) — dùng để Deduplicate
    content_type TEXT DEFAULT 'text',     -- 'text','url','email','phone','sensitive'
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    last_used_at INTEGER,
    copy_count INTEGER DEFAULT 1,         -- tần suất tái sử dụng (trùng hash → +1)
    is_pinned INTEGER DEFAULT 0,
    is_favorite INTEGER DEFAULT 0,
    privacy_risk_score INTEGER DEFAULT 0, -- 0: An toàn, 1: Nghi vấn, 2: Rủi ro cao (heuristic only)
    is_archived INTEGER DEFAULT 0,        -- soft-delete khi vượt Free limit (KHÔNG xoá vật lý)
    source_app TEXT,                      -- metadata thông tin, không phải security boundary
    expires_at INTEGER
);
CREATE UNIQUE INDEX idx_clipboard_hash ON clipboard_items(content_hash);
CREATE INDEX idx_clipboard_created ON clipboard_items(created_at);
CREATE INDEX idx_clipboard_pinned ON clipboard_items(is_pinned);
CREATE INDEX idx_clipboard_archived ON clipboard_items(is_archived);

-- 2. Bảng Snippets (Gõ tắt)
CREATE TABLE snippets (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    trigger TEXT UNIQUE NOT NULL,         -- vd: ;email
    content TEXT NOT NULL,
    prefix TEXT DEFAULT ';',              -- tiền tố (Pro: cho phép đổi)
    folder_id TEXT,
    is_enabled INTEGER DEFAULT 1,
    is_archived INTEGER DEFAULT 0,        -- soft-delete khi vượt Free limit
    usage_count INTEGER DEFAULT 0,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    FOREIGN KEY (folder_id) REFERENCES folders(id) ON DELETE SET NULL
);
CREATE INDEX idx_snippet_trigger ON snippets(trigger);
CREATE INDEX idx_snippet_archived ON snippets(is_archived);

-- 3. Bảng Folders
CREATE TABLE folders (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    icon TEXT,
    created_at INTEGER NOT NULL
);

-- 4. Meta bảng lưu cache_version (đơn giản hoá thay vì file riêng, tuỳ chọn triển khai)
CREATE TABLE app_meta (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);
-- ví dụ row: ('cache_version', '1735300000000')
```

### 2.1. Content Hash — bắt buộc Normalize trước khi hash

```dart
String normalizeContent(String raw) {
  return raw
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ')     // collapse whitespace thừa
      .normalize();                         // Unicode NFC — bắt buộc để é (single) == é (combining)
}

String contentHash(String raw) =>
    sha256.convert(utf8.encode(normalizeContent(raw))).toString();
```

Deduplication logic khi copy:
```
IF content_hash đã tồn tại
    → UPDATE last_used_at = now, copy_count = copy_count + 1
ELSE
    → INSERT bản ghi mới
```

### 2.2. Schema Migration — Quy trình bắt buộc

> **STRICT RULE**: Mỗi khi app khởi động và phát hiện version DB cũ hơn, phải chạy migration
> theo transaction. **Nếu migration fail → app KHÔNG được cho phép IME hoạt động với cache cũ/
> không hợp lệ.** Sau khi migration **thành công**, bắt buộc gọi `regenerateSnippetCache()`
> ngay lập tức trước khi coi app "sẵn sàng". Nếu cache file không hợp lệ, IME phải fallback về
> empty state (mục 1.3).

---

## 3. Flutter Project Structure

```
lib/
├── main.dart
├── core/
│   ├── database/              # SQLite Helper (WAL), migration runner
│   ├── native_bridge/         # MethodChannel: isKeyboardEnabled(), openKeyboardSettings(),
│   │                          #   regenerateSnippetCache()
│   ├── constants/              # Regex OTP/thẻ/API key patterns
│   └── utils/                  # normalizeContent(), entropy checker, AES-GCM helper
├── models/
│   ├── clipboard_item.dart
│   ├── snippet.dart
│   └── folder.dart
├── repositories/
│   ├── clipboard_repository.dart
│   └── snippet_repository.dart
├── services/
│   ├── clipboard_service.dart      # Foreground capture only
│   ├── expansion_service.dart      # In-app expansion engine
│   ├── privacy_service.dart        # Sensitive heuristic + expiration
│   └── cache_sync_service.dart     # regenerateSnippetCache()
├── screens/
│   ├── home_screen.dart
│   ├── clipboard/
│   ├── snippets/
│   ├── playground/              # ✨ Expander Playground — P0 bắt buộc, xem mục 6
│   ├── settings/
│   └── onboarding/
├── widgets/
└── state/                        # Riverpod (chốt cứng — xem mục 8)
```

---

## 4. Native IME Kiến trúc chi tiết (Android — Kotlin)

### 4.1. Phạm vi Phase 1 Prototype (2–4 ngày)

**CHỈ làm**: `InputMethodService` tối giản, Candidate/Suggestion strip nhỏ, trigger detection,
`commitText()` replacement. **KHÔNG** viết lại full QWERTY keyboard layout, không autocorrect,
không emoji picker riêng — IME nên **kế thừa/pass-through** hành vi gõ bình thường của hệ thống
nhiều nhất có thể trong scope prototype; mục tiêu duy nhất của Phase 1 là chứng minh:

> "Can Android IME intercept/replace a trigger reliably across common apps mà không phá vỡ
> trải nghiệm gõ tiếng Việt?"

### 4.2. Trigger / Delimiter / Escape — Rule chính thức (đã chốt)

| Hành vi | Quy tắc |
|---|---|
| Prefix mặc định | `;` (Pro: cho phép đổi trong Settings) |
| Kích hoạt expansion | Trigger phải theo sau bởi **delimiter**: `Space`, `Enter`, `Tab`, hoặc dấu câu `. , ! ?` |
| Ví dụ | Gõ `;email` (chưa có dấu cách) → chưa thay thế. Gõ `;email ` (có space) → xoá `;email`, insert nội dung |
| Escape | Gõ `;;email` → xuất ra một `;` duy nhất, bỏ qua expansion, giữ nguyên text thô |
| Instant mode (expand ngay không cần delimiter) | **KHÔNG làm ở MVP** — dễ false-trigger (vd phá `user@email.com`) |
| Composition | IME phải bỏ qua các ký tự đang trong trạng thái pre-edit/composition (vd đang gõ `a`+`a`→`â`); trigger chỉ được xét **sau khi composition kết thúc** |

### 4.3. ⚠️ Edge case bắt buộc xử lý: UTF-16 offset khi xoá/thay text có dấu

`InputConnection.deleteSurroundingText(before, after)` trên Android tính offset theo
**UTF-16 code unit**, không phải theo "ký tự hiển thị". Một số emoji (surrogate pair) hoặc tổ
hợp dấu tiếng Việt phức tạp có thể khiến việc tính `length` theo kiểu ngây thơ (String.length)
xoá lệch ký tự khi có ký tự đặc biệt/emoji ở gần trigger.

> **STRICT RULE**: Logic xoá trigger trước khi insert nội dung PHẢI tính offset theo UTF-16 code
> unit chính xác, có test case cụ thể: gõ trigger ngay sau một từ có dấu phức tạp
> (`đường;email `) và ngay sau emoji (`😀;email `) — đảm bảo không xoá lệch/để sót ký tự.

### 4.4. Go / No-Go Gate — Phase 1 (chỉ chuyển Phase 2 nếu 100% đạt)

```
□ Keystroke latency < 16ms (không giật/khựng phím)
□ Trigger + delimiter thay thế chính xác
□ Escape ;; hoạt động đúng
□ Không phá bộ gõ tiếng Việt Telex/VNI (aa→â, aw→ă, dd→đ) — trigger chỉ xét
  sau khi composition kết thúc
□ Test case UTF-16 offset: trigger sau từ có dấu phức tạp + sau emoji không lệch ký tự
□ Không crash khi chuyển đổi giữa các app khác nhau (Chrome, Gmail, Messenger, Telegram, Slack)
□ RAM tiêu thụ của IME process < 25MB
□ Password field (inputType = TYPE_TEXT_VARIATION_PASSWORD) → tự động ẩn candidate
  bar/suggestion hoàn toàn, không track nội dung
□ Native IME KHÔNG query SQLite trên bất kỳ onKey event nào (chỉ đọc HashMap RAM)
```

Nếu **fail bất kỳ mục nào** → **No-Go**. Quay lại đầu tư In-App Extensions & UX
(Share Sheet, Quick Action, Widgets), release bản In-App Utility, không tiếp tục Phase 2.

---

## 5. Bảo mật, Riêng tư & Key Management

### 5.1. Sensitive Data — chỉ là Heuristic, KHÔNG phải Security Guarantee

- Dùng kết hợp **Regex** (OTP 6 số, thẻ ngân hàng, pattern API key) + **Entropy Score**
  (chuỗi biến thiên cao → khả năng là password/seed phrase/API key).
- Output là `privacy_risk_score` (0/1/2), **không gắn nhãn cứng "Đây là Password"** — entropy
  cao cũng có thể là random ID/hash hợp lệ, không phải chỉ có sensitive data.
- Nếu score ≥ 1 → banner gợi ý: *"Văn bản này có thể chứa thông tin nhạy cảm. Tự động xoá sau
  24h?"* Mặc định **KHÔNG tự lưu** vào history nếu nghi vấn cao (score = 2), trừ khi user xác
  nhận lưu → tự động bật **Burn After Paste** (P1).
- **STRICT RULE**: Không được marketing/quảng cáo tính năng này như "bảo mật tuyệt đối" ở bất
  kỳ đâu trong UI, Store listing, hay code comment.

### 5.2. Incognito / Pause Mode (P0 bắt buộc)

Cho phép user tạm dừng ghi Clipboard History (toggle 1 chạm) — giải pháp UX thực tế để tạo
niềm tin, quan trọng hơn việc cố "đoán đúng" dữ liệu nhạy cảm bằng heuristic.

### 5.3. Backup Encryption — Key Management (chốt phương án, không để agent tự chọn)

Tất cả review đều yêu cầu AES-256-GCM nhưng **không ai trả lời khoá lấy từ đâu** — đây là lỗ
hổng thật sự nếu bỏ trống (agent AI có xu hướng chọn giải pháp yếu: derive key từ device ID,
hoặc lưu key plaintext cạnh file backup).

> **QUYẾT ĐỊNH CHO MVP — Phương án A (bắt buộc)**:
> Khoá mã hoá được **derive từ passphrase do user tự nhập lúc export**, qua **PBKDF2**
> (tối thiểu 100.000 iterations) hoặc **Argon2** — **KHÔNG dùng MD5/SHA1 trực tiếp làm key**.
> Salt ngẫu nhiên lưu cùng file backup (không phải bí mật). User phải nhớ passphrase này để
> restore — đây là trade-off UX chấp nhận được và nhất quán với positioning "privacy-first".
> AES-256-GCM dùng nonce ngẫu nhiên cho mỗi lần export, không tái sử dụng.
>
> *(Phương án B — key sinh ngẫu nhiên lưu Android Keystore/iOS Keychain — bị loại cho MVP vì
> chỉ restore được trên cùng thiết bị, mất khả năng chuyển máy; có thể cân nhắc lại cho bản Pro
> nâng cao sau này, không phải bây giờ.)*

### 5.4. Strict Privacy Rules (tổng hợp, áp dụng toàn bộ codebase)

1. **KHÔNG** tạo Background Service chạy ngầm 24/7 nghe lén Clipboard.
2. **KHÔNG** tích hợp SDK Server/BaaS nào (Firebase DB, Supabase...) để đẩy nội dung text
   ra ngoài thiết bị.
3. Nội dung Clipboard, Snippets, Password, OTP **TUYỆT ĐỐI KHÔNG** được ghi vào Logcat,
   Analytics, Crashlytics, notification, hay bất kỳ debug output nào — dưới mọi hình thức,
   kể cả khi debug build.
4. App là **Local-First 100%**: không khởi tạo bất kỳ network request nào ngoài SDK xác thực
   In-App Purchase của Google Play/App Store.
5. Native IME **KHÔNG ĐƯỢC** query SQLite trên bất kỳ key event nào — chỉ dùng in-memory
   HashMap (mục 1.2).

---

## 6. Expander Playground (P0 bắt buộc — không phải optional)

**Vấn đề**: Nếu Phase 0 chỉ có danh sách snippet + nút Copy thủ công, user sẽ không có
**"Aha Moment"** — họ sẽ nghĩ đây chỉ là notepad có tiền tố lạ, không thấy giá trị thật.

**Giải pháp**: Màn hình riêng trong app, ngay Phase 0:

```
┌─────────────────────────────────────────┐
│  ✨ Smart Expander Playground            │
│  ┌─────────────────────────────────────┐ │
│  │  Nhập trigger (vd: ;email) ...       │ │
│  └─────────────────────────────────────┘ │
│  Kết quả:                                │
│  ┌─────────────────────────────────────┐ │
│  │  contact@company.com     [Copy]      │ │
│  └─────────────────────────────────────┘ │
│  💡 Bật keyboard Smart Clipboard để       │
│     dùng ngay trên mọi ứng dụng!          │
└─────────────────────────────────────────┘
```

- User gõ `;email` + Space trong text field lớn → thấy expansion **ngay lập tức**, không cần
  cài keyboard.
- Đây là công cụ onboarding mạnh nhất và cũng là công cụ đo product-market fit sớm nhất
  (`playground_expansions` — xem mục 10 Metrics).
- Banner CTA nhẹ nhàng mời bật system keyboard, không spam.

---

## 7. Onboarding & Fallback Mode (nâng thành first-class, không phải fallback tạm bợ)

```
[Mở App Lần Đầu]
       │
       ▼
 Màn hình 1: Giới thiệu "Personal Text Memory" & cam kết 100% Privacy
       │
       ▼
 Màn hình 2: Hướng dẫn bật System Keyboard
       ├─ Bấm "Enable Keyboard" → mở Intent Settings Android trực tiếp
       │        │
       │        ▼
       │   App kiểm tra IME status qua MethodChannel isKeyboardEnabled()
       │        ├── SUCCESS: đã bật
       │        └── FAIL/REFUSE: chuyển Fallback
       ▼
 [Fallback = Share Sheet Integration]
```

- **KHÔNG dùng Floating Widget** trong MVP (rủi ro permission + policy Play Store cao, review
  đồng thuận loại bỏ).
- **Ưu tiên Android Sharesheet / iOS Share Extension**: user Share text từ Chrome/Gmail/Messenger
  → Smart Clipboard xuất hiện trong sheet → Save as Clipboard hoặc Snippet. Đây là fallback tự
  nhiên, không cần overlay permission, biến hạn chế "không đọc clipboard nền" thành lợi thế chủ
  động ("Bạn chủ động gửi text vào app").
- MethodChannel bắt buộc trong Phase 0: `isKeyboardEnabled()`, `openKeyboardSettings()`.
  - Android: dùng `InputMethodManager` lấy danh sách enabled IME, kiểm tra package name.
  - Nếu keyboard chưa bật → Home screen hiện banner nhắc nhẹ nhàng, không spam liên tục.

### 7.1. Rủi ro OEM Android (thị trường Việt Nam) — bắt buộc đưa vào Onboarding

MIUI (Xiaomi), ColorOS (Oppo), One UI (Samsung) có cơ chế battery optimization/autostart
management aggressive hơn AOSP thuần — có thể kill IME process hoặc hạn chế Handler chạy nền,
gây hiện tượng "snippet mới tạo không nhận được" mà không phải lỗi code.

> **STRICT RULE**: Onboarding phải có bước hướng dẫn theo hãng máy phổ biến tại VN (vd: "Vào
> Cài đặt > Pin > Không giới hạn nền cho app này") — pattern quen thuộc với user Việt (Zalo,
> app OCR...). Không bắt buộc block nếu user bỏ qua, nhưng phải hiển thị rõ.

---

## 8. Feature Priority Matrix (MVP Scope)

| Nhóm | Tính năng | Mô tả | Scope |
|---|---|---|---|
| Clipboard | Foreground Capture | Đọc & lưu Pasteboard khi App lên Foreground | **P0** |
| Clipboard | Deduplication qua content_hash | Trùng nội dung → update copy_count, không tạo bản ghi mới | **P0** |
| Clipboard | Auto-Expiration Engine | Tự xoá lịch sử sau 1/7/30 ngày | **P0** |
| Clipboard | Sensitive Detection (Heuristic) | Regex + Entropy → privacy_risk_score | **P0** |
| Clipboard | Incognito/Pause Mode | Tạm dừng ghi history | **P0** |
| Clipboard | Burn After Paste | Tự xoá sau 1 lần dùng lại | **P1** |
| Snippets | Manual Snippets & Triggers | Tạo trigger `;email` → content | **P0** |
| Snippets | In-App Expansion + Playground | Gõ tắt trong text field nội bộ, có Playground riêng | **P0** |
| Snippets | System-Wide Android IME | Bàn phím custom bắt trigger mọi app | **P1** (sau Go-Gate) |
| Snippets | System-Wide iOS Extension | Swift Keyboard Extension | **P2** |
| Snippets | Dynamic Variables (`{{date}}`, `{{clipboard}}`) | Biến tự động | **P2** |
| Bảo mật | Biometric App Lock | Vân tay/khuôn mặt, khoá app | **P0 (Free)** |
| Bảo mật | Direct Intent Settings | Nhảy thẳng trang bật Keyboard Android | **P0** |
| Bảo mật | Encrypted Backup/Restore | AES-256-GCM, passphrase-derived key (mục 5.3) | **P1** |
| UX | Share Sheet Integration | Fallback chính thay Floating Widget | **P0** |
| UX | Soft-delete khi vượt Free limit | is_archived=1, không xoá vật lý | **P0** |

---

## 9. Monetization

```
┌───────────────────────────────────────┬───────────────────────────────────────┐
│              BẢN FREE                  │             BẢN PRO (IAP)              │
│            ($0 / Mãi mãi)              │       ($4.99 – $7.99 One-Time)         │
├───────────────────────────────────────┼───────────────────────────────────────┤
│ • Lưu tối đa 50–100 Clipboard History  │ • UNLIMITED Clipboard History          │
│ • Tạo tối đa 15–20 Active Snippets     │ • UNLIMITED Snippets & Triggers        │
│ • Tối đa 3 Folders                     │ • UNLIMITED Folders                    │
│ • Biometric Lock (miễn phí)            │ • Dynamic Variables                    │
│ • Onboarding + Share Sheet đầy đủ      │ • Encrypted Backup/Restore             │
│ • Không quảng cáo interstitial         │ • Đổi prefix trigger tuỳ chỉnh         │
└───────────────────────────────────────┴───────────────────────────────────────┘
```

- **Nguyên tắc**: Không Interstitial Ads ở bất kỳ luồng nào. Cân nhắc **bỏ hoàn toàn Banner Ads**
  nếu muốn giữ USP "Privacy-first, No tracking" mạnh — banner Settings của utility app thường
  revenue rất thấp, trong khi advertising SDK làm giảm trust ngay từ vị thế sản phẩm.
- **Soft-delete khi vượt Free limit**: item vượt ngưỡng KHÔNG bị xoá vật lý, chỉ đánh dấu
  `is_archived = 1` và ẩn khỏi UI + banner "Nâng cấp Pro để mở khoá X mục đã lưu". Khi mua Pro →
  restore toàn bộ ngay lập tức. Tránh review 1-sao "app xoá data của tôi".
- **7-day Pro Trial** (không cần thanh toán) — **KHÔNG hardcode cứng trong spec này**. Đây là
  quyết định monetization nên A/B test dựa trên dữ liệu thật từ Phase 0, không quyết định trước
  khi có data. Lý do: với one-time purchase + free tier đã generous (50–100/15–20), risk là user
  dùng hết trial rồi quay về free mà không thấy áp lực nâng cấp (trial hợp lý hơn với subscription
  model, nơi mất quyền truy cập hoàn toàn khi hết hạn). → Đưa vào backlog Phase 0 experiment,
  không phải P0 must-have.

---

## 10. Metrics (Local-only, KHÔNG chứa nội dung text)

```
snippets_created
snippets_used / expansion_count
clipboard_items_saved
clipboard_items_reused
playground_expansions
days_active
```

**Metric quan trọng nhất: `expansion_count / active_day`.**
- ≥ 1 → Text Expander tạo habit thật → đáng đầu tư Native IME (Phase 1→2).
- < 1 → Text Expander chưa tạo value → **không nên đầu tư nặng vào IME**, tập trung Share Sheet
  & In-App Utility.

Hypothesis sản phẩm cần kiểm chứng bằng Phase 0 trước khi cam kết Phase 1/2:
> "Người dùng lặp lại gõ cùng một đoạn text trên mobile và muốn cách nhanh, riêng tư để tái sử
> dụng mà không cần ghi chú hay tìm lại tin nhắn cũ."

---

## 11. Quyết định thay cho tranh luận (chốt các điểm review từng bất đồng/bỏ ngỏ)

| Chủ đề | Các review đề xuất | Quyết định cuối |
|---|---|---|
| Riverpod vs Provider | Một số để ngỏ | **Riverpod**, dùng thống nhất toàn app (state Clipboard/Snippet/Settings/Lock/IAP/IME status đều qua Riverpod, không trộn setState tự do ở màn hình chính) |
| Cache sync mechanism | Polling 2–3s (review3/4/5) vs FileObserver (review6) | **Polling cho MVP**, ghi rõ là technical debt có chủ đích, không phải kiến trúc cuối; nâng cấp FileObserver ở bản sau |
| Backup key management | "AES-256-GCM" nhắc lại nhưng không nói key từ đâu (review1–5) | **Phương án A**: passphrase-derived key qua PBKDF2/Argon2 (mục 5.3) |
| 7-day Pro trial | Đồng thuận mạnh ở review3/4/5, review6 phản biện | **Không hardcode**, đưa vào A/B test backlog dựa trên data Phase 0 |
| Floating Widget | plan1_final ban đầu đề xuất làm fallback | **Loại bỏ khỏi MVP**, thay bằng Share Sheet Integration (review1/4 đồng thuận) |
| Process boundary cho IME cache | Ngầm hiểu "in-memory cache" mơ hồ | **Làm rõ tường minh**: 2 process riêng biệt, sync chỉ qua file (mục 1.1) |
| Trigger instant-expand (không cần delimiter) | Không đề xuất bởi review nào | **Không làm ở MVP** — dễ false trigger |

---

## 12. Roadmap cuối cùng (4 Phase, có Go/No-Go Gate)

```
┌─────────────────────────────────────────────────────────────────────────┐
│ PHASE 0: CORE IN-APP MVP (5–7 ngày)                                      │
├─────────────────────────────────────────────────────────────────────────┤
│ • Flutter + SQLite (WAL) + Riverpod setup                               │
│ • Clipboard History: Foreground Capture, Dedup (content_hash), Auto-    │
│   Expiration, Sensitive Heuristic, Incognito/Pause Mode                 │
│ • Snippet & Folder Management + Soft-delete free limit                  │
│ • ✨ Expander Playground (bắt buộc, không optional)                     │
│ • Share Sheet Integration (Android Sharesheet)                          │
│ • Biometric App Lock (P0 Free)                                          │
│ • Local Encrypted Backup/Restore (AES-256-GCM, passphrase-derived key)  │
│ • Onboarding kép + Direct Intent Settings + OEM battery-opt hướng dẫn   │
│ • Local-only metrics tracking                                           │
└─────────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ PHASE 1: ANDROID IME TECHNICAL PROTOTYPE (2–4 ngày)                     │
├─────────────────────────────────────────────────────────────────────────┤
│ • InputMethodService tối giản (KHÔNG full QWERTY layout)                │
│ • Đọc cache từ file JSON → HashMap RAM riêng của IME process             │
│ • Trigger + Delimiter + Escape (;;)                                     │
│ • Test trên: Chrome, Gmail, Messenger, Telegram, Slack, plain           │
│   TextField, password field, gõ Telex/VNI, emoji                        │
│ • CHẠY GO/NO-GO GATE CHECKLIST (mục 4.4)                                │
└─────────────────────────────────────────────────────────────────────────┘
          │                                              │
     [PASS GATE]                                    [FAIL GATE]
          │                                              │
          ▼                                              ▼
┌───────────────────────────────────┐      ┌──────────────────────────────┐
│ PHASE 2: PRODUCTION ANDROID IME    │      │ QUAY VỀ IN-APP EXTENSIONS &  │
│ (7–14 ngày, chỉ nếu Gate PASS)     │      │ UX: Share Sheet, Quick        │
│ • Candidate bar, composition đầy đủ│      │ Action, Widgets. Release bản  │
│ • Onboarding Deep Link             │      │ In-App Utility, dừng đầu tư   │
│ • Performance polish, RAM budget   │      │ IME cho đến khi có data mới   │
│ • Deploy Google Play Open Beta     │      │                                │
│ • Play Store Data Safety           │      │                                │
│   declaration (mục 13)             │      │                                │
└───────────────────────────────────┘      └──────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ PHASE 3: iOS + ADVANCED (Post-launch, chỉ sau khi Android có traction)  │
├─────────────────────────────────────────────────────────────────────────┤
│ • Swift Keyboard Extension (App Group Shared Container)                 │
│ • Dynamic Variables Engine ({{date}}, {{time}}, {{clipboard}})          │
│ • Smart Tags / advanced detection                                       │
└─────────────────────────────────────────────────────────────────────────┘
```

**Nguyên tắc điều hành roadmap**: Release Phase 0 trước, đo `expansion_count/active_day`
(mục 10). Nếu thấp → không tiếp tục Phase 1/2 ngay, ưu tiên cải thiện In-App Utility. Đây là
cách giảm rủi ro lớn nhất cho một team/agent chưa có kinh nghiệm Native IME.

---

## 13. Play Store / App Store Compliance

- App khai báo là bàn phím (IME) + có quyền đọc clipboard → Google Play **bắt buộc khai trong
  Data Safety form** rằng app "collects clipboard data", **kể cả khi 100% local**. Khai sai/thiếu
  → risk bị gỡ app hoặc bị gắn cảnh báo ngay trên trang store, ảnh hưởng install rate.
- **Checklist release bắt buộc** (thủ công, ngoài code, dễ bị quên):
  - [ ] Play Console → Data Safety: khai rõ *"Clipboard data: Collected but not shared, stored
        on device only, user can delete"*.
  - [ ] Privacy Policy công khai, minh bạch: khẳng định 100% Offline Local, không server thu
        thập dữ liệu.
  - [ ] Store listing description không quảng cáo sai: *"Save it once. Paste it anywhere"* —
        không dùng ngôn ngữ ngụ ý "tự động lưu nền liên tục" (tránh review 1-sao vì hiểu nhầm).

---

## 14. Dependency Whitelist (Flutter) — Chốt cứng, Agent KHÔNG tự ý thêm package khác

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.5.1        # State Management chính, thống nhất toàn app
  sqflite: ^2.3.2                  # Local SQLite Database
  path_provider: ^2.1.2            # Lấy thư mục lưu trữ cục bộ
  local_auth: ^2.1.8               # Biometric App Lock (Free P0)
  in_app_purchase: ^3.1.13         # Pro Lifetime IAP
  encrypt: ^5.0.3                  # AES-256-GCM cho Backup/Restore
  crypto: ^3.0.3                   # SHA256 content_hash, PBKDF2 key derivation
  receive_sharing_intent: ^1.4.5   # Share Sheet Integration
  flutter_secure_storage: ^9.0.0   # (nếu cần lưu salt/metadata backup — KHÔNG lưu key raw)
```

**Không dùng**: Hive (đã chọn SQLite làm nguồn sự thật duy nhất, tránh 2 nguồn dữ liệu song
song), Firebase (trừ trường hợp thật sự cần Analytics vô hại về sau — không phải MVP), bất kỳ
BaaS/Server SDK nào khác.

---

## 15. STRICT RULES CHO AI CODING AGENT (tổng hợp cuối cùng — đọc kỹ trước khi code)

1. **[NO BACKGROUND SPY]** KHÔNG tạo Background Service chạy ngầm 24/7 nghe lén Clipboard.
2. **[NO SERVER SDK]** KHÔNG tích hợp bất kỳ SDK Server/BaaS nào (Firebase DB, Supabase...) để
   đẩy nội dung text ra ngoài thiết bị.
3. **[WAL MODE]** BẮT BUỘC `PRAGMA journal_mode=WAL;` khi khởi tạo SQLite.
4. **[NO INTERSTITIAL]** KHÔNG dùng Interstitial Ads ở bất kỳ luồng nào.
5. **[NO SQLITE ON HOT PATH]** Native IME TUYỆT ĐỐI KHÔNG query SQLite trên bất kỳ key event
   nào (`onKey`/`onStartInputView` loop). Mọi truy xuất Snippet phải qua in-memory HashMap được
   dựng từ file cache riêng của IME process.
6. **[PROCESS BOUNDARY]** IME process và Flutter App process là hai tiến trình độc lập, KHÔNG
   chia sẻ bộ nhớ. Đồng bộ CHỈ qua file trên disk (`snippets_cache.json` + `cache_version`).
   Không viết code giả định object nào đó tồn tại chung giữa hai bên.
7. **[NO LOGGING SENSITIVE DATA]** Nội dung Clipboard, Snippet, Password, OTP KHÔNG BAO GIỜ
   được ghi vào Logcat, Analytics, Crashlytics, notification hay debug output dưới bất kỳ hình
   thức nào — kể cả debug build.
8. **[LOCAL-FIRST NETWORK]** App Local-First 100%. Không khởi tạo network request nào ngoài SDK
   xác thực In-App Purchase.
9. **[HEURISTIC BOUNDARY]** Tính năng phát hiện dữ liệu nhạy cảm chỉ là Heuristic/Gợi ý, KHÔNG
   ĐƯỢC quảng cáo là giải pháp bảo mật tuyệt đối ở bất kỳ đâu (UI, Store listing, code comment).
10. **[IME SCOPE PHASE 1]** Trong Phase 1 Prototype, KHÔNG viết lại full QWERTY keyboard layout.
    Chỉ tập trung Candidate/Suggestion strip + Text Replacement Engine.
11. **[NO FLOATING OVERLAY]** KHÔNG thêm quyền Floating Overlay trong MVP.
12. **[BACKUP ENCRYPTION]** File Backup bắt buộc AES-256-GCM, key derive từ passphrase user qua
    PBKDF2/Argon2 (≥100k iterations), salt + nonce ngẫu nhiên mỗi lần export. KHÔNG hardcode key,
    KHÔNG derive từ device ID.
13. **[CACHE REGEN]** Sau MỌI thao tác CRUD snippet và sau MỌI schema migration thành công, phải
    gọi `regenerateSnippetCache()`. Nếu cache không hợp lệ, IME fallback empty state, KHÔNG crash.
14. **[TRIGGER RULE]** Snippet chỉ expand khi trigger theo sau bởi delimiter (Space/Enter/Tab/
    dấu câu `.,!?`). Escape bằng `;;`. Trigger chỉ xét sau khi composition (Telex/VNI) kết thúc.
15. **[UTF-16 OFFSET SAFETY]** Logic xoá trigger trước khi insert PHẢI tính offset theo UTF-16
    code unit, có test case với ký tự có dấu phức tạp và emoji liền kề.
16. **[VIETNAMESE GATE]** Composition tiếng Việt Telex/VNI (`aa→â, aw→ă, dd→đ`) là tiêu chí BẮT
    BUỘC trong Go/No-Go Gate — fail bất kỳ mục nào → No-Go, không tiếp tục Phase 2.
17. **[SOFT DELETE]** Khi vượt Free limit, đánh dấu `is_archived=1`, KHÔNG xoá vật lý dữ liệu
    user. Restore đầy đủ khi mua Pro.
18. **[STATE MANAGEMENT]** BẮT BUỘC dùng Riverpod thống nhất toàn app. Không trộn Provider hoặc
    setState tự do ở các màn hình chính.
19. **[DEPENDENCY WHITELIST]** Chỉ dùng package trong danh sách mục 14. Không tự ý thêm package
    khác (đặc biệt Hive, Firebase, bất kỳ BaaS nào) mà không có xác nhận rõ ràng.
20. **[PLAYGROUND REQUIRED]** Expander Playground là màn hình bắt buộc trong Phase 0, không phải
    tính năng optional có thể bỏ qua để tiết kiệm thời gian.

---

## 16. Kết luận

Bản Master Spec này gộp toàn bộ điểm đồng thuận từ 6 vòng phản biện độc lập và **chốt cứng**
mọi điểm còn bỏ ngỏ hoặc mâu thuẫn (key management, cache sync mechanism, process boundary,
trial monetization, floating widget) thành quyết định rõ ràng — không để lại quyết định thiết
kế mơ hồ cho AI Coding Agent tự suy đoán giữa chừng.

**Trình tự giao việc cho Agent**: Bắt đầu Phase 0 ngay theo mục 12, tuân thủ toàn bộ Strict
Rules ở mục 15. Không bắt đầu Phase 1 (Native IME) cho đến khi Phase 0 hoàn thành và có dữ liệu
metrics thật (mục 10) xác nhận hypothesis Text Expander. Phase 1 chỉ chuyển Phase 2 khi Go/No-Go
Gate (mục 4.4) đạt 100%.