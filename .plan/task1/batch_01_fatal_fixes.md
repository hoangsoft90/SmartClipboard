# PROMPT CHỈ THỊ KỸ THUẬT - THỰC HIỆN BATCH 1

Chào Agent, hãy thực hiện sửa lỗi cho dự án SmartClipboard theo các yêu cầu của BATCH 1 dưới đây.

 nghiêm túc tuân thủ các quy tắc sau:
1. Bạn CHỈ ĐƯỢC THỰC HIỆN duy nhất BATCH 1. Tuyệt đối KHÔNG làm Batch 2, 3, 4, 5.
2. CHỈ SỬA ĐÚNG các file được liệt kê trong Batch 1. Không tự ý refactor hay thay đổi file ngoài phạm vi.
3. Sau khi hoàn thành, tóm tắt danh sách các file đã sửa và các thay đổi chính.
4. Không tự kết luận các Acceptance Criteria liên quan đến UI/Native Android là "Đã Pass" — hãy để tôi build test thực tế trên thiết bị.

Fix lỗi Crash Biometric, Lỗi logic Share Sheet / Sensitive Data, Lệch đường dẫn & Cache Key IME
--------------------------------------------------
## THÔNG TIN BATCH 1: FATAL & DATA INTEGRITY FIXES

### 1.1. Sửa Crash Biometric Lock
* **File:** `android/app/src/main/kotlin/.../MainActivity.kt`
* **Vấn đề:** Đang kế thừa `FlutterActivity` khiến `local_auth` crash/fail.
* **Yêu cầu:** 
  - Đổi class kế thừa sang `FlutterFragmentActivity`.
  - Import đúng `io.flutter.embedding.android.FlutterFragmentActivity`.

### 1.2. Refactor ClipboardService & Sửa Lỗi Share Sheet / Confirmation
* **File:** `lib/services/clipboard_service.dart`, `lib/services/share_intent_service.dart`, `lib/widgets/privacy_confirmation_dialog.dart` (hoặc nơi gọi confirmation)
* **Vấn đề:** Khi lưu từ Share Sheet hoặc confirm lưu text bị block (high-risk), app gọi lại `captureFromSystem()` $\rightarrow$ đọc lại `Clipboard.getData()` của hệ thống, gây lưu sai nội dung nếu clipboard đã đổi.
* **Yêu cầu:**
  - Tách `ClipboardService` thành 2 hàm rõ ràng:
    1. `captureSystemClipboard()`: Đọc clipboard hệ thống và gọi `saveContent()`.
    2. `saveContent(String rawText, {bool forceSave = false})`: Trực tiếp lưu chuỗi `rawText` được truyền vào, không đọc lại Clipboard OS.
  - Sửa `ShareIntentService`: Khi user chọn "Save to History", truyền trực tiếp chuỗi `sharedText` vào `saveContent()`.
  - Sửa Sensitive Confirmation Dialog: Lưu trữ chuỗi `blockedText` ban đầu và truyền trực tiếp vào `saveContent(blockedText, forceSave: true)` khi user confirm.

### 1.3. Thống nhất Cache Key & Path giữa Flutter và IME
* **File:** `lib/services/cache_sync_service.dart`, `android/app/src/main/kotlin/.../SmartClipboardIME.kt`
* **Vấn đề:** 
  - Key trong cache JSON không chứa prefix `;` (`email`), nhưng IME lại tra `triggerMap[";email"]` $\rightarrow$ Nổ Trigger thất bại.
  - Path cache file Flutter ghi (`getApplicationSupportDirectory`) khác path IME đọc (`filesDir`).
* **Yêu cầu:**
  - Thống nhất Cache Key: Lưu `fullTrigger` (ví dụ `;email`) làm key trong JSON cache, HOẶC đảm bảo cả Flutter và IME đều strip `;` đồng nhất khi tạo/tra map.
  - Thống nhất Path: Đảm bảo Flutter ghi file `snippets_cache.json` vào đúng đường dẫn `context.filesDir` của Android Native.

### 1.4. Chuyển Cache Version sang Monotonic Counter
* **File:** `lib/services/cache_sync_service.dart`, `lib/core/database/app_database.dart`
* **Vấn đề:** Dùng Timestamp `millisecondsSinceEpoch` có rủi ro trùng version nếu CRUD xảy ra trong cùng 1ms.
* **Yêu cầu:**
  - Lưu `cache_version` dạng Integer trong SQLite Metadata (`meta` table).
  - Mỗi lần `regenerateSnippetCache()`, tăng `cache_version = cache_version + 1` trong SQLite Transaction.

### 1.5. Tạm ẩn Service IME khỏi Manifest (Scope Phase 0 Clean)
* **File:** `android/app/src/main/AndroidManifest.xml`
* **Yêu cầu:** Comment out hoặc tạm gỡ đăng ký `<service android:name=".SmartClipboardIME" ... />` để bản build Phase 0 hoàn toàn không nạp Service IME chưa hoàn thiện.