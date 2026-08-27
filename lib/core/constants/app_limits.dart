/// Giới hạn bản Free & hằng số ứng dụng — Master Spec mục 9.
///
/// Khi vượt limit: soft-delete (`is_archived = 1`) — KHÔNG BAO GIỜ xoá vật lý
/// dữ liệu user (STRICT RULE 17). Mua Pro → restore toàn bộ ngay lập tức.
class AppLimits {
  AppLimits._();

  /// Số lượng Clipboard History tối đa đang hoạt động ở bản Free.
  static const int freeClipboardLimit = 50;

  /// Số lượng Active Snippets tối đa ở bản Free.
  static const int freeActiveSnippets = 15;

  /// Số lượng Folders tối đa ở bản Free.
  static const int freeFolderLimit = 3;

  /// Các lựa chọn Auto-Expiration cho lịch sử clipboard (ngày).
  static const List<int> expirationOptionsDays = [1, 7, 30];

  /// Khi heuristic phát hiện văn bản nghi vấn nhạy cảm (score >= 1), banner
  /// gợi ý tự động xoá sau khoảng thời gian này.
  static const int sensitiveAutoDeleteHours = 24;

  /// Prefix trigger mặc định (`;email`). Pro mới được đổi — MVP khóa giá trị này.
  static const String defaultTriggerPrefix = ';';

  /// Delimiter kích hoạt expansion — STRICT RULE 14 (chốt mục 4.2).
  static const String expansionDelimiters = ' \n\t.,!?';
}
