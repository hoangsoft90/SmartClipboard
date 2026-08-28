# PROMPT CHỈ THỊ KỸ THUẬT - THỰC HIỆN BATCH 2

Chào Agent, chúng ta chuyển sang BATCH 2. Hãy thực hiện các yêu cầu sửa lỗi bảo mật, hiệu năng và privacy dưới đây.

 nghiêm túc tuân thủ các quy tắc sau:
1. Bạn CHỈ ĐƯỢC THỰC HIỆN duy nhất BATCH 2. Tuyệt đối KHÔNG đụng vào các Batch khác.
2. CHỈ SỬA ĐÚNG các file được chỉ định trong Batch 2.
3. Sau khi viết code xong, tự chạy các Unit Test liên quan để kiểm tra.

--------------------------------------------------
## THÔNG TIN BATCH 2: SECURITY, PRIVACY & PERFORMANCE

### 2.1. App Lock Lifecycle (Re-lock khi Background)
* **File:** `lib/widgets/lock_gate.dart` (hoặc controller quản lý Auth State)
* **Vấn đề:** Mở khóa Biometric 1 lần thì app mở luôn, chuyển sang app khác rồi quay lại không tự khóa lại.
* **Yêu cầu:**
  - Thêm `WidgetsBindingObserver` để lắng nghe `AppLifecycleState`.
  - Khi app chuyển sang `paused` hoặc `detached`, tự động reset trạng thái unlocked (`_unlocked = false`).
  - Khi app `resumed` quay lại, bắt buộc hiển thị lại màn hình Authenticate Biometric.

### 2.2. Offload PBKDF2 Crypto ra Isolate Riêng
* **File:** `lib/services/backup_service.dart`
* **Vấn đề:** Hàm `_deriveKey()` chạy PBKDF2 150.000 vòng HMAC-SHA256 trên Main Isolate gây giật/treo UI (ANR).
* **Yêu cầu:**
  - Sử dụng `compute()` hoặc `Isolate.run()` để đẩy thao tác `_deriveKey()` tính toán PBKDF2 sang background isolate.
  - Đảm bảo UI hiển thị Loading Indicator trong lúc đang Export/Restore backup.

### 2.3. Fix Bug NFC Approximate trong Content Normalizer
* **File:** `lib/core/utils/content_normalizer.dart`
* **Vấn đề:** Khi match ký tự kết hợp (NFD), code dùng `sb.write(composed)` làm append thêm ký tự thay vì thay thế ký tự base trước đó $\rightarrow$ Làm sai Hash Dedup với text NFD (macOS / Tiếng Việt).
* **Yêu cầu:**
  - Sửa logic ghép dấu: Khi phát hiện `composed`, phải xóa ký tự base vừa ghi ở bước trước đó khỏi buffer rồi mới ghi `composed` vào.

### 2.4. Hardening Network Config trong Manifest
* **File:** `android/app/src/main/AndroidManifest.xml`
* **Vấn đề:** Khai báo quyền `INTERNET` và `cleartextTrafficPermitted="true"` không cần thiết, làm giảm tính uy tín "100% Privacy Local-First".
* **Yêu cầu:**
  - Xóa bỏ `<uses-permission android:name="android.permission.INTERNET" />` và `ACCESS_NETWORK_STATE` (nếu không dùng IAP/Network).
  - Xóa bỏ `android:usesCleartextTraffic="true"`.