# Smart Clipboard Keyboard — PATCH PLAN (plan3_final.md)

> Phạm vi: CHỈ sửa 4 lỗi UI/input đã verify trực tiếp trong
> `SmartKeyboardView.kt` và `SmartClipboardIME.kt`. Đây là bản vá có giới hạn
> (quick-fix), KHÔNG phải redesign kiến trúc. Phần cache sync, trigger
> matching, escape `;;`, suggestion-commit-content đã đúng — **không đụng
> vào các phần đó**.

**Bối cảnh xác nhận trước khi sửa:** Sau khi bật keyboard "Smart Clipboard"
trong Settings, bàn phím hiện ra thô kệch, chiếm gần toàn bộ màn hình, gõ chữ
luôn ra HOA, thiếu phím Enter, nút `?123` bấm không phản ứng. Cả 4 vấn đề đã
được đọc trực tiếp trong code và xác nhận nguyên nhân chính xác — không phải
suy đoán.

---

## QUY TẮC BẮT BUỘC CHO AGENT

1. **CHỈ sửa 2 file:** `SmartKeyboardView.kt` và `SmartClipboardIME.kt`.
   Không sửa file nào khác (không đụng Dart, không đụng Manifest, không đụng
   `cache_sync_service.dart`, không đụng schema DB).
2. **Không đổi kiến trúc.** Vẫn là `View` tự vẽ bằng `Canvas` như hiện tại —
   không chuyển sang `android.inputmethodservice.KeyboardView`/XML layout,
   không thêm library bàn phím ngoài.
3. **Không thêm tính năng mới** (không thêm số, không thêm symbol layer đầy
   đủ, không thêm emoji, không thêm Vietnamese composition). Các mục này nằm
   ngoài phạm vi patch này — đã được ghi nhận là công việc dài hạn riêng.
4. Sau khi sửa, liệt kê rõ diff từng file và tự kiểm tra theo Acceptance
   Criteria ở cuối văn bản này trước khi báo hoàn thành.
5. Nếu phát hiện thêm lỗi ngoài 4 mục dưới đây trong lúc sửa, **dừng lại, báo
   cáo, không tự ý sửa thêm**.

---

## LỖI 1 — Bàn phím chiếm toàn bộ màn hình

### Nguyên nhân (đã verify trong code)

`SmartKeyboardView` là `View` tự vẽ nhưng **không override `onMeasure()`**.
Khi `InputMethodService` đo input view, không có gì giới hạn chiều cao View
này lấy, nên hệ thống cấp gần như toàn bộ không gian còn lại của màn hình.

### File: `SmartKeyboardView.kt`

**Thêm override `onMeasure()`** (đặt ngay trước `override fun onDraw`):

```kotlin
override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
    val scale = resources.displayMetrics.density
    val mh = (keyHeight * scale).toInt()
    val mm = (keyMargin * scale).toInt()
    val mp = (keyboardPadding * scale).toInt()

    // 4 hàng phím + 3 khoảng margin giữa hàng + padding trên/dưới
    val desiredHeight = mh * 4 + mm * 3 + mp * 2
    val width = MeasureSpec.getSize(widthMeasureSpec)

    setMeasuredDimension(width, desiredHeight)
}
```

Giá trị `desiredHeight` phụ thuộc `keyHeight` — sau khi sửa LỖI 2 (giảm
`keyHeight` xuống ~50), tổng chiều cao 4 hàng sẽ vào khoảng 220–260dp, đúng
tầm bàn phím hệ thống thông thường.

### File: `SmartClipboardIME.kt`

Trong `onCreateInputView()`, thêm `LayoutParams` rõ ràng khi add view (hiện
tại đang add không kèm params, dựa hoàn toàn vào default của `LinearLayout`):

```kotlin
override fun onCreateInputView(): View {
    val root = LinearLayout(this).apply {
        orientation = LinearLayout.VERTICAL
        layoutParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        )
    }

    suggestionStrip = SuggestionStrip(this)
    root.addView(
        suggestionStrip,
        LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        )
    )

    keyboardView = SmartKeyboardView(this)
    keyboardView.setOnKeyPressListener(object : SmartKeyboardView.OnKeyPressListener {
        override fun onKeyPress(keyCode: Int) {
            onKeyPressed(keyCode)
        }
    })
    root.addView(
        keyboardView,
        LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        )
    )

    return root
}
```

Dùng `WRAP_CONTENT` cho height ở mọi cấp — kết hợp với `onMeasure()` đã cố
định chiều cao thật của `SmartKeyboardView`, tổng input view sẽ co đúng theo
nội dung, không bị hệ thống ép full màn hình.

---

## LỖI 2 — Phím quá to, nhìn thô kệch

### Nguyên nhân (đã verify trong code)

```kotlin
private val keyHeight = 140  // dp-like pixels (will be scaled)
...
val mh = (keyHeight * scale).toInt()   // 140 × density(~3) ≈ 420px MỖI PHÍM
```

`140` được comment là "dp-like" nhưng lại nhân trực tiếp với `density` như
đang là dp thật — trên máy density 3, mỗi hàng phím cao tới ~420px, 4 hàng
≈ 1680px, lớn hơn nhiều so với bàn phím hệ thống chuẩn (~250-320dp tổng).

### File: `SmartKeyboardView.kt`

```kotlin
// Trước:
private val keyHeight = 140

// Sau:
private val keyHeight = 50   // dp — tổng 4 hàng ≈ 50*4 + margin/padding ≈ 230-250dp
```

Đồng thời giảm `textSize` cho tương xứng (hiện đang `48f`, quá to so với
phím cao 50dp):

```kotlin
private val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
    color = Color.BLACK
    textSize = 38f   // giảm từ 48f
    textAlign = Paint.Align.CENTER
}
```

**Lưu ý:** không cần sửa gì thêm ở các hàm `drawRow`/`drawRowCentered`/
`drawRow3`/`drawRow4` — chúng đã nhận `height`/`mh` làm tham số động, tự động
co theo giá trị `keyHeight` mới.

---

## LỖI 3 — Gõ luôn ra chữ HOA, Shift không có tác dụng

### Nguyên nhân (đã verify trong code)

Key code của các phím chữ được lưu **từ chính mã ASCII chữ HOA**:

```kotlin
private val row1 = listOf("Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P")
    .map { Key(it, it[0].code) }   // keyCode = 'Q'.code = 81 (mã HOA)
```

Và `getCharForKey` chuyển thẳng `keyCode.toChar()` — vì `keyCode` đã là mã
HOA, `ch` luôn là ký tự HOA bất kể `isShifted`:

```kotlin
fun getCharForKey(keyCode: Int): String? {
    return if (keyCode in 32..126) {
        val ch = keyCode.toChar()   // luôn 'Q', không phụ thuộc isShifted
        if (isShifted && ch.isLetter()) ch.uppercaseChar().toString() else ch.toString()
        // nhánh else vẫn trả "Q" (đã HOA sẵn) → Shift không đổi được gì
    } else null
}
```

### File: `SmartKeyboardView.kt`

```kotlin
fun getCharForKey(keyCode: Int): String? {
    return if (keyCode in 32..126) {
        val ch = keyCode.toChar().lowercaseChar()   // ✅ luôn chuẩn hoá về thường trước
        if (isShifted && ch.isLetter()) ch.uppercaseChar().toString() else ch.toString()
    } else null
}
```

**Kiểm tra chéo:** hàm `drawRow3()` đã có logic hiển thị đúng theo Shift cho
label vẽ trên phím (`val ch = if (isShifted) key.label.uppercase() else
key.label`) — đây là phần HIỂN THỊ, độc lập với `getCharForKey` (phần XỬ LÝ
KÝ TỰ THỰC TẾ gửi vào `InputConnection`). Row1 và Row2 hiện **không có** logic
tương tự cho hiển thị (label luôn vẽ HOA cố định) — đây là vấn đề UX phụ,
không bắt buộc sửa trong patch này (không ảnh hưởng chức năng gõ), nhưng nếu
muốn tiện thể sửa để nhất quán trải nghiệm, xem GHI CHÚ TÙY CHỌN cuối file.

---

## LỖI 4 — Thiếu Enter, thừa 1 phím Backspace, nút `?123` không phản ứng

### Nguyên nhân (đã verify trong code)

**4a. Không có Enter:** comment đầu file mô tả "Row 4: [?123] [Space] [.]
[Enter]" nhưng `row4` thực tế không có key code `-3`:

```kotlin
private val row4 = listOf(
    Key("?123", -6, true),
    Key(",", ','.code),
    Key("", -2),           // Space
    Key(".", '.'.code),
    Key("⌫", -1, true)     // Backspace — TRÙNG với Backspace đã có ở cuối row3
)
```

**4b. `?123` chết:** trong `SmartClipboardIME.kt`, `onKeyPressed()`'s
`when(keyCode)` chỉ xử lý `-1` đến `-5`. Với `keyCode = -6`, code rơi vào
nhánh `else` (dành cho ký tự thường), gọi `getCharForKey(-6)` → `-6` không
nằm trong `32..126` → trả `null` → `return` ngay, không có gì xảy ra.

### File: `SmartKeyboardView.kt`

Sửa `row4`: bỏ Backspace trùng, thêm Enter:

```kotlin
private val row4 = listOf(
    Key("?123", -6, true),
    Key(",", ','.code),
    Key("", -2),            // Space
    Key(".", '.'.code),
    Key("↵", -3, true)      // ✅ Enter thay cho Backspace trùng
)
```

`drawRow4()` không cần sửa gì thêm — nó vẽ theo danh sách `row4[]` đã đổi,
tự động dùng `Key("↵", -3, true)` ở đúng vị trí cuối hàng.

### File: `SmartClipboardIME.kt`

`-3` (Enter) đã có handler sẵn (`handleDelimiter(ic, '\n')`) — không cần sửa
gì thêm ở đây, chỉ cần key `-3` thực sự tồn tại trên layout (đã sửa ở trên).

Với `?123` (`-6`): phạm vi patch này **không làm symbol layer đầy đủ** (nằm
ngoài scope, cần thiết kế riêng). Thay vào đó, để nút không còn "chết" một
cách khó hiểu, thêm xử lý tạm thời: hiện Toast/log thông báo tính năng chưa
sẵn sàng, tránh im lặng khó chịu cho người dùng test:

```kotlin
// Trong onKeyPressed(), thêm case mới:
when (keyCode) {
    -1 -> handleBackspace(ic)
    -2 -> handleDelimiter(ic, ' ')
    -3 -> handleDelimiter(ic, '\n')
    -4 -> handleDelimiter(ic, '\t')
    -5 -> keyboardView.toggleShift()
    -6 -> {
        // TODO: Symbol layer — nằm ngoài phạm vi patch này.
        // Tạm thời không làm gì để tránh crash; không còn rơi vào
        // nhánh "else" (regular character) gây gọi getCharForKey(-6) vô nghĩa.
    }
    else -> {
        // giữ nguyên toàn bộ logic hiện tại (regular character, escape ;;, buffer...)
    }
}
```

---

## TỔNG HỢP DIFF CẦN THỰC HIỆN

| File | Thay đổi |
|---|---|
| `SmartKeyboardView.kt` | Thêm `onMeasure()` |
| `SmartKeyboardView.kt` | `keyHeight`: `140` → `50` |
| `SmartKeyboardView.kt` | `textPaint.textSize`: `48f` → `38f` |
| `SmartKeyboardView.kt` | `getCharForKey`: thêm `.lowercaseChar()` trước khi so `isShifted` |
| `SmartKeyboardView.kt` | `row4`: đổi `Key("⌫", -1, true)` cuối cùng thành `Key("↵", -3, true)` |
| `SmartClipboardIME.kt` | `onCreateInputView()`: thêm `LayoutParams` tường minh cho root/strip/keyboardView |
| `SmartClipboardIME.kt` | `onKeyPressed()`: thêm case `-6 -> {}` tách khỏi nhánh `else` |

**Không đụng vào:** `handleDelimiter`, `handleBackspace`, escape `;;`,
`triggerMap`, `loadCache`/`reloadCacheIfChanged`, `SuggestionStrip`,
`isPasswordField`, `cache_sync_service.dart`, `AndroidManifest.xml`.

---

## ACCEPTANCE CRITERIA (agent tự kiểm tra trước khi báo hoàn thành)

- [ ] Build APK thành công, không lỗi compile.
- [ ] Bật keyboard "Smart Clipboard" trong Settings, mở Chrome/Ghi chú → bàn
      phím hiện ra chiếm khoảng nửa dưới màn hình (không full screen).
- [ ] Phím có kích thước hợp lý, không bị vỡ layout, chữ trên phím đọc được
      rõ ràng, không tràn ra ngoài viền phím.
- [ ] Gõ các chữ cái không bấm Shift → ra chữ **thường** (a, b, c...).
- [ ] Bấm Shift rồi gõ chữ cái → ra chữ **HOA** đúng 1 lần rồi cần xem lại
      hành vi toggle hiện tại (giữ nguyên behavior gốc — patch này chỉ đảm
      bảo có phân biệt HOA/thường, không thay đổi cơ chế toggle một-lần hay
      giữ liên tục).
- [ ] Bấm phím Enter (`↵`) → xuống dòng đúng trong text field (test trong 1
      app hỗ trợ multiline như Ghi chú/Keep).
- [ ] Bấm `?123` → không crash, không có hành vi kỳ lạ (im lặng chấp nhận
      được ở patch này, vì symbol layer nằm ngoài scope).
- [ ] Gõ lại `;email` + Space trên Chrome/Gmail để xác nhận **tính năng
      expansion vẫn hoạt động đúng như trước patch** (không bị ảnh hưởng bởi
      các thay đổi ở trên — đây là bước hồi quy bắt buộc, vì LỖI 3 sửa
      `getCharForKey` dùng chung cho cả gõ thường lẫn buffer trigger).
- [ ] Gõ `;;` → vẫn ra đúng 1 dấu `;` (hồi quy, không bị ảnh hưởng).

---

## GHI CHÚ TÙY CHỌN (không bắt buộc, chỉ làm nếu agent còn dư phạm vi và thấy an toàn)

Label hiển thị trên phím ở `row1`/`row2` hiện luôn vẽ HOA cố định
(`"Q","W",...`) bất kể `isShifted`, trong khi `row3` đã có logic đổi label
theo Shift. Đây **chỉ là vấn đề hiển thị** (không ảnh hưởng ký tự thực gửi
vào `InputConnection` — đã sửa đúng ở LỖI 3), nên KHÔNG bắt buộc trong patch
này. Nếu muốn đồng bộ trải nghiệm, có thể áp dụng cùng pattern của `drawRow3`
cho `drawRow`/`drawRowCentered`, nhưng **chỉ làm sau khi 4 lỗi chính đã pass
Acceptance Criteria**, không gộp chung để dễ review diff.