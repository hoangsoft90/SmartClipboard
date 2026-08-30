# Smart Clipboard Keyboard — Bug Fix Pass + Switch Keyboard Button (plan6_final.md)

> Verify trực tiếp trên `SmartKeyboardView.kt` + `SmartClipboardIME.kt` hiện
> tại, đối chiếu docs chính thức Android `InputConnection`/`BaseInputConnection`.
> Phạm vi: CHỈ 2 file này. Không đụng Telex mapping, không đụng lifecycle đã
> fix ở batch trước, không thêm one-shot Shift / long-press Backspace.
>
> **Cập nhật:** bổ sung Bug 4 — thêm nút chuyển sang bàn phím khác ngay trong
> lúc Smart Clipboard đang active (tính năng mới, không phải bug, nhưng gộp
> chung batch vì cùng phạm vi 2 file và cùng đợt release).

---

## TÓM TẮT (đã xác nhận qua code + 1 tính năng mới)

| # | Hạng mục | Vị trí | Loại |
|---|---|---|---|
| 1 | Shift bật/tắt nhưng phím row1/row2 luôn hiện HOA | `SmartKeyboardView.kt` — `row1`, `row2`, `drawRow`/`drawRowCentered` | Bug — ✅ xác nhận 100% |
| 2 | Layer `?123` không có phím Backspace | `SmartKeyboardView.kt` — `symbolRow1..4`, `drawSymbolRow4` | Bug — ✅ xác nhận 100% |
| 3 | Select All rồi Backspace chỉ xoá 1 ký tự | `SmartClipboardIME.kt` — `handleBackspace()` | Bug — ✅ xác nhận 100% |
| 4 | Thêm nút chuyển bàn phím khác khi đang active | `SmartClipboardIME.kt` — `QuickToolbar`, `onToolbarShortcut()` | Tính năng mới |

**Phát hiện bổ sung (không nằm trong 3 báo cáo gốc nhưng liên quan trực tiếp Bug 1):** popup xem trước phím (key preview) cũng luôn hiện label HOA gốc bất kể trạng thái Shift, vì `keyRects` lưu `Key` gốc (chưa qua điều chỉnh hoa/thường) — kể cả ở `row3` vốn đã có logic hiển thị đúng trên canvas. Nên sửa cùng lúc với Bug 1 vì cùng nguyên nhân gốc (thiếu 1 nguồn label thống nhất).

---

## BUG 1 — Shift không đổi label hiển thị

### Bằng chứng

```kotlin
// row1/row2: label CỐ ĐỊNH viết hoa
private val row1 = listOf("Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P")
    .map { Key(it, it[0].code) }
private val row2 = listOf("A", "S", "D", "F", "G", "H", "J", "K", "L")
    .map { Key(it, it[0].code) }
```
`drawRow()`/`drawRowCentered()` vẽ thẳng `key.label` không qua bất kỳ biến đổi nào
theo `isShifted`. Trong khi `drawRow3()` (hàng Z-X-C...) **đã có** logic đúng:
```kotlin
val ch = if (isShifted) key.label.uppercase() else key.label
val displayKey = key.copy(label = ch)
```
nhưng **chỉ áp dụng cho row3**, không dùng chung cho row1/row2. Đây đúng là bug
UI/hiển thị — phần logic gõ ký tự thật (`getCharForKey()`) đã đúng từ trước
(đã tự `.lowercaseChar()` rồi mới xét `isShifted`), user chỉ bị đánh lừa bởi UI.

**Bug phụ liên quan (mới phát hiện):** kể cả `row3`, dòng
`keyRects.add(KeyRect(rect, key))` dùng `key` (bản gốc, KHÔNG phải `displayKey`
đã điều chỉnh hoa/thường) — nghĩa là popup preview khi nhấn giữ phím
(`onKeyPreview` → `key.key.label`) **luôn hiện label gốc, không phản ánh
Shift**, dù canvas vẽ đúng. Cần sửa cùng lúc.

### Fix

Thêm 1 hàm dùng chung, áp dụng cho **mọi nơi hiển thị label chữ cái** (vẽ trên
canvas VÀ preview popup):

```kotlin
// Thêm vào SmartKeyboardView, gần getCharForKey()
private fun displayLabel(key: Key): Key {
    if (key.isSpecial || key.label.length != 1 || !key.label[0].isLetter()) return key
    val display = if (isShifted) key.label.uppercase() else key.label.lowercase()
    return key.copy(label = display)
}
```

Sửa `drawRow()` và `drawRowCentered()` để dùng `displayLabel(key)` khi vẽ VÀ
khi lưu vào `keyRects` (đảm bảo preview cũng đúng):

```kotlin
private fun drawRow(
    canvas: Canvas, keys: List<Key>,
    y: Float, totalWidth: Float,
    pad: Int, margin: Int, height: Int, scale: Float
) {
    val keyWidth = ((totalWidth - 2 * pad - (keys.size - 1) * margin) / keys.size).toInt()
    var x = pad.toFloat()

    for (key in keys) {
        val displayKey = displayLabel(key)   // ✅ FIX
        val rect = Rect(x.toInt(), y.toInt(), x.toInt() + keyWidth, y.toInt() + height)
        drawKey(canvas, rect, displayKey, scale)
        keyRects.add(KeyRect(rect, displayKey))   // ✅ FIX: lưu displayKey, không phải key gốc
        x += keyWidth + margin
    }
}
```
Áp dụng đúng pattern tương tự cho `drawRowCentered()` (row2).

**Sửa `drawRow3()`** để cũng lưu `displayKey` vào `keyRects` thay vì `key` gốc
(khắc phục bug preview cho cả row3, hiện tại vẽ đúng nhưng lưu sai):
```kotlin
for (key in row3Base) {
    val displayKey = displayLabel(key)   // dùng chung hàm mới, thay vì tính riêng
    val rect = Rect(x.toInt(), y.toInt(), x.toInt() + letterWidth, y.toInt() + height)
    drawKey(canvas, rect, displayKey, scale)
    keyRects.add(KeyRect(rect, displayKey))   // ✅ FIX: lưu displayKey
    x += letterWidth + margin
}
```

**Lưu ý quan trọng — KHÔNG đổi `toggleShift()`:** giữ nguyên hành vi toggle
vĩnh viễn hiện tại (bật/tắt đơn giản). **Không** thêm one-shot shift hay
double-tap Caps Lock trong patch này — đây là task UX riêng, làm sau khi bug
hiển thị đã pass test.

**Không cần đổi `getCharForKey()`** — logic gõ ký tự thực tế đã đúng từ
trước, chỉ UI hiển thị sai.

---

## BUG 2 — Layer `?123` (Symbols) không có Backspace

### Bằng chứng

```kotlin
private val symbolRow1 = listOf("1","2","3","4","5","6","7","8","9","0").map { ... }
private val symbolRow2 = listOf("@","#","$","%","&","*","-","+","(",")").map { ... }
private val symbolRow3 = listOf("!","\"","'",":",";","/","?").map { ... }
private val symbolRow4 = listOf(
    Key("ABC", -6, true), Key(",", ','.code), Key("", -2),
    Key(".", '.'.code), Key("↵", -3, true)
)
```
Không có `Key("⌫", -1, ...)` ở bất kỳ hàng nào trong 4 hàng symbol. `keyRects`
khi ở layer Symbols vì vậy **không bao giờ chứa keyCode -1** — không phải lỗi
touch detection, phím xoá **không tồn tại** trên layout này.

### Fix — đặt Backspace ở góc phải hàng 3 (đúng vị trí muscle memory, không phải hàng 4)

Sửa `drawRowCentered(canvas, symbolRow3, ...)` (đang gọi hàm centered cho
symbolRow3) thành một hàm vẽ riêng tương tự `drawRow3()` bên layer chữ, thêm
Backspace ở cuối:

```kotlin
// Trong onDraw(), nhánh SYMBOLS — đổi lời gọi:
} else {
    drawRow(canvas, symbolRow1, y, w, mp, mm, mh, scale)
    y += mh + mm
    drawRow(canvas, symbolRow2, y, w, mp, mm, mh, scale)
    y += mh + mm
    drawSymbolRow3(canvas, y, w, mp, mm, mh, scale)   // ✅ FIX: hàm mới thay vì drawRowCentered
    y += mh + mm
    drawSymbolRow4(canvas, y, w, mp, mm, mh, scale)
}
```

Hàm mới `drawSymbolRow3`, dùng chung `handleBackspace()` sẵn có qua keyCode
`-1` (không viết logic xoá riêng):

```kotlin
private fun drawSymbolRow3(
    canvas: Canvas, y: Float, totalWidth: Float,
    pad: Int, margin: Int, height: Int, scale: Float
) {
    val backspaceKey = Key("⌫", -1, true)
    val specialWidth = (60 * scale).toInt()
    val symWidth = ((totalWidth - 2 * pad - margin - specialWidth) / symbolRow3.size).toInt()

    var x = pad.toFloat()
    for (key in symbolRow3) {
        val rect = Rect(x.toInt(), y.toInt(), x.toInt() + symWidth, y.toInt() + height)
        drawKey(canvas, rect, key, scale)
        keyRects.add(KeyRect(rect, key))
        x += symWidth + margin
    }

    // Backspace — góc phải, cùng hàng, đúng vị trí muscle memory như layer chữ
    val bsRect = Rect(x.toInt(), y.toInt(), x.toInt() + specialWidth, y.toInt() + height)
    drawKey(canvas, bsRect, backspaceKey, scale)
    keyRects.add(KeyRect(bsRect, backspaceKey))
}
```

**Không đổi `symbolRow4`** — giữ nguyên `ABC | , | Space | . | ↵` như hiện tại,
không nhét thêm Backspace vào hàng 4 (tránh làm nhỏ phím Space/Enter, tránh
sai vị trí muscle memory so với layer chữ — layer chữ có Backspace ở hàng 3
góc phải, symbol layer nên nhất quán).

`onKeyPressed(-1)` trong `SmartClipboardIME.kt` **không cần sửa gì** — đã xử lý
đúng Backspace, chỉ cần layout có phím gọi tới đúng keyCode này.

---

## BUG 3 — Select All + Backspace chỉ xoá 1 ký tự

### Bằng chứng

```kotlin
private fun handleBackspace(ic: InputConnection) {
    if (currentLanguage == InputLanguage.VI && telexProcessor != null && !telexProcessor!!.isEmpty()) {
        ... // nhánh Telex, cũng không xét selection
    }
    if (typingBuffer.isNotEmpty()) { typingBuffer.deleteCharAt(...) ; updateSuggestions(...) }
    ic.deleteSurroundingText(1, 0)   // ← luôn xoá đúng 1 ký tự, bất kể có selection hay không
    lastCommittedChar = null
}
```

### Xác nhận qua docs chính thức Android — vì sao `deleteSurroundingText` sai khi có selection

Theo tài liệu chính thức Android: *"cursor và selection về bản chất là một —
cursor chỉ là trường hợp đặc biệt của selection có kích thước 0. Mọi API thao
tác 'trước cursor' sẽ thao tác trước **điểm bắt đầu** của selection nếu có."*
→ `deleteSurroundingText(1, 0)` khi đang có selection 11 ký tự sẽ xoá 1 ký tự
**trước điểm bắt đầu vùng chọn** — không đụng gì tới 11 ký tự đã chọn. Đây
chính xác là hiện tượng bạn quan sát được.

### Fix — chỉ cần sửa `handleBackspace()`, dùng đúng pattern chuẩn cộng đồng Android

```kotlin
private fun handleBackspace(ic: InputConnection) {
    // FIX BUG 3: nếu đang có vùng chọn (selection), xoá toàn bộ vùng chọn
    // bằng commitText("", 1) — deleteSurroundingText KHÔNG xử lý selection,
    // nó luôn thao tác quanh cursor/điểm đầu selection.
    val selected = ic.getSelectedText(0)
    if (!selected.isNullOrEmpty()) {
        ic.commitText("", 1)
        typingBuffer.clear()
        telexProcessor?.reset()
        lastCommittedChar = null
        lastWasSpace = false
        updateSuggestions("")
        return   // KHÔNG gọi thêm deleteSurroundingText — đã xoá xong
    }

    // --- Phần dưới giữ nguyên y hệt code hiện tại ---
    if (currentLanguage == InputLanguage.VI && telexProcessor != null && !telexProcessor!!.isEmpty()) {
        val composingText = telexProcessor!!.onBackspace()
        if (typingBuffer.isNotEmpty()) typingBuffer.deleteCharAt(typingBuffer.length - 1)
        if (composingText.isNotEmpty()) {
            ic.setComposingText(composingText, 1)
        } else {
            ic.finishComposingText()
            ic.deleteSurroundingText(1, 0)
        }
        updateSuggestions(typingBuffer.toString())
        lastCommittedChar = null
        return
    }

    if (typingBuffer.isNotEmpty()) {
        typingBuffer.deleteCharAt(typingBuffer.length - 1)
        updateSuggestions(typingBuffer.toString())
    }
    ic.deleteSurroundingText(1, 0)
    lastCommittedChar = null
}
```

### ⚠️ Phản biện lại đề xuất "áp dụng check-selection cho MỌI phím" của cả 4 bản review

Cả `plan6.md`, `plan6_review1-4.md` đều đề xuất viết thêm hàm
`clearSelectionIfExists()` và gọi ở **đầu `onKeyPressed()` cho mọi phím**
(chữ, số, space...), không chỉ Backspace. Tôi đã tra cứu kỹ hành vi mặc định
của Android framework và **không đồng ý áp dụng toàn bộ đề xuất này** — lý do
cụ thể:

Theo triển khai chuẩn `BaseInputConnection.replaceText()` (dùng bởi hầu hết
`EditText`/editor chuẩn khi app không tự viết `InputConnection` riêng):
khi **không có composing span nào đang hoạt động**, `commitText()` tự động
dùng **vùng selection hiện tại** làm phạm vi thay thế. Nói cách khác:

> **Đối với ký tự thường (mode EN, dùng `ic.commitText(char, 1)` trực
> tiếp)**: nếu user đang bôi đen "Hello" rồi gõ "X", Android **tự động** thay
> thế "Hello" bằng "X" — **không cần code gì thêm**, đây là hành vi built-in
> của framework trên các editor chuẩn.

Việc thêm `clearSelectionIfExists()` và gọi cho **mọi phím** như 4 review đề
xuất là dư thừa cho nhánh EN, tăng bề mặt code phải bảo trì, và có rủi ro nhỏ
gây xoá 2 lần / nhấp nháy nếu logic không khớp hoàn toàn với hành vi mặc định
sẵn có của framework.

**Trường hợp DUY NHẤT thực sự cần xử lý selection thủ công ngoài Backspace là
nhánh Vietnamese Telex** (`ic.setComposingText(...)`), vì composing span và
selection là 2 khái niệm khác nhau trong Android IME — khi bắt đầu một
composing span mới trong lúc đang có sẵn 1 selection (không phải composing),
hành vi không được đảm bảo tự động đúng như `commitText`. Cần xử lý riêng chỉ
ở điểm này:

```kotlin
// Trong onKeyPressed(), nhánh Telex — thêm đúng 1 đoạn TRƯỚC khi gọi setComposingText:
if (currentLanguage == InputLanguage.VI && ch.length == 1 && ch[0].isLetter()) {
    // FIX: nếu đang có selection, xoá trước khi bắt đầu composing mới —
    // setComposingText KHÔNG tự động thay thế selection như commitText.
    val selected = ic.getSelectedText(0)
    if (!selected.isNullOrEmpty()) {
        ic.commitText("", 1)
        typingBuffer.clear()
    }
    if (telexProcessor == null) telexProcessor = VietnameseTelexProcessor()
    else telexProcessor!!.reset()   // đảm bảo không dính state cũ nếu vừa xoá selection
    val composingText = telexProcessor!!.onChar(ch[0])
    typingBuffer.append(ch)
    ic.setComposingText(composingText, 1)
    lastCommittedChar = composingText.lastOrNull()
    lastWasSpace = false
    updateSuggestions(typingBuffer.toString())
    return
}
```

**Trước khi viết đoạn code trên, hãy tự test 30 giây trên máy thật:** bôi đen
1 đoạn text (mode EN, không bật VI), gõ 1 chữ cái bất kỳ. Nếu chữ cũ đã tự mất
đúng như kỳ vọng (rất có khả năng là ĐÚNG theo hành vi framework) → xác nhận
nhánh EN không cần sửa gì, chỉ cần patch Backspace (Bug 3) + nhánh VI ở trên
là đủ. Nếu sau khi test vẫn sai (một số app/WebView có thể override hành vi
mặc định) → lúc đó mới thêm `clearSelectionIfExists()` cho nhánh EN, và nên
scope hẹp (chỉ gọi trước `ic.commitText(finalChar...)`, không cần áp dụng cho
Space/Enter/Tab/toolbar shortcut vốn hiếm khi user bôi đen rồi bấm).

---

## HẠNG MỤC 4 — Thêm nút chuyển sang bàn phím khác

### Mục tiêu

Khi Smart Clipboard Keyboard đang active, user cần 1 nút để mở dialog hệ
thống chọn bàn phím khác (Gboard, Samsung Keyboard...) mà không phải rời khỏi
app đích và vào Settings thủ công.

### API sử dụng — không cần quyền đặc biệt

`InputMethodManager.showInputMethodPicker()` mở đúng dialog hệ thống liệt kê
mọi bàn phím đã bật trong Settings. Đây là API tiêu chuẩn, gọi được trực tiếp
từ trong `InputMethodService`, không cần khai báo permission gì thêm, không
kích hoạt lại cảnh báo bảo mật (cảnh báo "có thể đọc mọi thứ bạn gõ" chỉ hiện
1 lần khi **bật** IME trong Settings, không hiện lại khi mở picker để **chọn**
giữa các IME đã bật).

### Vị trí đặt nút — vào `QuickToolbar`, không đụng `row4` Canvas

Chọn `QuickToolbar` (LinearLayout có sẵn, đang chứa EN/VI, `;` `@` `.com`,
emoji) thay vì thêm phím vào `row4` vẽ tay bằng Canvas — vì `QuickToolbar` chỉ
cần `addView()` một `TextView`, không phải tính lại `Rect`/toạ độ như sửa
`drawRow4()`. Rủi ro thấp hơn nhiều so với động vào layout Canvas đã ổn định
sau khi vừa fix Bug 1/2.

### Fix — `SmartClipboardIME.kt`

**1. Thêm import** (đầu file, cạnh các import `android.view.inputmethod.*` đã có):
```kotlin
import android.view.inputmethod.InputMethodManager
```

**2. Thêm nút vào `QuickToolbar`** — đặt cạnh nút emoji (cuối thanh toolbar):
```kotlin
class QuickToolbar(context: Context, private val onShortcut: (String) -> Unit) : LinearLayout(context) {
    // ... giữ nguyên phần khởi tạo langBtn, shortcuts, emoji hiện có ...

    init {
        // ... giữ nguyên toàn bộ code hiện tại ...

        // Divider trước nút chuyển bàn phím
        val switchDivider = View(context).apply {
            layoutParams = LayoutParams(1, LayoutParams.MATCH_PARENT).apply {
                setMargins(4, 8, 4, 8)
            }
            setBackgroundColor(0xFFCCCCCC.toInt())
        }
        addView(switchDivider)

        // ✅ FIX HẠNG MỤC 4: nút chuyển bàn phím
        val switchKeyboardBtn = TextView(context).apply {
            text = "🌐"
            setPadding(20, 8, 20, 8)
            textSize = 18f
            setBackgroundColor(0x00000000)
            setOnClickListener { onShortcut("SWITCH_KEYBOARD") }
        }
        addView(switchKeyboardBtn)
    }

    fun setLanguage(lang: String) { langBtn.text = lang }
}
```

**3. Xử lý shortcut mới trong `onToolbarShortcut()`:**
```kotlin
private fun onToolbarShortcut(shortcut: String) {
    val ic = currentInputConnection ?: return
    when (shortcut) {
        ";" -> { ... }      // giữ nguyên
        "@" -> { ... }       // giữ nguyên
        ".com" -> { ... }    // giữ nguyên
        "EMOJI" -> { ... }   // giữ nguyên
        "LANG" -> { ... }    // giữ nguyên

        // ✅ FIX HẠNG MỤC 4
        "SWITCH_KEYBOARD" -> {
            val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
            imm.showInputMethodPicker()
        }
    }
}
```

### Lưu ý cho agent

- **Không** dùng `switchToNextInputMethod()` (cơ chế "cycle" sang IME tiếp
  theo không qua dialog) — hành vi này khó đoán khi user có nhiều IME/subtype,
  dễ gây nhầm lẫn. Yêu cầu ban đầu là "nút **chọn** keyboard khác", nên
  `showInputMethodPicker()` (mở dialog cho user tự chọn) là đúng ý định nhất,
  không suy diễn thêm.
- **Không** cần `try/catch` đặc biệt — nếu vì lý do nào đó không gọi được
  (cực hiếm), Android tự bỏ qua, không crash.
- **Không** thêm nút tương tự vào `row4` Canvas trong cùng patch này — nếu
  sau này muốn thêm icon 🌐 cạnh phím Space (giống Gboard) thì làm task riêng,
  vì đụng vào tính toán `Rect` của `drawRow4()`.

---

## KHÔNG LÀM TRONG PATCH NÀY

- Không thêm one-shot Shift / double-tap Caps Lock.
- Không thêm long-press-để-lặp cho Backspace (đã cố ý bỏ ở batch trước).
- Không đổi `VietnameseTelexProcessor.kt` / mapping Telex.
- Không đổi layout `symbolRow4`, không dời Enter/Space.
- Không viết `clearSelectionIfExists()` cho toàn bộ `onKeyPressed()` trừ khi
  tự test xác nhận nhánh EN thực sự bị lỗi (xem lưu ý ở Bug 3).

---

## TEST MATRIX BẮT BUỘC SAU PATCH

| # | Bước | Kỳ vọng |
|---|---|---|
| 1 | Shift OFF, gõ `abc` | Phím hiện chữ thường, gõ ra `abc` |
| 2 | Bấm Shift, quan sát phím | Row1/Row2/Row3 đổi sang HOA ngay lập tức |
| 3 | Shift ON, gõ `abc` | Gõ ra `ABC` |
| 4 | Nhấn giữ 1 phím chữ (xem popup preview) ở cả 2 trạng thái Shift | Popup hiện đúng hoa/thường theo trạng thái hiện tại |
| 5 | Chuyển `?123` | Thấy phím ⌫ ở góc phải hàng 3 (cạnh `! " ' : ; / ?`) |
| 6 | Ở layer Symbols, bấm ⌫ | Xoá đúng 1 ký tự, không cần chuyển về ABC |
| 7 | Gõ "Hello World", Select All, bấm ⌫ | Toàn bộ text bị xoá, còn chuỗi rỗng |
| 8 | Gõ "abc", bôi đen "b", bấm ⌫ | Còn lại "ac" |
| 9 | Mode EN: Select All "Hello", gõ "X" | Kỳ vọng: "X" thay thế toàn bộ (nếu framework xử lý đúng mặc định — xem ghi chú Bug 3) |
| 10 | Mode VI: bôi đen "xin chào", gõ `aa` | "xin chào" biến mất, hiện composing `â` (không dính chữ cũ) |
| 11 | Gõ `;email` + Space (hồi quy — không liên quan patch này nhưng phải test) | Expand snippet đúng như trước |
| 12 | Đang ở Smart Clipboard Keyboard, bấm nút 🌐 trên toolbar | Dialog hệ thống "Choose input method" hiện ra, liệt kê đủ các bàn phím đã bật (Smart Clipboard, Gboard...) |
| 13 | Ở dialog trên, chọn Gboard | Bàn phím chuyển sang Gboard ngay lập tức, không crash |

Nếu test #9 **fail** (chữ cũ không tự mất khi gõ đè lên selection ở mode EN),
báo lại cụ thể app nào test (Chrome / Ghi chú / Gmail...) rồi mới bổ sung
`clearSelectionIfExists()` cho nhánh EN theo hướng dẫn ở Bug 3 — không viết
trước khi có bằng chứng cần thiết.