# PROMPT CHỈ THỊ KỸ THUẬT - THỰC HIỆN BATCH 5

Chào Agent, đây là BATCH 5 — Tái cấu trúc và sửa lỗi Native Android IME để chuẩn bị cho Phase 1.

 nghiêm túc tuân thủ các quy tắc sau:
1. Chỉ làm BATCH 5.
2. Mở lại đăng ký Service IME trong `AndroidManifest.xml` sau khi đã fix xong code.

--------------------------------------------------
## THÔNG TIN BATCH 5: NATIVE IME REFACTORING (PHASE 1)

### 5.1. Correct Trigger Matching & Buffer Stripping
* **File:** `android/app/src/main/kotlin/.../SmartClipboardIME.kt`
* **Yêu cầu:** 
  - Sửa logic `handleDelimiter`: Khi user gõ `;email` + `Space`, strip ký tự prefix `;` ở đầu buffer trước khi tra map HOẶC tra đúng key `;email` theo format cache đã thống nhất ở Batch 1.
  - Sửa Suggestion Strip: Click vào suggestion phải `commitText()` nội dung snippet (`content`), KHÔNG commit chuỗi `trigger`.

### 5.2. Fix Escape `;;` Logic
* **File:** `android/app/src/main/kotlin/.../SmartClipboardIME.kt`
* **Yêu cầu:** Khi phát hiện gõ `;;` liên tiếp, gọi `ic.deleteSurroundingText(1, 0)` để xóa dấu `;` đã commit trước đó rồi mới giữ lại 1 dấu `;`.

### 5.3. Fix AndroidManifest Meta-data Typo
* **File:** `android/app/src/main/AndroidManifest.xml`
* **Yêu cầu:** Sửa meta-data IME từ `android.view_im` thành chuẩn Android **`android.view.im`**.

### 5.4. Enable IME Service & Verification
* **File:** `android/app/src/main/AndroidManifest.xml`
* **Yêu cầu:** Mở lại comment tag `<service android:name=".SmartClipboardIME" ... />` để kích hoạt bàn phím trong Settings Android.