Tôi cần bạn xây dựng ứng dụng Flutter "Smart Clipboard & Text Expander" theo đúng bản
Master Spec đính kèm (smart_clipboard_master_spec.md). Đây là tài liệu DUY NHẤT bạn cần —
không cần tôi cung cấp thêm ngữ cảnh nào khác.

BẮT BUỘC ĐỌC TOÀN BỘ FILE TRƯỚC KHI VIẾT DÒNG CODE ĐẦU TIÊN, đặc biệt các mục:
- Mục 15: 20 Strict Rules — đây là ràng buộc cứng, vi phạm bất kỳ rule nào là lỗi nghiêm trọng.
- Mục 14: Dependency Whitelist — chỉ dùng đúng các package liệt kê, không tự ý thêm package khác.
- Mục 11: Quyết định thay cho tranh luận — đây là các quyết định đã chốt, không tự suy đoán
  hay chọn phương án khác.

PHẠM VI CÔNG VIỆC NGAY BÂY GIỜ: CHỈ PHASE 0 (mục 12).
Tuyệt đối KHÔNG được:
- Viết bất kỳ code Kotlin/Native IME nào (Phase 1) trong lượt này, kể cả "chuẩn bị sẵn".
- Thêm package ngoài whitelist mục 14.
- Tự quyết định thay đổi kiến trúc cache/process boundary (mục 1.1–1.3) — đây là quyết định
  đã chốt, không phải đề xuất.
- Bỏ qua Expander Playground (mục 6) vì nghĩ nó "không quan trọng bằng CRUD cơ bản" — đây là
  bắt buộc P0.

CÁCH LÀM VIỆC:
1. Trước tiên, đọc toàn bộ spec và liệt kê lại (dạng checklist ngắn) toàn bộ hạng mục Phase 0
   theo mục 12 + Feature Matrix mục 8 (chỉ dòng có Scope = P0), để tôi xác nhận trước khi bạn
   bắt đầu code. Đừng code ngay khi chưa có xác nhận của tôi.
2. Sau khi tôi xác nhận, khởi tạo project structure đúng theo mục 3 (lib/ folder layout).
3. Implement theo thứ tự ưu tiên sau (để có thể test tăng dần từng lớp, tránh big-bang):
   a. SQLite schema (mục 2) + migration runner + WAL mode + Riverpod setup cơ bản.
   b. Repository layer (clipboard_repository, snippet_repository) + content_hash
      normalize/dedup logic (mục 2.1).
   c. Clipboard History UI + Foreground Capture + Auto-Expiration + Incognito/Pause Mode +
      Soft-delete free-limit logic.
   d. Snippet & Folder Management UI + soft-delete free-limit.
   e. Expander Playground screen (mục 6) — bắt buộc trước khi coi Phase 0 "xong".
   f. Sensitive Data Heuristic (Regex + Entropy) → privacy_risk_score, banner cảnh báo
      (mục 5.1) — nhắc rõ trong code comment đây CHỈ LÀ heuristic.
   g. Biometric App Lock (local_auth).
   h. Onboarding flow kép (mục 7) + MethodChannel isKeyboardEnabled()/openKeyboardSettings()
      (chuẩn bị interface cho Phase 1 sau này, nhưng KHÔNG implement phần Kotlin native ở
      Phase 0 — chỉ interface Dart-side + stub trả về false).
   i. Share Sheet Integration (receive_sharing_intent).
   j. Encrypted Backup/Restore (AES-256-GCM, passphrase → PBKDF2, mục 5.3).
   k. Local-only metrics tracking (mục 10) — không chứa nội dung text.
4. Sau mỗi bước lớn (a–k), dừng lại báo cáo ngắn gọn: đã làm gì, có sai lệch nào với spec
   không (và tại sao), còn gì chưa hoàn thành. KHÔNG im lặng chạy hết toàn bộ rồi mới báo cáo
   một lần ở cuối.
5. Nếu gặp mâu thuẫn hoặc chi tiết spec chưa rõ ràng, DỪNG LẠI và hỏi tôi — không tự suy đoán
   theo hướng "có vẻ hợp lý", đặc biệt với các mục liên quan bảo mật (mục 5) và cache sync
   (mục 1.3).

KHI HOÀN THÀNH PHASE 0:
- Tự kiểm tra chéo lại với toàn bộ 20 Strict Rules (mục 15) — báo cáo rule nào đã tuân thủ,
  rule nào chưa áp dụng được (vì thuộc Phase 1, ví dụ rule 5/6/10/14/15/16) và lý do.
- KHÔNG tự động chuyển sang Phase 1 (Native IME) dù code đã sẵn sàng — Phase 1 chỉ bắt đầu
  khi tôi yêu cầu rõ ràng, sau khi xem xét metrics/quyết định của tôi.

Bắt đầu bằng bước 1: đọc spec và đưa checklist Phase 0 để tôi xác nhận.