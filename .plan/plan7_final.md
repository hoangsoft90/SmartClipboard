# plan7_final.md — Tổng hợp cuối cùng (đã đối chiếu source thực tế qua aki mcp)

Đã đọc trực tiếp local source (không suy đoán từ plan7.md/review*.md):
- `android/app/src/main/kotlin/.../SmartKeyboardView.kt`
- `android/app/src/main/kotlin/.../SmartClipboardIME.kt`
- `android/app/src/main/kotlin/.../VietnameseTelexProcessor.kt`
- `pubspec.yaml`, `lib/services/cache_sync_service.dart`, `lib/screens/snippets/snippet_edit_screen.dart`

File này: (1) xác nhận cái nào 4 review + plan7 nói đúng bằng code thật, (2) chỉ ra **1 bug mới, nghiêm trọng hơn**, chưa review nào phát hiện, (3) chốt kiến trúc nền màu keyboard theo đúng ràng buộc thực tế repo, (4) đưa ra chỉ thị kỹ thuật cụ thể để giao cho agent.

---

## 1. Bảng trạng thái đã verify bằng source

| Mục | plan7 tuyên bố | Thực tế trong code | Đánh giá |
|---|---|---|---|
| Backspace hold-to-delete | DOWN xoá ngay, 400ms → repeat 70ms, UP không dispatch lại | ✅ Đúng y hệt — `isBackspaceRepeating`, `backspaceRepeatRunnable`, có xử lý `ACTION_CANCEL` | Đúng nhưng **thiếu `ACTION_MOVE` và `onDetachedFromWindow`** — confirm 100% review1/3/4 |
| Tooltip vị trí | `showAsDropDown` thay `showAtLocation` | ✅ Đúng, công thức `yOffset = keyRect.top - keyboardView.height - popupHeight - 8` **tính đúng về mặt toán học** để đẩy popup lên trên phím | Đúng hướng dọc. **Không có clamp theo trục X** — `xOffset = keyRect.centerX() - popupWidth/2` có thể âm (phím Q) hoặc vượt width màn hình (phím P) → popup bị cắt ở mép, đúng như mọi review lo ngại |
| Telex dd→đ | Bỏ `reset()` mỗi ký tự | ✅ Đúng — trong `VietnameseTelexProcessor.onChar`, không có reset mỗi lần gọi | Đúng, nhưng xem mục 2 — root cause "word boundary" nghiêm trọng hơn 4 review nghĩ |
| Hide keyboard sau Save | `unfocus()` + `TextInput.hide` trước `pop()` | ✅ Đúng y hệt, đã có trong `snippet_edit_screen.dart` dòng ~106 | Đúng, đủ cho MVP. Chưa có try-catch quanh `invokeMethod` (rủi ro thấp) |
| Đổi nền keyboard | Chưa code | ❌ Xác nhận: không có UI, không có field màu nào trong `SmartKeyboardView`/`SmartClipboardIME` | Đúng như review3/4 |

---

## 2. PHÁT HIỆN MỚI: Telex mất chữ khi gõ dấu câu, không chỉ "dính từ"

Cả 4 review đều nói đúng hướng nhưng **sai mức độ nghiêm trọng**: mô tả thiếu reset ở word boundary sẽ khiến "processor nối từ vô hạn" / "dính state sang từ sau". Đọc code thật thì hậu quả nặng hơn nhiều: **mất luôn ký tự tiếng Việt vừa gõ.**

Truy vết `SmartClipboardIME.onKeyPressed()`:

- Space (-2), Enter (-3), Tab (-4) → đi qua `handleDelimiter()`, có gọi `ic.finishComposingText()` + `telexProcessor.commit()`. Đường xử lý đúng.
- Dấu câu `,` và `.` ở hàng 4 **không** đi qua `handleDelimiter()`. keyCode của chúng là mã ASCII (>=0) nên rơi vào nhánh `else` "Regular character". Vì không phải chữ cái nên bị nhánh Telex bỏ qua, cuối cùng gọi thẳng `ic.commitText(finalChar, 1)` — **trong khi composing span tiếng Việt (`setComposingText` từ trước) vẫn đang active.**

Theo tài liệu Android chính thức (`InputConnection.commitText` / `BaseInputConnection.commitText`, đã tra cứu trực tiếp): *"Default implementation replaces any existing composing text with the given text."* — `commitText()` khi đang có composing text sẽ **thay thế toàn bộ** composing text bằng chuỗi mới, không phải nối thêm.

→ Gõ `d` `d` → composing hiện `đ` (chưa commit) → gõ tiếp `.` → toàn bộ `đ` đang composing bị **xoá và thay bằng `.`**. Không phải "dính sang từ sau" mà là **mất ký tự ngay lập tức**, dễ tái hiện với mọi câu tiếng Việt kết thúc bằng dấu câu không có khoảng trắng trước đó (rất phổ biến, ví dụ "chào bạn.").

**Đây là bug P0**, ưu tiên cao hơn `ACTION_MOVE`/tooltip vì gây mất nội dung người dùng đang gõ trong tình huống thường gặp.

---

## 3. Backspace long-press — xác nhận + bổ sung

Đã đúng phần DOWN/UP/CANCEL. Còn thiếu đúng như review1/3/4:

1. `ACTION_MOVE`: chưa có case này trong `onTouchEvent` — trượt ngón ra khỏi ⌫ khi đang giữ thì `backspaceRepeatRunnable` vẫn lặp cho tới khi `ACTION_UP`/`ACTION_CANCEL` bất kỳ đâu trên bàn phím.
2. `onDetachedFromWindow`: chưa override — IME bị kill/switch app giữa lúc giữ ⌫ có thể để lại callback trên `Handler(Looper.getMainLooper())` tham chiếu view đã detach (rò rỉ nhẹ, không crash nhưng nên dọn).

Điểm review2 nêu "backspace repeat cần đồng bộ Telex composing state": đã kiểm tra, `handleBackspace()` **có** nhánh riêng cho Telex composing (`telexProcessor.onBackspace()`) — không phải lỗi thật, review2 lo hơi thừa. Lỗi thật còn lại (`aa→â` rồi xoá không "giải nén" lại `a`) nằm trong `VietnameseTelexProcessor.onBackspace()` — đúng như review3 gọi là "độc lập, không chặn ship". Giữ P2.

---

## 4. Tooltip — chốt

Công thức Y đúng. Cần clamp X để không cắt ở phím rìa (Q, P):

```kotlin
val screenWidth = keyboardView.width
val xOffset = (keyRect.centerX() - popupWidth / 2)
    .coerceIn(0, maxOf(0, screenWidth - popupWidth))
```

Fix rẻ, không cần chuyển sang vẽ Canvas như review1/3 đề xuất fallback — chỉ cân nhắc Canvas nếu sau khi clamp vẫn lệch trên thiết bị thật.

---

## 5. Nền màu keyboard — sửa lỗi kiến trúc của review1/review2

`plan7_review1.md` và `plan7_review2.md` đều đề xuất `shared_preferences`. Đã kiểm tra `pubspec.yaml` thật:

```
# DEPENDENCY WHITELIST — Master Spec mục 14 (STRICT RULE 19)
# KHÔNG tự ý thêm package khác
```

`shared_preferences` **không có** trong whitelist — thêm chỉ để lưu 1 màu là vi phạm STRICT RULE 19 không cần thiết.

Repo đã có sẵn đúng pattern cần dùng — `lib/services/cache_sync_service.dart`:
- Version lưu trong bảng `app_meta` (SQLite, đã có `sqflite`).
- Ghi file JSON ra `getApplicationSupportDirectory()` — đã verify: trên Android hàm này trả về thẳng `context.filesDir`, khớp chính xác cách `SmartClipboardIME.kt` đọc bằng `File(filesDir, CACHE_FILE_NAME)`.
- Ghi atomic qua file `.tmp` rồi `rename()`.
- IME đọc lại mỗi khi `onStartInputView()` — đúng lựa chọn của bạn ("cập nhật ở lần mở bàn phím tiếp theo").

→ Không cần `shared_preferences`, không cần `MethodChannel` mới, không cần `SharedPreferences` phía Android như review2 đề xuất. Tái dùng đúng cơ chế file đã kiểm chứng thay vì nhân đôi hạ tầng.

---

## 6. Thứ tự ưu tiên (re-rank theo mức độ nghiêm trọng thật)

**P0 — vá trước tiên (bug mất dữ liệu / hành vi sai khi gõ):**
1. Route dấu câu qua `handleDelimiter()` — vá mất chữ tiếng Việt composing (mục 2).
2. `ACTION_MOVE` trong `onTouchEvent` — dừng repeat khi trượt khỏi ⌫.
3. `onDetachedFromWindow` — cleanup Handler.

**P1 — UX:**
4. Clamp `xOffset` tooltip.
5. Nền bàn phím theo kiến trúc mục 5.

**P2 — sau, không chặn release:**
6. `VietnameseTelexProcessor.onBackspace()` chưa giải nén đúng ký tự ghép.
7. Try-catch quanh `TextInput.hide`.
8. Tinh chỉnh tốc độ repeat backspace nếu test thật thấy 70ms hơi nhanh.

---

## 7. CHỈ THỊ KỸ THUẬT — giao thẳng cho agent (P0 + P1)

### 7.1. Fix P0-1: Telex mất chữ khi gõ dấu câu

File: `SmartClipboardIME.kt`, hàm `onKeyPressed()`.

Hiện tại `,` và `.` (keyCode = mã ASCII) rơi vào nhánh `else` chung với mọi ký tự thường. Cần tách một nhánh riêng cho các ký tự là dấu câu kết thúc từ, gọi qua `handleDelimiter()` giống Space/Enter/Tab thay vì `ic.commitText()` trực tiếp.

```kotlin
// Thêm ngay đầu khối `else ->` (trước dòng "val ch = keyboardView.getCharForKey(keyCode) ?: return")
val wordBoundaryChars = setOf(',', '.', '!', '?', ';', ':')
val previewCh = keyboardView.getCharForKey(keyCode)
if (previewCh != null && previewCh.length == 1 && previewCh[0] in wordBoundaryChars) {
    handleDelimiter(ic, previewCh[0])
    return
}
```

Đặt đoạn này **trước** nhánh kiểm tra `currentLanguage == InputLanguage.VI && ch[0].isLetter()` để dấu câu không lọt vào nhánh Telex, và cũng trước khối `;;` escape / auto-capitalize / double-space hiện tại (những khối đó chỉ dành cho chữ cái/space).

`handleDelimiter()` hiện tại đã: (1) nếu đang composing Telex → `finishComposingText()` + `telexProcessor.commit()`; (2) check trigger snippet khớp buffer; (3) commit chính dấu câu. Không cần sửa gì thêm trong `handleDelimiter()`.

**Lưu ý cho agent:** không đổi hành vi của `;;` escape (dấu `;` không nằm trong `wordBoundaryChars` ở trên — giữ nguyên qua nhánh cũ).

### 7.2. Fix P0-2 + P0-3: `ACTION_MOVE` + `onDetachedFromWindow`

File: `SmartKeyboardView.kt`.

```kotlin
override fun onTouchEvent(event: MotionEvent): Boolean {
    when (event.action) {
        MotionEvent.ACTION_DOWN -> { /* giữ nguyên */ }

        MotionEvent.ACTION_MOVE -> {
            // Nếu đang lặp xoá và ngón tay đã rời khỏi vùng phím Backspace,
            // dừng repeat ngay — không chờ tới ACTION_UP.
            if (isBackspaceRepeating) {
                val stillOnBackspace = pressedKey?.rect?.contains(event.x.toInt(), event.y.toInt()) == true
                if (!stillOnBackspace) {
                    isBackspaceRepeating = false
                    touchHandler.removeCallbacks(backspaceRepeatRunnable)
                    pressedKey = null
                    invalidate()
                    previewListener?.onKeyPreviewDismissed()
                }
            }
            return true
        }

        MotionEvent.ACTION_UP -> { /* giữ nguyên */ }
        MotionEvent.ACTION_CANCEL -> { /* giữ nguyên */ }
    }
    return super.onTouchEvent(event)
}

override fun onDetachedFromWindow() {
    super.onDetachedFromWindow()
    isBackspaceRepeating = false
    touchHandler.removeCallbacks(backspaceRepeatRunnable)
}
```

### 7.3. Fix P1-4: clamp tooltip theo trục X

File: `SmartClipboardIME.kt`, hàm `showKeyPreview()`.

```kotlin
val xOffset = (keyRect.centerX() - popupWidth / 2)
    .coerceIn(0, maxOf(0, keyboardView.width - popupWidth))
val yOffset = keyRect.top - keyboardView.height - popupHeight - 8
popup.showAsDropDown(keyboardView, xOffset, yOffset, Gravity.START)
```

### 7.4. Feature P1-5: nền màu keyboard (kiến trúc file-sync có sẵn, không thêm package)

**Flutter — lưu setting:**
- Thêm key `keyboard_bg_color` vào bảng `app_meta` qua DAO hiện có trong `app_database.dart` (cùng cơ chế các setting khác đang dùng — KHÔNG dùng `shared_preferences`).
- Thêm UI preset màu trong `settings_screen.dart` (trắng mặc định `#FFFFFF`, xám `#E0E0E0`, đen `#1C1C1E`, xanh nhạt `#D6E4FF`) — dùng `SimpleDialog`/`Wrap` các ô màu, không thêm package color-picker.

**Flutter — đồng bộ ra IME:**
- Sửa `CacheSyncService.regenerateSnippetCache()` (hoặc gọi thêm 1 hàm nhỏ dùng lại `_cacheFile()`) để field `keyboard_bg_color` được ghi kèm vào payload JSON hiện có:
```dart
final payload = jsonEncode({
  'cache_version': version,
  'triggers': triggers,
  'keyboard_bg_color': bgColorHex, // đọc từ app_meta, fallback '#FFFFFF'
});
```
- Gọi hàm ghi lại cache này mỗi khi user đổi màu trong Settings (không chỉ sau CRUD snippet).

**Android — `SmartClipboardIME.kt`:**
- Trong `loadCache()`, đọc thêm `obj.optString("keyboard_bg_color", "#FFFFFF")`, parse bằng `Color.parseColor(...)` trong try-catch (fallback trắng nếu hex lỗi), rồi gọi `keyboardView.setBackgroundColor(color)`.

**Android — `SmartKeyboardView.kt`:**
```kotlin
private var customBackgroundColor: Int? = null

fun setBackgroundColor(color: Int) {
    if (customBackgroundColor != color) {
        customBackgroundColor = color
        invalidate()
    }
}

private fun isColorDark(color: Int): Boolean {
    val luminance = (0.299 * Color.red(color) + 0.587 * Color.green(color) + 0.114 * Color.blue(color)) / 255
    return luminance < 0.5
}
```
- Trong `onDraw()`: nếu `customBackgroundColor != null` → vẽ nó thay cho logic `isDarkMode` hiện tại (tuỳ chỉnh của user ưu tiên hơn dark mode hệ thống — ghi rõ điều này để agent không để 2 logic nền đè lên nhau).
- Trong `drawKey()`: nếu có `customBackgroundColor`, chọn `textPaint`/`keyStrokePaint` theo `isColorDark(customBackgroundColor)` thay vì theo `isDarkMode`.

---

## KHÔNG LÀM TRONG PATCH NÀY

- Không sửa `VietnameseTelexProcessor.onBackspace()` (P2, tách task riêng).
- Không thêm MethodChannel/Broadcast realtime cho nền màu — chỉ cập nhật ở lần mở bàn phím tiếp theo, đúng như đã chốt.
- Không thêm package mới (`shared_preferences`, color-picker...) — vi phạm STRICT RULE 19.
- Không chuyển tooltip sang vẽ Canvas — chỉ làm nếu sau khi clamp X vẫn lệch trên thiết bị thật.
- Không đổi tốc độ repeat 70ms trong patch này — để P2 riêng sau khi có phản hồi test thật.
- Không route `;` qua `handleDelimiter()` — giữ nguyên cơ chế `;;` escape hiện tại.

---

## TEST MATRIX BẮT BUỘC SAU PATCH

| # | Bước | Kỳ vọng |
|---|---|---|
| 1 | Mode VI: gõ `d` `d` → composing `đ`, gõ tiếp `.` (không có space trước) | `đ` được commit đúng, `.` xuất hiện ngay sau, không mất chữ |
| 2 | Mode VI: gõ "chao ban" rồi `dd` `.` liên tiếp | Câu hoàn chỉnh với `đ`, không có ký tự nào biến mất |
| 3 | Mode VI: gõ `aa` → `â`, gõ `,` | `â` commit đúng, `,` theo sau |
| 4 | Giữ ⌫ để xoá liên tục, giữa chừng trượt ngón ra khỏi vùng ⌫ sang phím khác | Việc xoá dừng ngay khi rời vùng ⌫, không xoá "ma" thêm ký tự nào |
| 5 | Giữ ⌫, thả tay ngay trên phím ⌫ | Dừng đúng, không xoá đúp |
| 6 | Chuyển app khác (Recents) khi đang giữ ⌫ | Không crash, không log lỗi callback trên view đã detach |
| 7 | Bấm giữ phím Q và phím P, quan sát tooltip | Tooltip hiển thị trọn vẹn trong màn hình, không bị cắt ở mép trái/phải |
| 8 | Vào Settings, đổi nền keyboard sang màu đen, quay lại app khác, mở bàn phím | Nền bàn phím đổi sang đen ngay từ lần mở tiếp theo, chữ trên phím tự động đổi sang trắng để đọc được |
| 9 | Đổi nền về trắng mặc định, mở lại bàn phím | Nền trắng, chữ đen — giống trạng thái gốc |
| 10 | Với nền tuỳ chỉnh đang bật, đổi hệ thống sang Dark Mode | Nền bàn phím vẫn theo màu user chọn, không bị đè bởi `isDarkMode` hệ thống |
| 11 | Gõ `;email` + Space (hồi quy, không liên quan patch này) | Snippet expand đúng như trước |
| 12 | Tạo/sửa snippet, bấm Save | Bàn phím tắt ngay, không hiện lại (hồi quy) |
