# Share Sheet Integration Specification

## Purpose

Fallback chính thay Floating Widget (đã loại khỏi MVP): user chủ động Share text từ Chrome/Gmail/Messenger → chọn "Smart Clipboard" trong system sharesheet → app nhận text và cho phép lưu Clipboard hoặc tạo Snippet.

## Requirements

### Requirement: Nhận cả cold-start và warm-start

`ShareIntentService.listen()` (file: `lib/services/share_intent_service.dart`) đăng ký: (a) stream `getMediaStream()` cho lúc app đang chạy; (b) `getInitialMedia()` + `reset()` cho lúc app mở mới từ share. Chỉ xử lý item type `SharedMediaType.text`; nội dung text nằm trong trường `path`. Lỗi stream nuốt im lặng (best-effort).

#### Scenario: Share text khi app đang background
- **GIVEN** app đang chạy ngầm
- **WHEN** user share text "hello" vào app
- **THEN** callback onTextReceived("hello") chạy → bottom sheet lựa chọn hiện lên trên HomeScreen.

#### Scenario: Cold start từ share
- **GIVEN** app bị kill
- **WHEN** share text vào app khởi động lại
- **THEN** getInitialMedia trả media; reset() dọn pending intent để lần sau không nhận trùng.

### Requirement: Hai lựa chọn xử lý text nhận được

Bottom sheet (file: `lib/widgets/save_snippet_dialog.dart`, hàm `showSaveSharedTextDialog`) hiển thị số ký tự và:
1. "Lưu vào lịch sử Clipboard" → `captureFromSystem(forceSave: true)` + reload list.
2. "Tạo Snippet với trigger" → dialog tạo snippet với content prefill sẵn.

#### Scenario: Chọn lưu clipboard
- **GIVEN** text chia sẻ "abc"
- **WHEN** chọn option 1
- **THEN** row mới (hoặc dedup) trong clipboard_items bất kể pause mode (forceSave bypass — xem mục Cần làm rõ của foreground-clipboard-capture).

### Requirement: Dialog tạo snippet dùng chung

`showSaveSnippetDialog(context, ref, initialContent?)`: fields tên/trigger(prefix ';' hiển thị)/nội dung/folder dropdown (load trực tiếp từ repo, rỗng thì ẩn dropdown); validate trigger + content khác rỗng trước khi lưu; sau khi create, snackbar báo số snippet bị archive nếu vượt limit.

#### Scenario: Tạo snippet từ text share
- **GIVEN** bottom sheet đang mở với content "contact@company.com"
- **WHEN** chọn "Tạo Snippet", điền trigger "email", Lưu
- **THEN** snippet mới tạo thành công; cache regen; snackbar ";email".
