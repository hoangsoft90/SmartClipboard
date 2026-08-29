# plan4_final.md — Smart Clipboard Keyboard: Kế hoạch triển khai chi tiết cho Agent

> Tổng hợp cuối cùng từ `plan4.md` + `plan4_review1-4.md` + đọc trực tiếp source thật tại
> `/Users/hoang/htdocs_apps/SmartClipboard/source` (ngày 29/08/2026).
> Mục tiêu sản phẩm: **Smart Clipboard trở thành bàn phím dùng hàng ngày, đủ để gỡ Gboard.**

---

## 0. Nguyên tắc bắt buộc cho Agent (đọc trước khi code)

1. **Làm đúng thứ tự Phase 4A → 4B → 4C → 4D → 4E.** Không nhảy cóc sang Telex/EN-VI khi 4A/4B chưa xong và test được trên máy thật.
2. **Không tự động set default IME bằng reflection/private API.** Luôn dùng `showInputMethodPicker()` để user tự chọn.
3. **Không thêm quyền `INTERNET`** — giữ 100% local-first (đã bị xoá chủ động ở `AndroidManifest.xml`, không được thêm lại).
4. **Mọi thao tác `deleteSurroundingText`/`commitText` phải gọi `finishComposingText()` trước** nếu đang trong trạng thái composing (áp dụng từ Phase 4D trở đi khi có Telex).
5. **Không sửa logic snippet expansion đang chạy tốt** (`handleDelimiter`, `;;` escape, suggestion strip) trừ khi phase yêu cầu rõ.
6. Mỗi phase xong phải **build + cài APK + test tay theo checklist ở cuối phase đó** trước khi sang phase tiếp theo.

---

## PHASE 4A — Fix Activation UX (Enabled ≠ Active)

### Vấn đề xác nhận từ source thật
`MainActivity.kt` hiện chỉ có `isKeyboardEnabled` và `openKeyboardSettings`. Không có API kiểm tra IME đang active, không có API mở picker. `providers.dart` → `keyboardEnabledProvider` là `FutureProvider<bool>` nhị phân, dùng ở 3 nơi: `playground_screen.dart`, `home_screen.dart`, `onboarding_screen.dart`.

### 4A.1 — `MainActivity.kt`

Thêm vào trong `configureFlutterEngine`, block `when (call.method)`, ngay sau case `"openKeyboardSettings"`:

```kotlin
"isKeyboardActive" -> {
    result.success(isSmartClipboardKeyboardActive())
}
"showKeyboardPicker" -> {
    showInputMethodPicker()
    result.success(null)
}
```

Thêm 2 private function mới, đặt ngay sau `isSmartClipboardKeyboardEnabled()`:

```kotlin
/**
 * Check if SmartClipboard IME is the CURRENTLY SELECTED input method
 * (không chỉ enabled). So sánh DEFAULT_INPUT_METHOD với package name.
 */
private fun isSmartClipboardKeyboardActive(): Boolean {
    return try {
        val current = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.DEFAULT_INPUT_METHOD
        )
        // Format: "com.smartclip.smartclipboard/.SmartClipboardIME"
        current?.startsWith(IME_PACKAGE) == true
    } catch (_: Exception) {
        false
    }
}

/**
 * Mở system IME picker để user chủ động chuyển sang Smart Clipboard.
 * KHÔNG tự set default bằng reflection — luôn để user chọn.
 */
private fun showInputMethodPicker() {
    try {
        val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
        imm.showInputMethodPicker()
    } catch (_: Exception) {
        // Best-effort
    }
}
```

### 4A.2 — `lib/core/native_bridge/native_bridge.dart`

Thêm 2 method mới vào class `NativeBridge`, theo đúng pattern try/catch đã có:

```dart
/// Smart Clipboard có đang là input method HIỆN TẠI (active) không?
/// Khác với isKeyboardEnabled() — enabled chỉ nghĩa là "được phép dùng".
Future<bool> isKeyboardActive() async {
  if (!_isSupported) return false;
  try {
    return await _channel.invokeMethod<bool>('isKeyboardActive') ?? false;
  } on MissingPluginException {
    return false;
  } on PlatformException {
    return false;
  }
}

/// Mở system IME picker (Settings > Choose input method) để user
/// chuyển sang Smart Clipboard ngay trong 1 bước, không cần vào Settings.
Future<void> showKeyboardPicker() async {
  if (!_isSupported) return;
  try {
    await _channel.invokeMethod('showKeyboardPicker');
  } on MissingPluginException {
    // No-op nếu native side chưa tồn tại.
  } on PlatformException {
    // Best-effort.
  }
}
```

### 4A.3 — `lib/state/providers.dart`

Thay thế `keyboardEnabledProvider` bool đơn bằng model 3 trạng thái. Thêm enum và provider mới, **giữ nguyên `keyboardEnabledProvider` cũ** (để không phá code khác đang phụ thuộc) nhưng thêm provider tổng hợp:

```dart
enum KeyboardActivationState { disabled, enabledNotActive, active }

final keyboardActiveProvider = FutureProvider<bool>(
    (ref) => ref.watch(nativeBridgeProvider).isKeyboardActive());

final keyboardActivationStateProvider = FutureProvider<KeyboardActivationState>((ref) async {
  final enabled = await ref.watch(nativeBridgeProvider).isKeyboardEnabled();
  if (!enabled) return KeyboardActivationState.disabled;
  final active = await ref.watch(nativeBridgeProvider).isKeyboardActive();
  return active
      ? KeyboardActivationState.active
      : KeyboardActivationState.enabledNotActive;
});
```

### 4A.4 — UI: `home_screen.dart`, `playground_screen.dart`, `onboarding_screen.dart`

Ở cả 3 file, thay chỗ đang dùng `ref.watch(keyboardEnabledProvider)` bằng `ref.watch(keyboardActivationStateProvider)`, hiển thị 3 trạng thái:

```dart
final activationState = ref.watch(keyboardActivationStateProvider).value
    ?? KeyboardActivationState.disabled;

switch (activationState) {
  case KeyboardActivationState.disabled:
    // Badge đỏ: "Disabled"
    // Button: "Enable Keyboard" -> ref.read(nativeBridgeProvider).openKeyboardSettings()
    break;
  case KeyboardActivationState.enabledNotActive:
    // Badge vàng: "Enabled — Not active"
    // Button: "Switch to Smart Clipboard" -> ref.read(nativeBridgeProvider).showKeyboardPicker()
    break;
  case KeyboardActivationState.active:
    // Badge xanh: "✓ Active & Ready"
    // Gợi ý: "Thử gõ ;email + Space ở Telegram"
    break;
}
```

Sau khi gọi `showKeyboardPicker()` hoặc quay lại app từ Settings, nhớ `ref.invalidate(keyboardActivationStateProvider)` (đúng pattern `ref.invalidate(keyboardEnabledProvider)` đã có ở 2 file kia).

### 4A.5 — Onboarding: cảnh báo bảo mật hệ thống

Trong `onboarding_screen.dart`, **trước** khi user bấm nút mở Settings/Picker lần đầu, thêm 1 màn/step giải thích:

> "Android sẽ hiện cảnh báo bảo mật tiêu chuẩn cho mọi bàn phím: *'Bàn phím này có thể đọc mọi thứ bạn gõ, bao gồm mật khẩu và số thẻ.'* Đây là cảnh báo mặc định của Android cho **mọi** IME, không riêng gì Smart Clipboard. Smart Clipboard cam kết 100% local-first — không có quyền Internet, không gửi dữ liệu ra ngoài."

### ✅ Checklist test Phase 4A (bắt buộc trước khi sang 4B)
- [ ] Cài APK mới, mở app → thấy badge "Disabled"
- [ ] Bấm Enable → vào Settings, bật switch → quay lại app → badge chuyển "Enabled — Not active"
- [ ] Bấm "Switch to Smart Clipboard" → picker hệ thống hiện ra, chọn Smart Clipboard
- [ ] Quay lại app → badge chuyển "Active & Ready"
- [ ] Mở Telegram, gõ thử `;` bất kỳ trigger nào đã tạo → xác nhận IME thật sự active

---

## PHASE 4B — Fix Symbol/Number Layer (BLOCKER nghiêm trọng nhất hiện tại)

### Vấn đề xác nhận từ source thật
Trong `SmartClipboardIME.kt`, key code `-6` (nút `?123`) hiện là:
```kotlin
-6 -> {
    // TODO: Symbol layer — nằm ngoài phạm vi patch này.
    // Tạm thời không làm gì để tránh crash.
}
```
**Đây là nút chết.** Người dùng hiện tại **không có cách nào gõ số, `;`, `@`, hay bất kỳ ký tự đặc biệt nào** bằng bàn phím này — nghiêm trọng hơn nhiều so với "thiếu dấu `;`" mà plan4.md mô tả ban đầu. Đây là việc phải làm **trước** `;`/`@`/toolbar, vì không có nó thì bàn phím không dùng được cho việc gõ hàng ngày dù chỉ 1 ngày.

### 4B.1 — `SmartKeyboardView.kt`: thêm state layer + layout symbol

Thêm field mới:
```kotlin
enum class KeyboardLayer { LETTERS, SYMBOLS }
private var currentLayer = KeyboardLayer.LETTERS
```

Thêm data cho symbol layer (theo đúng bố cục đã chốt ở review3/review4):
```kotlin
private val symbolRow1 = listOf("1","2","3","4","5","6","7","8","9","0")
    .map { Key(it, it[0].code) }
private val symbolRow2 = listOf("@","#","$","%","&","*","-","+","(",")")
    .map { Key(it, it[0].code) }
private val symbolRow3 = listOf("!","\"","'",":",";","/","?")
    .map { Key(it, it[0].code) }
```

Sửa `row4[0]` — nút `?123` cần đổi label động theo layer hiện tại (`?123` khi ở LETTERS, `ABC` khi ở SYMBOLS). Đơn giản nhất: thêm helper `getRow4Key0Label()` và dùng trong `drawRow4`.

Sửa `onDraw`: nếu `currentLayer == SYMBOLS`, vẽ `symbolRow1/2/3` + hàng cuối (`ABC` thay `?123`, giữ Space/Backspace/Enter) thay vì `row1/row2/row3Base`.

Thêm function toggle:
```kotlin
fun toggleSymbolLayer() {
    currentLayer = if (currentLayer == KeyboardLayer.LETTERS) KeyboardLayer.SYMBOLS else KeyboardLayer.LETTERS
    invalidate()
}
fun isSymbolLayer() = currentLayer == KeyboardLayer.SYMBOLS
```

### 4B.2 — `SmartClipboardIME.kt`: xử lý key `-6` thật sự

Thay block hiện tại:
```kotlin
-6 -> {
    keyboardView.toggleSymbolLayer()
}
```

Sau khi user gõ 1 ký tự ở symbol layer (vd `;` hoặc `@`), giữ nguyên hành vi hiện tại của `else -> {...}` (đã handle `;;` escape, buffer, commitText) — **không cần sửa gì thêm ở nhánh `else`**, vì `getCharForKey()` sẽ tự trả đúng ký tự nếu `keyCode` map đúng ASCII.

**Lưu ý quan trọng:** vì `getCharForKey()` hiện tại chỉ xử lý `keyCode in 32..126` — các ký tự symbol (`@ # $ % & * - + ( ) ! " ' : ; / ?`) đều nằm trong dải ASCII 33-47, 58-64 nên **đã tự động hoạt động đúng**, không cần sửa `getCharForKey()`.

### 4B.3 — Toolbar `;` `@` `.com` (theo bố cục đã chốt)

Thêm 1 row toolbar 40-48dp phía trên `SuggestionStrip` hiện có (hoặc gộp chung), chứa 3 nút tắt nhanh: `;` `@` `.com`. Khi bấm, gọi thẳng `onKeyPressed()` với keyCode tương ứng (`;`.code, `@`.code) — riêng `.com` gọi `ic.commitText(".com", 1)` trực tiếp (không qua buffer vì là chuỗi nhiều ký tự).

### ✅ Checklist test Phase 4B
- [ ] Bấm `?123` → layout đổi sang số/symbol, nút đổi thành `ABC`
- [ ] Gõ được đủ `0-9`, `@ # $ % & * - + ( )`, `! " ' : ; / ?`
- [ ] Bấm `ABC` → quay lại layout chữ cái
- [ ] Gõ `;email` + Space ở symbol layer vẫn expand đúng snippet (không phá logic buffer hiện có)
- [ ] Toolbar `;` `@` `.com` hoạt động không cần chuyển layer

---

## PHASE 4C — "Native Feel" (bắt buộc trước khi cân nhắc gỡ Gboard)

Đây là phần quyết định cảm giác "giống bàn phím mặc định" nhiều hơn cả Telex. Không có trong `plan4.md` gốc, bổ sung dựa trên phân tích thực tế cần thiết cho mục tiêu daily-driver.

### 4C.1 — Key preview popup
Khi `ACTION_DOWN` trong `onTouchEvent` của `SmartKeyboardView`, hiện 1 `TextView` popup phóng to (kiểu bubble) ngay phía trên vị trí phím đang nhấn, ẩn khi `ACTION_UP`/`ACTION_CANCEL`. Có thể dùng `PopupWindow` đơn giản gắn vào `SmartClipboardIME` (root view của `onCreateInputView`).

### 4C.2 — Auto-capitalize đầu câu
Trong `SmartClipboardIME`, theo dõi ký tự cuối đã commit (`lastCommittedChar`). Nếu `lastCommittedChar` là `null`/sau `.`/sau `!`/sau `?`/sau `\n` và tiếp theo là ký tự chữ cái đầu tiên, tự động uppercase ký tự đó khi commit (không cần `isShifted` toggle thủ công). Không phải autocorrect — chỉ là rule đơn giản, an toàn để làm.

### 4C.3 — Double-space → dấu chấm
Trong `handleDelimiter`, nếu delimiter là Space và ký tự **trước đó vừa commit cũng là Space** (trong field không phải password), thay bằng: xoá space vừa gõ, insert `". "` (chấm + space). Cần theo dõi `lastCommittedChar` để biết.

### 4C.4 — Emoji tray (bắt buộc nếu có kế hoạch gỡ Gboard)
Thêm 1 nút emoji (😀) trên toolbar/suggestion strip. Bấm vào mở 1 `GridLayout`/`RecyclerView` đơn giản chứa danh sách emoji phổ biến (~100-200 emoji Unicode cứng, không cần thư viện ngoài), bấm emoji → `ic.commitText(emoji, 1)`. Không cần category/search ở v1 — chỉ cần **có** để không mất khả năng gõ emoji khi gỡ Gboard.

### 4C.5 — Backspace giữ để xoá nhanh (accelerating repeat)
Trong `onTouchEvent`, khi `ACTION_DOWN` trên phím Backspace, dùng `Handler.postDelayed` lặp lại `handleBackspace()` với tần suất tăng dần (vd 400ms → 100ms sau 1s giữ), dừng khi `ACTION_UP`/`ACTION_CANCEL`.

### 4C.6 — Theme sáng/tối theo hệ thống
`SmartKeyboardView.onDraw` hiện dùng màu cứng (`Color.WHITE`, `#CCCCCC`...). Thêm check `resources.configuration.uiMode` (dark mode) và đổi bảng màu Paint tương ứng (nền tối, chữ sáng) khi hệ thống ở dark mode.

### ✅ Checklist test Phase 4C
- [ ] Key preview hiện đúng vị trí khi nhấn giữ
- [ ] Gõ câu mới sau dấu `.` tự viết hoa chữ đầu
- [ ] Gõ 2 lần Space liên tiếp → tự thành `. `
- [ ] Emoji tray mở được, chèn emoji đúng vào text field
- [ ] Giữ Backspace xoá nhanh dần, không giật/lag
- [ ] Bật Dark mode hệ thống → bàn phím đổi theme theo

---

## PHASE 4D — EN/VI Subtype + Vietnamese Telex Engine

### 4D.1 — `method_metadata.xml`
File hiện tại:
```xml
<input-method xmlns:android="http://schemas.android.com/apk/res/android"
    android:supportsInlineSuggestions="false" />
```
Cần thêm 2 subtype (English, Vietnamese) để hệ thống nhận diện đúng và một số app (đặc biệt Samsung Keyboard switcher) hoạt động chuẩn:
```xml
<input-method xmlns:android="http://schemas.android.com/apk/res/android"
    android:supportsInlineSuggestions="false">
    <subtype
        android:label="English"
        android:imeSubtypeLocale="en_US"
        android:imeSubtypeMode="keyboard" />
    <subtype
        android:label="Tiếng Việt"
        android:imeSubtypeLocale="vi_VN"
        android:imeSubtypeMode="keyboard" />
</input-method>
```

### 4D.2 — Nút EN/VI trên toolbar
Nút toggle đơn giản trong `SmartClipboardIME`, lưu state `currentLanguage: Language` (enum `EN`/`VI`) ở instance field (không cần persist qua subtype system phức tạp cho v1 — chỉ cần toggle nội bộ + hiển thị label rõ trên toolbar).

### 4D.3 — `VietnameseTelexProcessor.kt` (file mới)
Tạo class Kotlin thuần, **không** port thư viện C++, theo đúng hướng review2/3 đã thống nhất. Interface đề xuất:

```kotlin
class VietnameseTelexProcessor {
    // Buffer chứa các ký tự Latin gốc của từ đang gõ (chưa có dấu)
    private val rawBuffer = StringBuilder()

    /** Gọi khi user gõ 1 ký tự ở mode VI. Trả về composing text hiện tại. */
    fun onChar(c: Char): String { ... }

    /** Gọi khi backspace. */
    fun onBackspace(): String { ... }

    /** Gọi khi delimiter (space/enter/punctuation) — trả về từ cuối cùng, clear buffer. */
    fun commit(): String { ... }

    fun reset() { rawBuffer.clear() }
}
```

Bảng mapping bắt buộc (theo đúng chuẩn Telex, review2/3 đã liệt kê):
```
aa -> â      aw -> ă      dd -> đ
ee -> ê      oo -> ô      ow -> ơ
uw -> ư
Dấu thanh (áp dụng ký tự cuối của âm chính):
  s -> sắc (á)   f -> huyền (à)   r -> hỏi (ả)
  x -> ngã (ã)   j -> nặng (ạ)
```
**Bắt buộc viết bộ test case Kotlin unit test** (không chỉ happy path) trước khi tích hợp vào IME, cover: xoá giữa từ, sửa dấu (gõ `as` rồi `f` để đổi từ sắc sang huyền), tổ hợp `ươ` (`uow`), và trigger `;email` khi đang ở mode VI.

### 4D.4 — Tích hợp vào `SmartClipboardIME.kt`
- Khi `currentLanguage == VI`: mọi ký tự chữ cái đi qua `telexProcessor.onChar()` trước, dùng `ic.setComposingText(result, 1)` thay vì `ic.commitText()` trực tiếp.
- Khi gặp delimiter: gọi `telexProcessor.commit()` → `ic.finishComposingText()` → rồi mới chạy logic `handleDelimiter()` hiện có (kiểm tra trigger map) trên từ đã hoàn thiện dấu.
- **Rule bắt buộc (đã thống nhất ở review3):** Trước MỌI lệnh `deleteSurroundingText()` hoặc `commitText()` cho snippet expansion, phải gọi `ic.finishComposingText()` trước, nếu không sẽ crash hoặc lệch text khi Telex đang composing.

### ✅ Checklist test Phase 4D
- [ ] Toggle EN/VI hoạt động, label hiển thị đúng
- [ ] Gõ Telex cơ bản đúng: `chao1` → `chào`... (thực tế: `chaof` → `chào`)
- [ ] Sửa dấu giữa chừng không bị lệch/crash
- [ ] Gõ `;email` khi đang mode VI vẫn expand đúng, không kẹt composing text
- [ ] Test trên WebView thật (Zalo/Messenger) không riêng app native

---

## PHASE 4E — Go-Live Test trước khi gỡ Gboard

**Không code — đây là checklist thủ công bắt buộc trước khi user xoá Gboard.**

- [ ] Test toàn bộ app ngân hàng/ví điện tử đang dùng (MoMo, banking app...) với Smart Clipboard làm active IME trên ô nhập PIN/mật khẩu — nếu bị chặn, giữ Gboard cài (disable, không gỡ) làm dự phòng riêng cho các app đó.
- [ ] Dùng Smart Clipboard làm keyboard chính, **giữ Gboard cài nhưng disable** trong tối thiểu 2 tuần sử dụng thực tế.
- [ ] Xác nhận không crash IME trong ít nhất 2 tuần dùng hàng ngày (nếu IME crash, mất khả năng gõ trên toàn hệ thống — rủi ro nghiêm trọng hơn app thường).
- [ ] Test landscape orientation, ít nhất 1 app WebView (Zalo/Chrome), ít nhất 1 field password/email/number/URL.
- [ ] Chỉ gỡ Gboard sau khi mọi mục trên đều pass.

---

## Phụ lục: Bản đồ file liên quan (từ source thật)

| File | Vai trò |
|---|---|
| `android/.../MainActivity.kt` | MethodChannel native bridge |
| `android/.../SmartClipboardIME.kt` | InputMethodService chính, xử lý key + snippet expansion |
| `android/.../SmartKeyboardView.kt` | Vẽ layout bàn phím (Canvas-based, không dùng `Keyboard` class deprecated) |
| `android/.../res/xml/method_metadata.xml` | Khai báo subtype IME |
| `android/.../AndroidManifest.xml` | Khai báo `<service>` IME, permissions |
| `lib/core/native_bridge/native_bridge.dart` | Dart wrapper cho MethodChannel |
| `lib/state/providers.dart` | Riverpod providers, bao gồm `keyboardEnabledProvider` |
| `lib/screens/home_screen.dart`, `playground_screen.dart`, `onboarding_screen.dart` | UI hiển thị trạng thái keyboard |

## Phụ lục: Key code convention hiện có (giữ nguyên, không đổi)
```
>= 32       → ASCII character
-1          → Backspace
-2          → Space
-3          → Enter
-4          → Tab
-5          → Shift toggle
-6          → Symbol layer toggle (Phase 4B mới thật sự implement)
```