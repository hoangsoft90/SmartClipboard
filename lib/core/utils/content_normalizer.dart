import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Content hash pipeline — Master Spec mục 2.1.
///
/// BẮT BUỘC normalize trước khi hash để đảm bảo dedup đúng:
/// - trim + collapse whitespace thừa
/// - Unicode NFC: `é` (single code point) == `é` (base + combining mark)
///
/// Ghi chú kỹ thuật: Dart stdlib KHÔNG có `String.normalize()` (NFC). Package
/// chuẩn cho việc này (vd `unorm_dart`) nằm NGOÀI whitelist mục 14, nên ở đây
/// ta triển khai NFC xấp xỉ cho bảng Latin + tiếng Việt (phủ đủ các tổ hợp
/// phổ biến). Đây là technical debt có chủ đích: nếu cần full Unicode NFC,
/// phải có xác nhận rõ ràng trước khi thêm package (STRICT RULE 19).
String normalizeContent(String raw) {
  final collapsed = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  return _composeNfcApproximate(collapsed);
}

String contentHash(String raw) =>
    sha256.convert(utf8.encode(normalizeContent(raw))).toString();

// ---------------------------------------------------------------------------
// NFC xấp xỉ: canonical composition cho Latin-1, Latin Extended và tiếng Việt.
// ---------------------------------------------------------------------------

const Map<String, String> _compositionMap = {
  // Latin-1 Supplement (một phần) — base + mark → precomposed
  'a\u0300': 'à', 'a\u0301': 'á', 'a\u0302': 'â', 'a\u0303': 'ã',
  'a\u0308': 'ä', 'a\u030A': 'å', 'c\u0327': 'ç',
  'e\u0300': 'è', 'e\u0301': 'é', 'e\u0302': 'ê', 'e\u0308': 'ë',
  'i\u0300': 'ì', 'i\u0301': 'í', 'i\u0302': 'î', 'i\u0308': 'ï',
  'n\u0303': 'ñ',
  'o\u0300': 'ò', 'o\u0301': 'ó', 'o\u0302': 'ô', 'o\u0303': 'õ',
  'o\u0308': 'ö', 'u\u0300': 'ù', 'u\u0301': 'ú', 'u\u0302': 'û',
  'u\u0308': 'ü', 'y\u0301': 'ý', 'y\u0308': 'ÿ',
  'A\u0300': 'À', 'A\u0301': 'Á', 'A\u0302': 'Â', 'A\u0303': 'Ã',
  'A\u0308': 'Ä', 'A\u030A': 'Å', 'C\u0327': 'Ç',
  'E\u0300': 'È', 'E\u0301': 'É', 'E\u0302': 'Ê', 'E\u0308': 'Ë',
  'I\u0300': 'Ì', 'I\u0301': 'Í', 'I\u0302': 'Î', 'I\u0308': 'Ï',
  'N\u0303': 'Ñ',
  'O\u0300': 'Ò', 'O\u0301': 'Ó', 'O\u0302': 'Ô', 'O\u0303': 'Õ',
  'O\u0308': 'Ö', 'U\u0300': 'Ù', 'U\u0301': 'Ú', 'U\u0302': 'Û',
  'U\u0308': 'Ü', 'Y\u0301': 'Ý',
  // Latin Extended phổ biến (châu Â)
  'c\u030C': 'č', 's\u030C': 'š', 'z\u030C': 'ž',
  'C\u030C': 'Č', 'S\u030C': 'Š', 'Z\u030C': 'Ž',
  'o\u030B': 'ő', 'u\u030B': 'ű', 'O\u030B': 'Ő', 'U\u030B': 'Ű',
  'a\u0304': 'ā', 'e\u0304': 'ē', 'i\u0304': 'ī', 'o\u0304': 'ō',
  'u\u0304': 'ū', 'A\u0304': 'Ā', 'E\u0304': 'Ē', 'O\u0304': 'Ō',
  'u\u0328': 'ų', 'U\u0328': 'Ų', 'a\u0328': 'ą', 'A\u0328': 'Ą',
  'e\u0328': 'ę', 'E\u0328': 'Ę', 'i\u0328': 'į', 'I\u0328': 'Į',
  // Tiếng Việt — dấu thanh trên nguyên âm trơn (lowercase).
  // (à á â ã đã có ở khối Latin-1 phía trên — không lặp key.)
  'a\u0309': 'ả', 'a\u0323': 'ạ',
  'ă\u0300': 'ằ', 'ă\u0301': 'ắ', 'ă\u0309': 'ẳ', 'ă\u0303': 'ẵ',
  'ă\u0323': 'ặ',
  'â\u0300': 'ầ', 'â\u0301': 'ấ', 'â\u0309': 'ẩ', 'â\u0303': 'ẫ',
  'â\u0323': 'ậ',
  'e\u0309': 'ẻ', 'e\u0303': 'ẽ', 'e\u0323': 'ẹ',
  'ê\u0300': 'ề', 'ê\u0301': 'ế', 'ê\u0309': 'ể', 'ê\u0303': 'ễ',
  'ê\u0323': 'ệ',
  'i\u0309': 'ỉ', 'i\u0303': 'ĩ', 'i\u0323': 'ị',
  'o\u0309': 'ỏ', 'o\u0323': 'ọ',
  'ô\u0300': 'ồ', 'ô\u0301': 'ố', 'ô\u0309': 'ổ', 'ô\u0303': 'ỗ',
  'ô\u0323': 'ộ',
  'ơ\u0300': 'ờ', 'ơ\u0301': 'ớ', 'ơ\u0309': 'ở', 'ơ\u0303': 'ỡ',
  'ơ\u0323': 'ợ',
  'u\u0309': 'ủ', 'u\u0303': 'ũ', 'u\u0323': 'ụ',
  'ư\u0300': 'ừ', 'ư\u0301': 'ứ', 'ư\u0309': 'ử', 'ư\u0303': 'ữ',
  'ư\u0323': 'ự',
  'y\u0300': 'ỳ', 'y\u0309': 'ỷ', 'y\u0303': 'ỹ', 'y\u0323': 'ỵ',
  // Tiếng Việt — base compositions (dấu phụ tạo nguyên âm)
  'a\u0306': 'ă', 'o\u031B': 'ơ', 'u\u031B': 'ư',
  // Tiếng Việt — uppercase
  'A\u0306': 'Ă', 'A\u0309': 'Ả', 'A\u0323': 'Ạ',
  'Ă\u0300': 'Ằ', 'Ă\u0301': 'Ắ', 'Ă\u0309': 'Ẳ', 'Ă\u0303': 'Ẵ',
  'Ă\u0323': 'Ặ',
  'Â\u0300': 'Ầ', 'Â\u0301': 'Ấ', 'Â\u0309': 'Ẩ', 'Â\u0303': 'Ẫ',
  'Â\u0323': 'Ậ',
  'E\u0309': 'Ẻ', 'E\u0303': 'Ẽ', 'E\u0323': 'Ẹ',
  'Ê\u0300': 'Ề', 'Ê\u0301': 'Ế', 'Ê\u0309': 'Ể', 'Ê\u0303': 'Ễ',
  'Ê\u0323': 'Ệ',
  'I\u0309': 'Ỉ', 'I\u0303': 'Ĩ', 'I\u0323': 'Ị',
  'O\u0309': 'Ỏ', 'O\u0323': 'Ọ',
  'Ô\u0300': 'Ồ', 'Ô\u0301': 'Ố', 'Ô\u0309': 'Ổ', 'Ô\u0303': 'Ỗ',
  'Ô\u0323': 'Ộ',
  'O\u031B': 'Ơ', 'Ơ\u0300': 'Ờ', 'Ơ\u0301': 'Ớ', 'Ơ\u0309': 'Ở',
  'Ơ\u0303': 'Ỡ', 'Ơ\u0323': 'Ợ',
  'U\u0309': 'Ủ', 'U\u0303': 'Ũ', 'U\u0323': 'Ụ',
  'U\u031B': 'Ư', 'Ư\u0300': 'Ừ', 'Ư\u0301': 'Ứ', 'Ư\u0309': 'Ử',
  'Ư\u0303': 'Ữ', 'Ư\u0323': 'Ự',
  'Y\u0300': 'Ỳ', 'Y\u0309': 'Ỷ', 'Y\u0303': 'Ỹ', 'Y\u0323': 'Ỵ',
};

bool _isCombiningMark(int codeUnit) => codeUnit >= 0x0300 && codeUnit <= 0x036F;

/// Compose chuỗi decomposed (NFD) về dạng precomposed (NFC) xấp xỉ.
/// Chạy trái→phải: nếu ký tự hiện tại là combining mark và cặp
/// [ký tự trước] + [mark] có trong bảng → ghép lại.
/// FIX 2.3: Compose chuỗi decomposed (NFD) về dạng precomposed (NFC) xấp xỉ.
/// Chạy trái→phải: nếu ký tự hiện tại là combining mark và cặp
/// [ký tự trước] + [mark] có trong bảng → xóa base char rồi ghi composed.
String _composeNfcApproximate(String input) {
  if (!input.contains(RegExp(r'[\u0300-\u036F]'))) return input;
  final sb = StringBuffer();
  for (final ch in input.runes) {
    final unit = String.fromCharCode(ch);
    if (_isCombiningMark(ch) && sb.isNotEmpty) {
      // FIX 2.3: Lấy ký tự cuối buffer và kiểm tra compose
      final composed = _compositionMap['${sb.toString().last}$unit'];
      if (composed != null) {
        // FIX 2.3: Xóa base char vừa ghi rồi ghi composed vào
        // StringBuffer không có deleteCharAt → dùng String rồi write lại
        final currentStr = sb.toString();
        sb.clear();
        sb.write(currentStr.substring(0, currentStr.length - 1));
        sb.write(composed);
        continue;
      }
    }
    sb.write(unit);
  }
  return sb.toString();
}
