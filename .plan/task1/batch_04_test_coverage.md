# PROMPT CHỈ THỊ KỸ THUẬT - THỰC HIỆN BATCH 4

Chào Agent, ở BATCH 4 hãy tập trung bổ sung Unit Test suite để đảm bảo tính ổn định và chống đứt gãy (Regression).

 nghiêm túc tuân thủ các quy tắc sau:
1. Chỉ làm BATCH 4.
2. Viết các file Test sạch sẽ, có thể chạy và PASS 100% bằng lệnh `flutter test`.

--------------------------------------------------
## THÔNG TIN BATCH 4: TEST COVERAGE SUITE

Hãy bổ sung các file test độc lập trong thư mục `test/`:

### 4.1. Database & Migration Test (`test/database_test.dart`)
- Test khởi tạo SQLite schema v1, bật WAL mode, Foreign Key constraints.
- Test lưu trữ và truy vấn metadata (monotonic `cache_version`).

### 4.2. Clipboard Repository & Dedup Test (`test/clipboard_repository_test.dart`)
- Test lưu chuỗi trùng hash $\rightarrow$ Cập nhật `last_used_at` và tăng `copy_count`.
- Test vượt quá giới hạn Free (50 items) $\rightarrow$ Tự động chuyển item cũ nhất thành `is_archived = 1` (trừ Pinned/Favorite).

### 4.3. Sensitive Confirmation Data Integrity Test (`test/sensitive_flow_test.dart`)
- Test giả lập: Chặn chuỗi A $\rightarrow$ Clipboard OS đổi sang chuỗi B $\rightarrow$ Confirm save $\rightarrow$ Kiểm tra DB phải lưu chính xác chuỗi A.

### 4.4. Backup Crypto Roundtrip Test (`test/backup_crypto_test.dart`)
- Test Export dữ liệu $\rightarrow$ Restore đúng passphrase $\rightarrow$ Dữ liệu nguyên vẹn.
- Test Restore sai passphrase $\rightarrow$ Ném đúng Exception, không corrupt DB.
- Test Import file backup bị biến dạng/hỏng payload.