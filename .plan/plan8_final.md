# Smart Clipboard Keyboard — plan8_final.md

> Verify trực tiếp trên `SmartClipboardIME.kt` + `SmartKeyboardView.kt` bản
> mới nhất. Có 1 phát hiện MỚI (Bug 0) nghiêm trọng hơn 2 lỗi bạn báo cáo ban
> đầu — không nằm trong `plan8.md` hay bất kỳ review nào, phát hiện được nhờ
> đọc lại toàn bộ nhánh `else` trong `onKeyPressed()`.

---

## 🔴 BUG 0 (MỚI PHÁT HIỆN, ưu tiên cao nhất) — Gõ tắt `;trigger` qua bàn phím vật lý đã bị phá hoàn toàn

### Nguyên nhân

Một fix trước đó (đánh dấu "PLAN 7 P0-1", nhằm sửa lỗi dấu câu không đóng đúng
ranh giới từ Telex — đúng như tôi khuyến nghị ở `plan7_final.md`) đã route
các ký tự "word-boundary" qua `handleDelimiter()`:

```kotlin
val wordBoundaryChars = setOf(',', '.', '!', '?', ';', ':')
if (previewCh[0] in wordBoundaryChars) {
    handleDelimiter(ic, previewCh[0])
    return
}
```

**Vấn đề:** tập hợp này chứa cả `;` và `:` — trong khi khuyến nghị gốc của
tôi ở `plan7_final.md` **chỉ** gồm `. , ! ?`, không bao gồm `;`. Việc thêm
`;` vào đây tạo ra 1 regression nghiêm trọng:

1. `handleDelimiter()` **không** append ký tự delimiter vào `typingBuffer` —
   nó chỉ đọc buffer hiện có rồi `clear()` sau khi xử lý xong. Khi user gõ
   `;` là ký tự **đầu tiên** của trigger, `;` giờ bị chặn ngay từ đầu, route
   thẳng vào `handleDelimiter` → **không bao giờ được thêm vào `typingBuffer`**.
2. Hệ quả: gõ `;email` + Space → buffer thực tế là `"email"` (thiếu `;` ở
   đầu) → tra `triggerMap["email"]` — nhưng cache lưu key có prefix
   `";email"` (theo Option A đã chốt từ batch trước) → **không bao giờ
   match** → **snippet không expand qua bàn phím vật lý, coi như tính năng
   lõi của app đã chết lần nữa**.
3. **Đồng thời**, đoạn code xử lý escape `;;` (`if (ch == ";" && ...)`) nằm
   **sau** đoạn wordBoundaryChars trong cùng khối `else` — vì `;` giờ luôn bị
   chặn và `return` sớm ở bước 1, đoạn code escape `;;` trở thành **dead
   code, không bao giờ được thực thi** → gõ `;;` cũng không còn hoạt động
   đúng.

**Điểm may mắn duy nhất:** nút `;` trên `QuickToolbar` (thanh công cụ phía
trên bàn phím) đi qua nhánh code khác hoàn toàn (`onToolbarShortcut(";")`),
**không bị ảnh hưởng** bởi regression này — nếu bạn từng test snippet bằng
cách bấm nút `;` trên toolbar thay vì gõ phím `;` ở layer Symbols, bạn sẽ
không thấy bug này. Đây có thể là lý do chưa ai phát hiện ra.

### Fix — bỏ `;` và `:` khỏi wordBoundaryChars, chỉ giữ đúng 4 ký tự dấu câu

```kotlin
// PLAN 8 FIX BUG 0: chỉ dấu câu câu văn (. , ! ?) mới là word-boundary.
// KHÔNG gồm ';' — dấu này là PREFIX của trigger snippet, phải tiếp tục
// đi qua nhánh ký tự thường bên dưới để được append vào typingBuffer
// và được đoạn code escape ";;" xử lý đúng. KHÔNG gồm ':' — không có lý
// do sản phẩm nào cần ':' là delimiter, thêm vào chỉ tăng rủi ro không cần
// thiết.
val wordBoundaryChars = setOf(',', '.', '!', '?')
if (previewCh[0] in wordBoundaryChars) {
    handleDelimiter(ic, previewCh[0])
    return
}
```

**Đây là fix 1 dòng nhưng là fix quan trọng nhất trong toàn bộ patch này.**
Phải làm và test trước tiên, trước cả 2 bug bạn báo cáo — vì nó ảnh hưởng
trực tiếp tính năng lõi (text expansion), không phải lỗi "vặt".

---

## BUG 1 — Backspace: gõ lại vẫn tự bị xoá sau khi nhả tay

### Đồng thuận với `plan8.md` + cả 4 review về nguyên nhân, đồng thuận với review1/2/3/4 về hướng xử lý (KHÔNG bỏ hold-to-delete)

Xác nhận chính xác qua code — `ACTION_UP` thiếu đúng 2 dòng:

```kotlin
MotionEvent.ACTION_UP -> {
    val key = findKeyAt(event.x.toInt(), event.y.toInt())
    pressedKey = null
    invalidate()
    previewListener?.onKeyPreviewDismissed()

    if (key != null) {
        try { performHapticFeedback(...) } catch (_: Exception) {}
        listener?.onKeyPress(key.key.keyCode)   // ❌ luôn fire, kể cả khi vừa repeat xong
    }
    return true
}
// ❌ Không có: isBackspaceRepeating = false
// ❌ Không có: touchHandler.removeCallbacks(backspaceRepeatRunnable)
```

`ACTION_MOVE`, `ACTION_CANCEL`, `onDetachedFromWindow()` **đã có** cleanup
đúng (xác nhận qua code) — chỉ riêng `ACTION_UP` bị thiếu. Đây chính xác là
kết luận của `review3` (bản phân tích chính xác nhất trong 4 review) — không
phải toàn bộ cơ chế sai, chỉ thiếu đúng 1 nhánh.

### Phản biện lại `plan8.md`: không đồng ý bỏ hold-to-delete

`plan8.md` đề xuất xoá hoàn toàn `Handler`/`Runnable`/toàn bộ cơ chế repeat
vì lý do "giảm complexity, tăng ổn định". Tôi đồng ý với cả 4 review (đồng
thuận hiếm có, không ai lệch hướng) rằng đây là phản ứng thái quá:

- Nguyên nhân đã xác định chính xác, khu trú đúng 1 chỗ (`ACTION_UP` thiếu 2
  dòng) — không phải lỗi kiến trúc lan rộng cần đập đi xây lại.
- `ACTION_MOVE`, `CANCEL`, `onDetachedFromWindow` đã đúng sẵn — chứng minh
  cơ chế repeat về tổng thể là sound, chỉ sót 1 nhánh.
- Bỏ hold-to-delete là bước lùi UX thật sự (phải bấm 20 lần cho 20 ký tự) —
  đánh đổi không cân xứng với công sức bỏ 4 dòng code để vá đúng.

### Fix

```kotlin
MotionEvent.ACTION_UP -> {
    val key = findKeyAt(event.x.toInt(), event.y.toInt())
    val wasRepeating = isBackspaceRepeating   // ✅ lưu lại TRƯỚC khi reset

    // ✅ FIX BUG 1: bắt buộc dừng repeat khi nhả tay
    isBackspaceRepeating = false
    touchHandler.removeCallbacks(backspaceRepeatRunnable)

    pressedKey = null
    invalidate()
    previewListener?.onKeyPreviewDismissed()

    if (key != null) {
        try {
            performHapticFeedback(android.view.HapticFeedbackConstants.VIRTUAL_KEY)
        } catch (_: Exception) {}

        // ✅ FIX BUG 1: nếu vừa mới repeat (đã giữ >400ms và Runnable đã xoá
        // ít nhất 1 lần), KHÔNG fire thêm 1 lần onKeyPress khi nhả tay —
        // tránh xoá thừa 1 ký tự ở cuối mỗi lần hold.
        if (!(key.key.keyCode == -1 && wasRepeating)) {
            listener?.onKeyPress(key.key.keyCode)
        }
    }
    return true
}
```

**Quy tắc rõ ràng sau fix:**
- Tap nhanh (nhả tay trước 400ms, Runnable chưa kịp chạy lần nào) →
  `wasRepeating` vẫn `true` (được set ngay ở `ACTION_DOWN`) nhưng Runnable
  **chưa fire lần nào** → cần đảm bảo tap nhanh vẫn xoá đúng 1 ký tự.

  **Lưu ý quan trọng cho agent:** với code hiện tại, `isBackspaceRepeating`
  được set `true` ngay tại `ACTION_DOWN`, không phân biệt được "vừa set xong,
  Runnable chưa kịp chạy" với "đã repeat được vài lần". Cần thêm 1 biến đếm
  hoặc timestamp để phân biệt 2 trường hợp:

```kotlin
private var backspaceHasRepeated = false   // ✅ thêm biến mới

// Trong backspaceRepeatRunnable.run():
override fun run() {
    if (isBackspaceRepeating) {
        backspaceHasRepeated = true   // ✅ đánh dấu đã thực sự repeat ít nhất 1 lần
        listener?.onKeyPress(-1)
        touchHandler.postDelayed(this, 70)
    }
}

// ACTION_DOWN: reset cờ khi bắt đầu nhấn mới
if (key != null && key.key.keyCode == -1) {
    isBackspaceRepeating = true
    backspaceHasRepeated = false   // ✅ reset mỗi lần nhấn mới
    touchHandler.postDelayed(backspaceRepeatRunnable, 400)
}

// ACTION_UP: dùng backspaceHasRepeated thay vì wasRepeating
if (!(key.key.keyCode == -1 && backspaceHasRepeated)) {
    listener?.onKeyPress(key.key.keyCode)
}
isBackspaceRepeating = false
touchHandler.removeCallbacks(backspaceRepeatRunnable)
```

Với sửa này: tap nhanh (<400ms, chưa repeat lần nào) → `backspaceHasRepeated
== false` → `ACTION_UP` vẫn gọi `onKeyPress(-1)` đúng 1 lần → xoá đúng 1 ký
tự. Giữ lâu (>400ms, đã repeat ít nhất 1 lần qua Runnable) →
`backspaceHasRepeated == true` → `ACTION_UP` **không** gọi thêm, tránh xoá
thừa, và quan trọng nhất: **Runnable đã bị `removeCallbacks` dứt điểm ngay
tại `ACTION_UP`**, không còn chạy ngầm sau khi nhả tay — đây chính là fix cho
đúng triệu chứng "gõ lại cũng tự bị xoá" bạn báo cáo.

---

## BUG 2 — Tắt tiếng Việt: xác nhận đúng như `plan8.md` mô tả, đồng thuận tuyệt đối với cả 4 review

### Xác nhận qua code — bug Telex đã regress lại đúng như trước

```kotlin
if (telexProcessor == null) {
    telexProcessor = VietnameseTelexProcessor()
} else {
    telexProcessor!!.reset()   // ❌ comment nói "clean state if we just cleared
                                //    selection" nhưng thực chất chạy vô điều
                                //    kiện mỗi ký tự, không chỉ khi vừa clear
                                //    selection — đúng bug cũ đã quay lại
}
```
Nút `EN`/`LANG` vẫn còn trên `QuickToolbar`, `currentLanguage`/`telexProcessor`
vẫn còn trong `SmartClipboardIME`. Xác nhận chính xác như `plan8.md`.

### Đồng thuận: đóng băng VI, không sửa Telex trong đợt này

Không có bất đồng nào giữa `plan8.md` và 4 review về điểm này — hiếm có sự
đồng thuận tuyệt đối như vậy trong toàn bộ quá trình review dự án này. Tôi
đồng ý: Telex đã bị vá đi vá lại nhiều lần (`plan5`, `plan7`, giờ lại `plan8`)
với cùng 1 loại bug tái phát — dấu hiệu cho thấy cần thiết kế lại module này
từ đầu như 1 hạng mục riêng, không nên tiếp tục vá từng phần trong lúc đang
ưu tiên ổn định English-only.

### Fix — đóng băng đúng cách (không chỉ set mặc định EN)

**`SmartClipboardIME.kt`:**

```kotlin
// ✅ FIX BUG 2: đóng băng Vietnamese — không khởi tạo, không gọi processor
// currentLanguage và InputLanguage giữ nguyên khai báo (không xoá) để dễ
// khôi phục sau này, nhưng luôn cố định EN, không còn đường nào đổi sang VI.
private var currentLanguage = InputLanguage.EN   // không đổi được nữa
private var telexProcessor: VietnameseTelexProcessor? = null   // không bao giờ khởi tạo

// Trong onKeyPressed(), else branch — XOÁ HẲN nhánh kiểm tra
// currentLanguage == VI, để mọi ký tự chữ cái luôn đi thẳng qua commit
// path bên dưới:
// (xoá đoạn "if (currentLanguage == InputLanguage.VI && ...) { ... }")
```

Trong `onToolbarShortcut()`, xoá hẳn case `"LANG"`:
```kotlin
private fun onToolbarShortcut(shortcut: String) {
    val ic = currentInputConnection ?: return
    when (shortcut) {
        ";" -> { ... }        // giữ nguyên
        "@" -> { ... }         // giữ nguyên
        ".com" -> { ... }      // giữ nguyên
        "EMOJI" -> { ... }     // giữ nguyên
        "SWITCH_KEYBOARD" -> { ... }   // giữ nguyên
        // ✅ FIX BUG 2: đã xoá case "LANG"
    }
}
```

Trong `onFinishInputView()`, xoá dòng `telexProcessor?.reset()` (không còn ý
nghĩa vì `telexProcessor` không bao giờ được khởi tạo nữa — giữ lại không sai
nhưng là dead code).

**`QuickToolbar` class:** xoá hẳn `langBtn` và logic khởi tạo nút EN:
```kotlin
init {
    orientation = HORIZONTAL
    setPadding(4, 2, 4, 2)
    setBackgroundColor(0xFFF0F0F0.toInt())

    // ✅ FIX BUG 2: đã xoá hoàn toàn langBtn (nút EN/VI)

    val shortcuts: List<Pair<String, String>> = listOf(
        ";" to ";", "@" to "@", ".com" to ".com",
    )
    // ... giữ nguyên phần còn lại
}

// ✅ FIX BUG 2: có thể xoá fun setLanguage() nếu không còn nơi nào gọi
```

**Không xoá file `VietnameseTelexProcessor.kt`** — giữ nguyên trong source để
dùng lại khi thiết kế module VI riêng sau này, đúng như cả `plan8.md` và 4
review đều thống nhất.

---

## THỨ TỰ THỰC HIỆN (không gộp, làm và test tuần tự)

```
Bug 0 (word-boundary ';' regression)  →  test snippet expansion qua bàn phím vật lý
        ↓
Bug 1 (Backspace ACTION_UP)           →  test tap/hold/nhả rồi gõ tiếp
        ↓
Bug 2 (đóng băng Vietnamese)          →  test không còn nút EN/VI, gõ dd → "dd"
```

Bug 0 đứng đầu vì nó ảnh hưởng tính năng lõi và có khả năng đang bị bug ngay
lúc này mà bạn chưa nhận ra do quen dùng nút `;` trên toolbar thay vì phím
`;` ở layer Symbols.

---

## TEST MATRIX BẮT BUỘC

| # | Bước | Kỳ vọng |
|---|---|---|
| 1 | Ở layer Symbols (`?123`), gõ phím `;` trực tiếp (không dùng nút toolbar), gõ tiếp `email`, rồi Space | Expand đúng thành nội dung snippet |
| 2 | Gõ `;;` bằng phím Symbols (không dùng toolbar) | Ra đúng 1 dấu `;`, không expand |
| 3 | Dùng nút `;` trên toolbar để gõ `;email` + Space | Vẫn expand đúng (hồi quy — path này chưa bao giờ hỏng) |
| 4 | Gõ `;email.` (dấu chấm liền, không cách) | Vẫn expand đúng, giữ dấu `.` theo sau |
| 5 | Tap Backspace 1 lần (nhả tay ngay) | Xoá đúng 1 ký tự |
| 6 | Giữ Backspace >400ms rồi nhả tay | Xoá liên tục trong lúc giữ, dừng ngay khi nhả — không xoá thừa |
| 7 | Giữ Backspace, nhả tay, gõ tiếp chữ khác ngay | Chữ mới gõ hiển thị bình thường, KHÔNG bị tự động xoá |
| 8 | Giữ Backspace, trượt tay ra khỏi phím trước khi nhả | Dừng xoá ngay khi rời phím (hồi quy — đã đúng từ trước) |
| 9 | Mở QuickToolbar | Không còn thấy nút `EN`/`VI` |
| 10 | Gõ `dd`, `aa` | Ra đúng `dd`, `aa` (chữ thường, không cố ghép thành `đ`, `â`) |
| 11 | Select All rồi gõ chữ mới | Thay thế đúng toàn bộ (hồi quy — đã đúng từ batch trước) |