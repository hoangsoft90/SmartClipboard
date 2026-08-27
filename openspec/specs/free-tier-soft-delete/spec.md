# Free Tier Soft-Delete Limits Specification

## Purpose

Giới hạn bản Free (50 clipboard active / 15 snippet active / 3 folder) mà KHÔNG BAO GIỜ xoá vật lý dữ liệu user khi vượt ngưỡng: item vượt bị đánh dấu `is_archived = 1` (ẩn khỏi UI), banner "Nâng cấp Pro" hiển thị số mục bị ẩn, và khi mua Pro sẽ restore toàn bộ. Tránh review 1-sao "app xoá data của tôi".

## Requirements

### Requirement: Enforce limit clipboard sau mỗi lần save

`ClipboardRepository.enforceFreeLimit()` (file: `lib/repositories/clipboard_repository.dart`) chạy ngay sau INSERT mới: trong khi số row active > 50, archive tuần tự các row CŨ NHẤT thỏa `is_pinned = 0 AND is_favorite = 0` (order `created_at ASC`). Số lượng bị archive trả về để UI hiện snackbar.

#### Scenario: Vượt limit 2 item
- **GIVEN** 51 row active, không có pin/favorite
- **WHEN** save nội dung thứ 52
- **THEN** 2 row cũ nhất chuyển `is_archived = 1`; result.archivedCount = 2; tổng active = 50.

#### Scenario: Item cũ nhất đang pinned
- **GIVEN** row cũ nhất là pinned
- **WHEN** enforce chạy
- **THEN** pinned được bỏ qua, archive row thường cũ kế tiếp.

### Requirement: Enforce limit snippet theo ít dùng nhất

`_enforceSnippetFreeLimit()` archive các snippet có `usage_count ASC, updated_at ASC` cho tới khi active ≤ 15, chạy sau mỗi create.

#### Scenario: Tạo snippet thứ 16
- **GIVEN** 15 snippet active, snippet usage_count thấp nhất là X
- **WHEN** create thành công snippet mới
- **THEN** snippet có usage_count X bị archive; snackbar báo "1 snippet cũ bị ẩn do giới hạn Free — mua Pro để mở khoá".

### Requirement: Folder bị chặn cứng thay vì archive

Vượt 3 folder → `canCreateFolder()` false → FAB hiện dialog "Giới hạn bản Free" và KHÔNG tạo folder. (Khác với clip/snippet vì folder không có khái niệm "cũ nhất nên ẩn".)

### Requirement: Banner nâng cấp + đường restore

`ProUpgradeBanner` (file: `lib/widgets/pro_upgrade_banner.dart`) hiện ở History và Snippets screen khi tổng (archived clipboard + archived snippets) > 0; bấm vào mở dialog giải thích dữ liệu VẪN GIỮ NGUYÊN và sẽ mở khoá khi mua Pro. Hai repository đều có sẵn `restoreAllArchived()`. `proStatusProvider` hiện là stub `false`.

#### Scenario: Có 7 mục bị ẩn
- **GIVEN** 5 clipboard + 2 snippet archived
- **WHEN** mở tab Snippets
- **THEN** banner primaryContainer "7 mục đang bị ẩn do giới hạn bản Free" hiển thị trên danh sách.

## Cần làm rõ

- `restoreAllArchived()` của cả hai repository hiện KHÔNG được gọi bởi bất kỳ UI/code nào (chờ wire-up IAP). Đây là API chuẩn bị có chủ đích hay dead code?
- Khi user xoá vĩnh viễn một item archived (không thể làm từ UI vì item đã ẩn)... thực tế UI không cho thao tác gì với item archived ngoài đếm. Dữ liệu archived sẽ tích luỹ vô hạn ở bản Free — có cần cap hoặc cho xem danh sách ẩn không?
