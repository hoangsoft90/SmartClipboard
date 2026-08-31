/// Hằng số ứng dụng — Master Spec mục 9.
class AppLimits {
  AppLimits._();

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
