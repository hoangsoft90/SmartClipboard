# PROMPT CHỈ THỊ KỸ THUẬT - THỰC HIỆN BATCH 3

Chào Agent, chúng ta tiếp tục với BATCH 3. Hãy tập trung nâng cấp UX và làm rõ Semantics dữ liệu.

 nghiêm túc tuân thủ các quy tắc sau:
1. Chỉ làm BATCH 3.
2. Không tự ý mở rộng scope ngoài các file được yêu cầu.

--------------------------------------------------
## THÔNG TIN BATCH 3: UX & DATA SEMANTICS

### 3.1. Thêm Entry Point cho Quản lý Folder
* **File:** `lib/screens/home_screen.dart`, `lib/screens/snippets_tab.dart` (hoặc UI liên quan)
* **Vấn đề:** Màn hình `FoldersScreen` có tồn tại nhưng user không có nút/đường dẫn để truy cập từ UI chính.
* **Yêu cầu:**
  - Thêm Icon Button hoặc Tab chuyển đổi tại màn hình Snippets để user dễ dàng mở `FoldersScreen` quản lý Thư mục.

### 3.2. Cải thiện Flow Export/Import Backup (File Picker)
* **File:** `lib/services/backup_service.dart`, `lib/screens/settings_screen.dart`
* **Vấn đề:** User phải gõ đường dẫn file `/data/user/0/...` thủ công để Restore.
* **Yêu cầu:**
  - Tích hợp package chọn file chuẩn (Storage Access Framework / Share Intent) cho phép user chọn file `.scbak` từ Dung lượng máy / Google Drive khi Restore.
  - Khi Export, kích hoạt Android Share Sheet để user lưu file ra chỗ tùy chọn.

### 3.3. Làm rõ Semantics Auto-Expiration & Free Limit
* **File:** `lib/services/clipboard_service.dart`, UI Settings/History
* **Yêu cầu:**
  - Đảm bảo cài đặt Auto-Expiration (1/7/30 ngày) chỉ áp dụng cho các clipboard item được lưu *sau* thời điểm thay đổi setting.
  - Hiển thị thông báo/banner rõ ràng khi item bị soft-archive do vượt mốc Free Limit (50 items) để user hiểu dữ liệu không bị mất vĩnh viễn.