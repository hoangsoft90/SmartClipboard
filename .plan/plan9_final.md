# plan9_final.md — Tổng hợp cuối cùng (đã đối chiếu source thực tế qua aki mcp)

Đã đọc trực tiếp source hiện tại (không suy đoán từ plan9.md/review*.md):
- `android/app/src/main/kotlin/.../SmartKeyboardView.kt` (toàn bộ, kể cả `onMeasure`, `onDraw`, `drawRow3`, `drawRow4`, `drawSymbolRow4`)
- `android/app/src/main/kotlin/.../SmartClipboardIME.kt` (cấu trúc root `LinearLayout`)
- `android/app/src/main/res/xml/method_metadata.xml`
- `android/app/src/main/AndroidManifest.xml`

File này: (1) xác nhận toàn bộ chẩn đoán của plan9 + 4 review bằng code thật, (2) đưa ra **1 phát hiện mới, đã tính toán bằng số cụ thể**, mà cả 5 tài liệu trước đều bỏ sót — nguyên nhân khiến Enter khuất **độc lập với** lý thuyết "IME window height bị vượt" mà tất cả đều tập trung vào, (3) chốt chỉ thị kỹ thuật.

---

## 1. Xác nhận bằng source — plan9 và 4 review đều đúng phần đã nói

| Mục | Tuyên bố (plan9 + reviews) | Thực tế source | Đánh giá |
|---|---|---|---|
| `onMeasure()` ép `desiredHeight` cố định, bỏ qua `heightMeasureSpec` | ✓ | ✅ Đúng 100% — `setMeasuredDimension(width, desiredHeight)`, không hề đọc `MeasureSpec.getMode(heightMeasureSpec)` | Xác nhận |
| Root cause là layout engine, không phải riêng phím Enter | ✓ | ✅ Đúng | Xác nhận |
| Cần `rowHeight` động + `MIN_ROW_HEIGHT` cho landscape | ✓ | Chưa có trong code — `keyHeight = 50` (dp) cố định | Xác nhận, cần làm |
| Root `LinearLayout` (Toolbar + Suggestion + Keyboard) đều `WRAP_CONTENT` height | Review3 nhắc, không kiểm tra kỹ | ✅ Đã verify: cả 4 view con trong `SmartClipboardIME.kt` đều `LinearLayout.LayoutParams.WRAP_CONTENT` cho height | Xác nhận cơ chế: vì mọi thứ WRAP_CONTENT, `SmartKeyboardView` chỉ bị giới hạn nếu **hệ thống** áp `AT_MOST` lên window IME — xem lưu ý mục 3 |
| `method_metadata.xml` có 2 subtype `en_US` + `vi_VN` | ✓ | ✅ Đúng y hệt, đã đọc file thật | Xác nhận |
| `AndroidManifest.xml` service label = "Smart Clipboard" (không phải "English Smart Clipboard") | ✓ | ✅ Đúng — `android:label="Smart Clipboard"` | Xác nhận |
| Cần uninstall/reinstall để Android refresh cache subtype | ✓ | Hành vi hệ thống, không kiểm chứng được qua code | Giữ khuyến nghị |

Không có điểm nào trong plan9 hay 4 review bị sai về những gì họ đã nói — tất cả đều đúng hướng. Vấn đề là **cả 5 tài liệu chỉ nhìn thấy một nửa bug**.

---

## 2. PHÁT HIỆN MỚI: `drawRow4()` có lỗi tính toán khiến phím Enter tràn ra ngoài View **~76dp trên mọi thiết bị**, độc lập hoàn toàn với lỗi chiều cao IME

Tất cả 5 tài liệu (plan9 + 4 review) đều quy nguyên nhân Enter bị khuất về lý thuyết: *"IME window height bị vượt do Toolbar + Suggestion + Keyboard cộng lại > chiều cao hệ thống cấp"* — tức lỗi **chiều dọc (vertical)**. Đây là một bug thật, nhưng khi tính tay công thức `drawRow4()` bằng số, có một bug **chiều ngang (horizontal)** khác, độc lập, và **chắc chắn xảy ra trên mọi màn hình/density** — không phụ thuộc chiều cao IME:

```kotlin
val specialWidth = (80 * scale).toInt()
val spaceWidth = (totalWidth - 2 * pad - 2 * margin - 2 * specialWidth - 2 * margin - 2 * margin).toInt()
val periodWidth = (50 * scale).toInt()
```

Tính tay vị trí `right` của phím Enter (ký hiệu `TW`=totalWidth, `P`=pad, `M`=margin, `SW`=specialWidth, `C`=comma width=40·scale, `PW`=period width=50·scale, đều đã nhân `scale`):

```
Enter.right = pad + 2·SW + C + spaceWidth + PW + 4·margin
            = TW − pad + C + PW − 2·margin        (thay spaceWidth vào và rút gọn)
```

Với `pad = 6·scale`, `margin = 4·scale`, `C = 40·scale`, `PW = 50·scale`:

```
Enter.right = TW − 6·scale + 40·scale + 50·scale − 8·scale
            = TW + 76·scale
```

**Kết luận: mép phải của phím Enter luôn nằm ở vị trí `totalWidth + 76dp`, tức tràn ra ngoài View đúng 76dp, trên MỌI kích thước màn hình và MỌI density** — vì `76·scale` tỉ lệ thuận với density chứ không phụ thuộc `totalWidth`. Vì `specialWidth` (bề rộng phím Enter) chỉ là `80·scale`, nghĩa là **chỉ khoảng 4dp trong tổng số 80dp bề rộng phím Enter còn nằm trong View — 76/80 diện tích phím bị vẽ ra ngoài canvas và bị cắt bởi clip bounds của View.**

**Nguyên nhân gốc:** công thức `spaceWidth` trừ đúng `2 × specialWidth` (cho `?123` và `Enter`) nhưng **quên trừ bề rộng của phím `,` (40·scale) và phím `.` (50·scale)** — hai phím này vẫn được vẽ chiếm chỗ thật trong `x`, nhưng không được tính vào ngân sách "phần còn lại dành cho Space". Hệ quả: mọi phím sau `Space` (tức là `.` và `Enter`) đều bị đẩy lệch phải thêm ~90dp so với dự kiến, chỉ được bù lại một phần nhỏ (~14dp từ chênh lệch pad/margin) → dư ra đúng 76dp tràn khỏi View.

**`drawSymbolRow4()` bị lỗi giống hệt** (copy cùng công thức) → Enter cũng tràn 76dp ở layer Symbols.

### Vì sao phát hiện này quan trọng hơn cả lỗi vertical

Ngay cả khi vá triệt để `onMeasure()`/`onDraw()` theo đúng 5 tài liệu trước (tôn trọng `heightMeasureSpec`, `rowHeight` động, `MIN_ROW_HEIGHT`...), **Enter vẫn sẽ bị khuất y hệt** vì đây là bug độc lập nằm ở trục ngang, không liên quan gì đến chiều cao IME window. Nếu chỉ merge patch theo 5 tài liệu trước mà bỏ qua phát hiện này, bạn test lại sẽ vẫn thấy Enter bị cắt và dễ nhầm tưởng patch chưa đủ mạnh ở phần vertical — trong khi thực ra cần sửa cả 2 chỗ.

Đã tính thêm `drawRow3()` (Shift + 7 letters + Backspace) theo cùng cách: công thức `letterWidth` chỉ trừ `2·margin` trong khi thực tế có 8 khoảng cách (1 sau Shift + 6 giữa các chữ + 1 trước Backspace) → Backspace cũng tràn phải **~18dp** (nhỏ hơn Enter nhưng vẫn là bug thật, cùng một lớp lỗi: đếm thiếu số lượng margin/key-width khi cộng dồn thủ công bằng tay).

→ Đây chính là lý do 5 tài liệu trước đều đúng khi khuyên "chuyển sang layout theo weights thay vì công thức cộng dồn thủ công" — nhưng giờ có bằng chứng số cụ thể *tại sao* công thức thủ công nguy hiểm: nó đã âm thầm sai ở **2 hàng khác nhau** trong cùng 1 file mà không ai phát hiện vì lỗi loại này không throw exception, chỉ lặng lẽ vẽ/tính touch rect ra ngoài bounds.

---

## 3. Một lưu ý thận trọng chưa tài liệu nào nhắc — cần verify trước khi tin chắc lý thuyết vertical

Vì root `LinearLayout` và toàn bộ view con (Toolbar, SuggestionStrip, SmartKeyboardView, EmojiTray) đều khai `WRAP_CONTENT` cho height, `SmartKeyboardView.onMeasure()` chỉ thực sự nhận được `MeasureSpec` dạng `AT_MOST` (nhỏ hơn `desiredHeight`) nếu **hệ thống** (window IME, chính sách giới hạn chiều cao bàn phím của Android — đặc biệt từ Android 11+ với gesture nav) áp constraint đó lên toàn bộ cây view. Điều này rất có khả năng đúng (đó là cách hầu hết custom IME bị clip), nhưng **chưa được xác nhận trực tiếp từ code** vì không có nơi nào trong `SmartClipboardIME.kt` tự set `Window`/`LayoutParams` giới hạn chiều cao.

**Khuyến nghị nhỏ, rẻ, nên làm trước khi code chỉ thị mục 4:** thêm 1 dòng `Log.d` tạm trong `onMeasure()` in ra `MeasureSpec.toString(heightMeasureSpec)` và `desiredHeight`, cài thử trên máy đang thấy lỗi, xem log thực tế trước khi merge patch. Nếu log cho thấy mode thực sự là `AT_MOST` với size nhỏ hơn `desiredHeight` → lý thuyết vertical của cả 5 tài liệu đúng, cứ theo chỉ thị mục 4. Nếu mode lại là `UNSPECIFIED` hoặc size ≥ `desiredHeight` → vertical không phải nguyên nhân thật (khi đó riêng bug horizontal ở mục 2 đã đủ giải thích 100% triệu chứng "Enter khuất", và không cần đổi `onMeasure` phức tạp — chỉ cần sửa mục 2 là xong). Việc này tốn 5 phút nhưng tránh sửa nhầm chỗ không phải nguyên nhân chính.

---

## 4. CHỈ THỊ KỸ THUẬT — giao thẳng cho agent

### 4.1. Fix horizontal overflow (P0 — chắc chắn có bug, không cần verify thêm)

File: `SmartKeyboardView.kt`, áp dụng cho cả `drawRow4()` và `drawSymbolRow4()` (2 hàm giống hệt nhau).

Bỏ công thức cộng dồn thủ công, chuyển sang tính `spaceWidth` đúng — trừ đủ mọi phím láng giềng thật sự chiếm chỗ:

```kotlin
private fun drawRow4(
    canvas: Canvas, y: Float, totalWidth: Float,
    pad: Int, margin: Int, height: Int, scale: Float
) {
    val specialWidth = (80 * scale).toInt()
    val commaWidth = (40 * scale).toInt()
    val periodWidth = (50 * scale).toInt()
    // FIX: trừ đủ commaWidth + periodWidth (trước đây bị quên), và đúng số
    // khoảng cách thật sự (4 margin giữa 5 phím: ?123-, / ,-Space / Space-. / .-Enter)
    val spaceWidth = (totalWidth - 2 * pad - 4 * margin
        - 2 * specialWidth - commaWidth - periodWidth).toInt()

    // ... phần vẽ giữ nguyên, chỉ đổi (40 * scale).toInt() → commaWidth,
    // (50 * scale).toInt() → periodWidth để dùng chung 1 nguồn giá trị
}
```

Áp dụng tương tự cho `drawSymbolRow4()`.

Với `drawRow3()`: sửa `letterWidth` để trừ đủ **8 margin** (1 sau Shift, 6 giữa 7 chữ cái, 1 trước Backspace) thay vì `2 * margin`:

```kotlin
val letterWidth = ((totalWidth - 2 * pad - 8 * margin - 2 * specialWidth) / 7).toInt()
```//

**Sau khi sửa cả 2, thêm 1 dòng invariant check ngay cuối `onDraw()`** (debug-only, log warning chứ không throw, để không crash production nếu vẫn còn sai số làm tròn nhỏ):

```kotlin
val lastRect = keyRects.lastOrNull()?.rect
if (lastRect != null && (lastRect.right > width || lastRect.bottom > height)) {
    android.util.Log.w("SmartKeyboardView", "Key overflow: ${lastRect} vs bounds ${width}x${height}")
}
```

Đây là điểm mà plan9 gợi ý ("geometry invariants/assertions") nhưng chưa ai viết code cụ thể — nên dùng `Log.w` thay vì `assert`/exception vì đây là custom View chạy trong IME, crash ở đây sẽ crash luôn bàn phím hệ thống của user.

### 4.2. Fix vertical clipping (P0 — theo đúng hướng cả 5 tài liệu, đã thêm ngưỡng an toàn rõ ràng)

File: `SmartKeyboardView.kt`.

**Nguyên tắc chốt** (giải quyết mâu thuẫn mà không tài liệu nào nói rõ): `heightMeasureSpec` dạng `AT_MOST` là **trần cứng, không bao giờ được vượt** — kể cả khi áp dụng `MIN_ROW_HEIGHT`. `MIN_ROW_HEIGHT` chỉ là mục tiêu UX mềm, được áp dụng khi còn dư khoảng trống (`UNSPECIFIED` hoặc size dư), **không phải lý do để phá vỡ trần `AT_MOST`** — nếu không sẽ tái tạo lại chính xác bug gốc chỉ với một con số nhỏ hơn.

```kotlin
companion object {
    private const val MIN_ROW_HEIGHT_DP = 36
}

override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
    val scale = resources.displayMetrics.density
    val width = MeasureSpec.getSize(widthMeasureSpec)
    val mm = (keyMargin * scale).toInt()
    val mp = (keyboardPadding * scale).toInt()
    val minRowHeight = (MIN_ROW_HEIGHT_DP * scale).toInt()

    val desiredRowHeight = (keyHeight * scale).toInt()
    val desiredHeight = desiredRowHeight * 4 + mm * 3 + mp * 2

    val heightMode = MeasureSpec.getMode(heightMeasureSpec)
    val heightSize = MeasureSpec.getSize(heightMeasureSpec)

    val resolvedHeight = when (heightMode) {
        MeasureSpec.EXACTLY -> heightSize
        MeasureSpec.AT_MOST -> minOf(desiredHeight, heightSize)  // trần cứng, không vượt
        else -> desiredHeight // UNSPECIFIED
    }

    setMeasuredDimension(width, resolvedHeight)
}
```

Trong `onDraw()`, tính `rowHeight` từ `height` thật (measured), không dùng `keyHeight` cố định nữa:

```kotlin
val availableHeight = height - 2 * mp - 3 * mm
val rowHeight = (availableHeight / 4).coerceAtLeast(minRowHeight.coerceAtMost(availableHeight / 4))
// Nói cách khác: dùng availableHeight/4 làm chính; chỉ "cố" đạt MIN khi có dư,
// không bao giờ ép row cao hơn những gì height thật cho phép.
```

*(Ghi chú cho agent: dòng `coerceAtLeast(minRowHeight.coerceAtMost(...))` cố ý viết theo kiểu "không thể vượt trần" — nếu thấy khó đọc, có thể đơn giản là `val rowHeight = availableHeight / 4` và chấp nhận nó nhỏ hơn `MIN_ROW_HEIGHT_DP` trong trường hợp landscape cực hẹp, KHÔNG cố "sửa" bằng cách vẽ tràn ra ngoài.)*

Dùng `rowHeight` này (thay vì `mh` cố định) cho toàn bộ 4 lần gọi `drawRow*` trong `onDraw()`.

**Không làm trong patch này** (theo đúng đồng thuận cả 5 tài liệu): không chuyển sang Fullscreen Extract UI, không đổi kiến trúc IME.

### 4.3. Xoá subtype Tiếng Việt (P0 — đơn giản, đã verify)

File: `res/xml/method_metadata.xml` — xoá toàn bộ node `<subtype>` có `android:imeSubtypeLocale="vi_VN"`, chỉ giữ `en_US`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<input-method xmlns:android="http://schemas.android.com/apk/res/android"
    android:supportsInlineSuggestions="false">
    <subtype
        android:label="English"
        android:imeSubtypeLocale="en_US"
        android:imeSubtypeMode="keyboard" />
</input-method>
```

**Không xoá** `VietnameseTelexProcessor.kt` (đã freeze, giữ lại để dùng sau — đúng như plan9 và cả 4 review đồng thuận).

Về `android:label` trong `AndroidManifest.xml`: hiện là `"Smart Clipboard"`. Nếu bạn muốn Settings hiện đúng chữ **"English Smart Clipboard"** như yêu cầu ban đầu, đổi:

```xml
<service
    android:name=".SmartClipboardIME"
    android:label="English Smart Clipboard"
    ...
```

Nếu chỉ cần "còn duy nhất 1 mục, không quan tâm tên chính xác" thì có thể giữ `"Smart Clipboard"` — việc xoá subtype `vi_VN` ở `method_metadata.xml` mới là thứ quyết định chỉ còn 1 dòng trong "Choose input method", đổi `android:label` chỉ là đổi *tên hiển thị* của dòng đó.

**Sau khi build:** phải **uninstall app cũ rồi cài lại** (không chỉ update) — Android cache danh sách subtype theo `versionCode`/metadata cũ, chỉ disable/enable IME trong Settings thường không đủ để refresh.

---

## 5. KHÔNG LÀM TRONG PATCH NÀY

- Không chuyển sang Fullscreen Extract UI hay đổi kiến trúc IME lớn.
- Không bật lại Vietnamese Telex / nút LANG.
- Không đổi logic snippet/expander, không đụng `SmartClipboardIME.kt` phần xử lý phím.
- Không dùng `assert`/throw cho invariant check trong `onDraw()` — chỉ `Log.w`, vì crash ở đây sập luôn bàn phím hệ thống.
- Không cố ép `rowHeight` đạt `MIN_ROW_HEIGHT_DP` bằng cách vượt qua giá trị `AT_MOST` mà hệ thống cấp — trần `AT_MOST` luôn thắng.

---

## 6. TEST MATRIX BẮT BUỘC SAU PATCH

| # | Bước | Kỳ vọng |
|---|---|---|
| 1 | Portrait, layer LETTERS: quan sát phím Enter | Enter hiển thị trọn vẹn, mép phải nằm hoàn toàn trong màn hình |
| 2 | Chuyển sang layer SYMBOLS (`?123`): quan sát Enter | Enter hiển thị trọn vẹn (đã fix `drawSymbolRow4`) |
| 3 | Bấm vào đúng vị trí hiển thị của Enter | Xuống dòng / gửi đúng, không cần bấm lệch ra ngoài rìa mới ăn |
| 4 | Quan sát phím Backspace ở layer LETTERS (row 3) | Nằm trọn trong View, không tràn phải (fix `drawRow3`) |
| 5 | Landscape (nếu build được emulator xoay ngang) | Các hàng phím co lại nhưng vẫn đủ 4 hàng trong view, không hàng nào bị cắt cả 2 chiều |
| 6 | Bật debug log tạm, xem `Log.w` "Key overflow" có xuất hiện không sau khi thao tác đủ mọi layer | Không xuất hiện log overflow nào |
| 7 | Settings hệ thống → "Choose input method" (sau uninstall/reinstall) | Chỉ còn đúng 1 dòng cho Smart Clipboard, không còn "Vietnamese (Vietnam) Smart Keyboard" |
| 8 | Chọn dòng English Smart Clipboard, gõ thử | Bàn phím hoạt động bình thường, English only |
| 9 | Hồi quy: giữ ⌫ để xoá liên tục, dấu câu tiếng Việt, save snippet (các fix từ plan7/plan8) | Vẫn hoạt động đúng như trước, không bị ảnh hưởng bởi patch này |
