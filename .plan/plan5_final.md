# Smart Clipboard Keyboard — Lỗi "Tự động xoá hết ký tự" (plan5_final.md)

> Toàn bộ nội dung dưới đây được verify **trực tiếp trên code hiện tại**
> (`SmartClipboardIME.kt`, `SmartKeyboardView.kt`, `VietnameseTelexProcessor.kt`)
> — không suy đoán. Có 2 bug độc lập, cả hai đều xác nhận có thật trong code,
> cả hai đều cần sửa. Tài liệu này xếp hạng lại đúng mức độ ưu tiên dựa trên
> bằng chứng cụ thể, khác với thứ tự ưu tiên mà 4 bản review trước đưa ra.

---

## KẾT LUẬN NGAY (đọc trước khi vào chi tiết)

| Bug | Xác nhận trong code | Phạm vi ảnh hưởng | Ưu tiên |
|---|---|---|---|
| **A — Backspace chạy lặp không kiểm soát** | ✅ 100% chắc chắn | **Cả EN lẫn VI, ngay trong 1 session** | 🔴 P0 — khả năng cao là thủ phạm chính |
| **B — Composing region VI không được chốt khi đóng bàn phím** | ✅ 100% chắc chắn | **Chỉ ảnh hưởng khi đang ở mode VI** | 🔴 P0 — phải sửa song song, dù không phải nguyên nhân duy nhất |
| C — Telex backspace lệch số ký tự composed vs raw | ✅ có thật | Chỉ ảnh hưởng chất lượng gõ VI, không gây "xoá hết" | 🟡 P1 — sửa sau |

**Điểm khác biệt quan trọng nhất so với 4 bản review trước:** review2/review3/review4 đều xếp "Composing region leak" là nghi phạm số 1. Sau khi đọc code, tôi xác nhận **Bug A (Backspace runaway) mới là nghi phạm có khả năng cao hơn** cho đúng triệu chứng bạn mô tả, vì 2 lý do cụ thể verify được:

1. `currentLanguage` mặc định là `EN` (`private var currentLanguage = InputLanguage.EN`). Trừ khi bạn chủ động bấm nút chuyển ngôn ngữ sang VI, bug Composing Region (Bug B) **không thể xảy ra** — vì ở mode EN, code dùng `ic.commitText()` trực tiếp, không hề đụng tới `setComposingText()`/composing region.
2. Bug A **không cần đóng/mở lại bàn phím mới xảy ra** — nó có thể tự kích hoạt ngay trong lúc bạn đang gõ bình thường, chỉ cần bạn chạm phím Backspace một lần bất kỳ lúc nào trong lúc "tương tác với bàn phím một lúc" (đúng như bạn mô tả) — sau đó ký tự tiếp tục bị xoá ngầm mỗi 100–400ms cho tới khi bạn đóng hẳn bàn phím. Điều này khớp rất sát với câu bạn mô tả: **"lần sau type là tự động xoá hết ký tự"** — tự động xoá trong lúc gõ tiếp, không phải xoá ngay khi vừa mở lại.

---

## BUG A — Backspace chạy lặp không kiểm soát (verify từng dòng)

### Bằng chứng trong `SmartKeyboardView.kt`

```kotlin
override fun onTouchEvent(event: MotionEvent): Boolean {
    when (event.action) {
        ...
        MotionEvent.ACTION_UP -> {
            ...
            if (key != null) {
                ...
                listener?.onKeyPress(key.key.keyCode)   // ← Gọi khi NHẢ TAY, kể cả TAP đơn
            }
            return true
        }
        ...
    }
}
```

`onKeyPress` chỉ được gọi ở `ACTION_UP` — nghĩa là **mọi lần tap (kể cả chạm rất nhanh)** đều kích hoạt sự kiện, không phân biệt "tap ngắn" hay "giữ lâu".

### Bằng chứng trong `SmartClipboardIME.kt`

```kotlin
-1 -> { // Backspace
    handleBackspace(ic)
    backspaceRepeating = true                      // ← Bật lặp NGAY, không điều kiện gì
    backspaceInterval = 400L
    backspaceHandler.removeCallbacks(backspaceRepeatRunnable)
    backspaceHandler.postDelayed(backspaceRepeatRunnable, backspaceInterval)
}
```

Chỉ cần **tap Backspace một lần duy nhất**, code lập tức bật `backspaceRepeating = true` và lên lịch xoá tiếp sau 400ms. Không có điều kiện nào kiểm tra "user có đang giữ phím hay không".

```kotlin
private val backspaceRepeatRunnable = object : Runnable {
    override fun run() {
        if (backspaceRepeating) {
            val ic = inputConnection ?: return
            handleBackspace(ic)
            backspaceInterval = maxOf(100L, backspaceInterval - 100L)
            backspaceHandler.postDelayed(this, backspaceInterval)   // ← Tự lên lịch tiếp
        }
    }
}
```

Runnable này tự gọi lại chính nó liên tục, tăng tốc dần 400→300→200→100ms, **và không có bất kỳ nơi nào khác trong toàn bộ file đặt `backspaceRepeating = false`, ngoại trừ `onFinishInputView()`**. Nghĩa là: gõ chữ khác sau đó **không** dừng được vòng lặp này.

### Hệ quả thực tế (khớp với triệu chứng bạn mô tả)

```
User tap Backspace 1 lần (để sửa lỗi gõ, việc rất bình thường)
        ↓
handleBackspace() chạy — xoá 1 ký tự (đúng ý user)
        ↓
NHƯNG đồng thời: backspaceRepeating = true, hẹn giờ 400ms
        ↓
User tiếp tục gõ chữ bình thường (không đụng gì tới Backspace nữa)
        ↓
Sau 400ms: backspaceRepeatRunnable tự chạy → xoá thêm 1 ký tự NGẦM
        ↓
Sau 300ms tiếp: xoá thêm 1 ký tự NGẦM
        ↓
... liên tục mỗi 100-400ms, không dừng ...
        ↓
User cảm nhận: "đang gõ mà chữ tự động biến mất"
        ↓
Chỉ dừng khi: đóng hẳn bàn phím (onFinishInputView) — lúc đó mới reset
```

**Xác nhận: `onFinishInputView()` CÓ dừng vòng lặp đúng cách** (khác với claim của
`plan5_review1.md` rằng vòng lặp "sống sót" qua lần đóng/mở bàn phím):
```kotlin
override fun onFinishInputView(finishingInput: Boolean) {
    ...
    backspaceRepeating = false                                  // ✅ có dừng
    backspaceHandler.removeCallbacks(backspaceRepeatRunnable)    // ✅ có huỷ lịch
    ...
}
```
→ Đây là điểm tôi **phản biện lại `plan5_review1.md`**: vòng lặp không "chạy ngầm sang session 2" như review1 mô tả — nó bị dọn đúng khi đóng bàn phím. Nhưng đây không phải tin tốt, vì **bug thật sự tệ hơn**: nó có thể tàn phá ngay **trong session hiện tại**, chỉ cần bạn chạm Backspace một lần bất kỳ lúc nào — không cần đóng mở lại bàn phím mới bị.

---

## BUG B — Composing region tiếng Việt không được chốt khi đóng bàn phím

### Bằng chứng

```kotlin
override fun onFinishInputView(finishingInput: Boolean) {
    super.onFinishInputView(finishingInput)
    isKeyboardVisible = false
    handler.removeCallbacks(pollRunnable)
    backspaceRepeating = false
    backspaceHandler.removeCallbacks(backspaceRepeatRunnable)
    typingBuffer.clear()
    suggestionStrip.clear()
    dismissKeyPreview()
    isEmojiTrayVisible = false
    emojiTrayView?.visibility = View.GONE
    telexProcessor?.reset()          // ← chỉ xoá state NỘI BỘ Kotlin
    // ❌ KHÔNG có: currentInputConnection?.finishComposingText()
}
```

`telexProcessor?.reset()` xác nhận (đọc trong `VietnameseTelexProcessor.kt`) chỉ:
```kotlin
fun reset() {
    originalInput.clear()
    composedChars.clear()
    composedBuffer.clear()
}
```
— không hề gọi bất kỳ API nào của `InputConnection`. Vì vậy nếu bạn đang gõ dở một
từ tiếng Việt (chưa bấm Space/Enter/dấu câu) rồi đóng bàn phím, **vùng composing ở
phía editor đích (Chrome/Gmail/Zalo...) vẫn còn treo ở trạng thái "đang soạn thảo"
cho riêng từ dở đó**. Mở lại bàn phím, gõ ký tự tiếp theo → `setComposingText()`
mới sẽ **thay thế toàn bộ composing region cũ** (theo đúng spec chính thức của
Android `InputConnection`), tức từ tiếng Việt dở đó biến mất.

**Điều chỉnh so với mô tả "xoá cả đoạn văn bản" của `plan5.md`/`plan5_review2.md`:**
theo đúng flow code, `handleDelimiter()` đã gọi `finishComposingText()` +
`telexProcessor.commit()` sau **mỗi từ đã gõ xong** (có dấu cách/enter/dấu câu theo
sau) — nghĩa là các từ **đã hoàn thành** trong câu không nằm trong composing region
nữa, chỉ có từ **cuối cùng, dở dang** lúc đóng bàn phím mới bị treo. Do đó phạm vi
mất dữ liệu thực tế nhiều khả năng là **từ tiếng Việt cuối cùng chưa hoàn thành**,
không phải "toàn bộ đoạn văn" như một số mô tả — dù vậy hành vi này vẫn đủ để người
dùng cảm nhận là "mất chữ", cần sửa dứt điểm.

**Chỉ áp dụng khi mode = VI.** Ở mode EN, mọi ký tự dùng `ic.commitText()` trực
tiếp — không có composing region — nên Bug B **không thể** là nguyên nhân nếu bạn
test ở mode EN (mặc định của app).

---

## BUG C — Telex backspace lệch số ký tự (đã đồng thuận, sửa sau)

Xác nhận trong `VietnameseTelexProcessor.kt`:
```kotlin
fun onBackspace(): String {
    if (originalInput.isNotEmpty()) {
        originalInput.removeAt(originalInput.size - 1)
        composedChars.removeAt(composedChars.size - 1)   // luôn xoá đúng 1 phần tử
        rebuildComposedBuffer()
    }
    return composedBuffer.toString()
}
```
Khi `"aa"` đã compose thành `"â"` (2 ký tự gốc → 1 ký tự composed), backspace chỉ
xoá đúng 1 phần tử trong `composedChars` (vốn đã chỉ còn 1 phần tử là `'â'`), nên
backspace 1 lần sau khi gõ `aa` sẽ xoá sạch luôn cả `â`, ra chuỗi rỗng, thay vì lùi
về `a` như hành vi Telex chuẩn. **Bug có thật, nhưng không giải thích được hiện
tượng "xoá hết khi đang gõ tiếp"** — đúng như 4 bản review đã đồng thuận. Xếp sau
Bug A và B.

---

## CÁCH XÁC ĐỊNH CHÍNH XÁC BẠN ĐANG GẶP BUG NÀO (làm trước khi sửa code)

Vì Bug A và Bug B có triệu chứng bề ngoài giống nhau nhưng nguyên nhân khác hẳn,
hãy tự test theo bảng sau **trước khi yêu cầu agent sửa** — điều này giúp xác nhận
patch có thật sự dứt điểm hay không sau khi sửa:

| # | Bước test | Nếu lỗi xảy ra | Nếu KHÔNG lỗi |
|---|---|---|---|
| 1 | Mở app ở mode **EN** (mặc định). Gõ liên tục 1 câu dài **không đụng phím Backspace** | → | Nếu không lỗi ở bước này nhưng lỗi khi có chạm Backspace ở bước 2, xác nhận **Bug A** |
| 2 | Mode EN. Gõ vài chữ, **tap Backspace đúng 1 lần**, rồi tiếp tục gõ bình thường không chạm gì thêm | Ký tự tự mất dần trong lúc gõ tiếp → **Bug A xác nhận 100%** | Không mất → Bug A đã hết ảnh hưởng |
| 3 | Chuyển mode **VI**. Gõ 1 từ tiếng Việt **chưa bấm Space** (vd gõ dở `"vieej"`), đóng bàn phím (back hoặc chuyển app), mở lại, gõ tiếp 1 ký tự | Từ dở biến mất, bị ký tự mới ghi đè → **Bug B xác nhận** | Không mất → Bug B đã hết ảnh hưởng |

---

## PATCH TỐI THIỂU (chỉ sửa đúng 2 file, không đụng Telex mapping)

### File: `SmartClipboardIME.kt`

**1. Sửa Backspace — chỉ lặp khi thực sự giữ phím, dừng ngay khi nhả tay**

Vấn đề gốc: `onKeyPress` hiện chỉ có 1 sự kiện duy nhất (fire ở `ACTION_UP`), không
phân biệt được "tap" và "giữ". Cách sửa đúng và an toàn nhất, **không cần sửa
`SmartKeyboardView.kt`**: bỏ hẳn cơ chế tự-lặp-vô-điều-kiện, thay bằng chỉ xoá
**đúng 1 ký tự mỗi lần `onKeyPress(-1)` được gọi** — tức mỗi lần user tap/nhả tay
khỏi phím Backspace chỉ xoá đúng 1 ký tự, giống hành vi bàn phím chuẩn khi không
giữ lâu:

```kotlin
-1 -> { // Backspace — FIX: chỉ xoá 1 ký tự mỗi lần nhả tay, KHÔNG tự lặp
    handleBackspace(ic)
    // Đã loại bỏ hoàn toàn: backspaceRepeating = true + postDelayed(...)
    // Lý do: onKeyPress hiện tại fire ở ACTION_UP nên không có cách phân biệt
    // tap ngắn vs giữ lâu — bật auto-repeat vô điều kiện gây xoá ngầm không kiểm
    // soát được (xem BUG A trong plan5_final.md). Long-press-to-repeat cần
    // ACTION_DOWN/ACTION_UP riêng biệt từ SmartKeyboardView — để lại cho task
    // sau, KHÔNG làm trong patch này để tránh mở rộng phạm vi.
}
```

Đồng thời **xoá hẳn** các phần liên quan không còn dùng để tránh dead code gây
nhầm lẫn sau này:
```kotlin
// Xoá các biến/hàm sau (không còn được gọi ở đâu sau patch):
// private var backspaceRepeating = false
// private var backspaceInterval = 400L
// private val backspaceHandler = Handler(Looper.getMainLooper())
// private val backspaceRepeatRunnable = object : Runnable { ... }
// private fun stopBackspaceRepeat() { ... }
```
Và trong `onFinishInputView()`, xoá 2 dòng không còn cần thiết:
```kotlin
// Xoá:
// backspaceRepeating = false
// backspaceHandler.removeCallbacks(backspaceRepeatRunnable)
```

> **Lưu ý quan trọng cho agent:** patch này **cố ý bỏ tính năng "giữ Backspace để
> xoá liên tục"** — đây là đánh đổi chấp nhận được để dứt điểm bug nghiêm trọng
> ngay lập tức. Long-press-repeat là tính năng UX phụ, **không phải điều kiện để
> ship**, có thể làm lại đúng cách ở task riêng sau (cần tách `ACTION_DOWN` bắt đầu
> đếm giờ và `ACTION_UP`/`ACTION_CANCEL` dừng hẳn — đòi hỏi sửa cả
> `SmartKeyboardView.kt` để expose 2 sự kiện riêng, ngoài phạm vi patch này).

**2. Chốt composing region khi đóng bàn phím VÀ khi bắt đầu session mới**

Thêm override `onStartInput()` (hiện chưa có) và sửa `onFinishInputView()`:

```kotlin
override fun onStartInput(info: EditorInfo?, restarting: Boolean) {
    super.onStartInput(info, restarting)
    // FIX BUG B: chốt mọi composing region còn sót từ session trước —
    // phòng trường hợp onFinishInputView của session trước không kịp chạy
    // (Android kill process, crash, hoặc restarting=true edge case).
    currentInputConnection?.finishComposingText()
}
```

```kotlin
override fun onFinishInputView(finishingInput: Boolean) {
    super.onFinishInputView(finishingInput)
    // FIX BUG B: chốt composing region TRƯỚC khi reset state nội bộ,
    // đảm bảo từ tiếng Việt dở dang được giữ nguyên trên editor đích.
    currentInputConnection?.finishComposingText()

    isKeyboardVisible = false
    handler.removeCallbacks(pollRunnable)
    typingBuffer.clear()
    suggestionStrip.clear()
    dismissKeyPreview()
    isEmojiTrayVisible = false
    emojiTrayView?.visibility = View.GONE
    telexProcessor?.reset()
}
```

**3. Bỏ cached `inputConnection` field (đồng thuận cả 4 review, rủi ro thấp, nên làm cùng lúc)**

```kotlin
// Xoá field:
// private var inputConnection: InputConnection? = null

// Trong onStartInputView(), xoá dòng: inputConnection = currentInputConnection
// Trong onFinishInput(), xoá dòng: inputConnection = null

// Mọi nơi đang dùng `inputConnection` (onKeyPressed, handleBackspace không cần
// nữa vì không còn Runnable, onToolbarShortcut, emojiTrayView callback...)
// đổi thành lấy trực tiếp:
val ic = currentInputConnection ?: return
```

### File: `SmartKeyboardView.kt`

**Không cần sửa gì** trong patch này — giữ nguyên cơ chế `ACTION_UP` hiện tại vì
đã bỏ auto-repeat ở phía IME (mục 1 ở trên), touch handling hiện tại vẫn tương
thích, không cần đổi.

---

## KHÔNG LÀM TRONG PATCH NÀY (giữ đúng phạm vi)

- Không sửa `VietnameseTelexProcessor.kt` (Bug C, mapping `uo→ư`, case handling,
  tone placement) — để task riêng sau khi Bug A/B đã xác nhận hết.
- Không làm lại tính năng giữ-Backspace-để-xoá-liên-tục — task UX riêng.
- Không đổi `typingBuffer` sang đọc trực tiếp `getTextBeforeCursor()` như review1
  đề xuất — ý tưởng đúng dài hạn nhưng không liên quan tới bug đang sửa, để tránh
  mở rộng phạm vi trong cùng 1 patch.
- Không thêm log debug vĩnh viễn vào production code — nếu cần, dùng
  `if (BuildConfig.DEBUG) Log.d(...)` và xoá trước khi merge.

---

## TEST MATRIX BẮT BUỘC SAU PATCH

| # | Mode | Bước | Kỳ vọng |
|---|---|---|---|
| 1 | EN | Gõ "hello", tap Backspace 1 lần, gõ tiếp "world" không chạm gì khác | Kết quả cuối: `hellworld` (đúng 1 ký tự bị xoá bởi Backspace, không mất thêm) |
| 2 | EN | Tap Backspace 1 lần rồi **đợi 2 giây không làm gì** | Không có ký tự nào bị xoá thêm trong lúc đợi |
| 3 | VI | Gõ dở `vieej` (chưa Space), đóng bàn phím, mở lại, gõ tiếp 1 ký tự | Không bị ghi đè mất chữ đã gõ dở (hoặc ít nhất không ảnh hưởng ký tự đã commit trước đó) |
| 4 | VI | Gõ `viejt nam;` (có dấu cách giữa từ, có dấu câu cuối) → đóng → mở lại → gõ tiếp | Câu cũ giữ nguyên |
| 5 | Bất kỳ | Gõ `;email` + Space để expand snippet, ngay sau khi vừa tap Backspace 1 lần trước đó | Expand đúng, không bị ảnh hưởng bởi vòng lặp backspace cũ (đã bỏ) |

Nếu test #1–2 **PASS** → Bug A đã hết.
Nếu test #3–4 **PASS** → Bug B đã hết.
Nếu cả 5 test PASS → coi như dứt điểm nhóm bug "tự động xoá ký tự" ở patch này,
chuyển sang xử lý Bug C (Telex quality) ở task riêng.