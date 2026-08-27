import 'dart:math' as math;

/// Shannon entropy (bits/char) — dùng CHO HEURISTIC phát hiện dữ liệu nhạy cảm
/// (Master Spec mục 5.1). ⚠️ CHỈ LÀ heuristic: entropy cao cũng có thể là
/// random ID/hash hợp lệ, không phải chỉ có sensitive data. KHÔNG được gắn
/// nhãn cứng "Đây là Password" (STRICT RULE 9).
double shannonEntropy(String s) {
  if (s.isEmpty) return 0;
  final freq = <String, int>{};
  for (final ch in s.split('')) {
    freq[ch] = (freq[ch] ?? 0) + 1;
  }
  var entropy = 0.0;
  for (final count in freq.values) {
    final p = count / s.length;
    entropy -= p * math.log(p) / math.ln2;
  }
  return entropy;
}

/// Đếm số lớp ký tự khác nhau (chữ thường / HOA / số / ký tự đặc biệt) —
/// tín hiệu phụ cho heuristic password/API-key.
int charClassCount(String s) {
  var hasLower = false, hasUpper = false, hasDigit = false, hasSymbol = false;
  for (final ch in s.runes) {
    if (ch >= 0x30 && ch <= 0x39) {
      hasDigit = true;
    } else if (ch >= 0x41 && ch <= 0x5A) {
      hasUpper = true;
    } else if (ch >= 0x61 && ch <= 0x7A) {
      hasLower = true;
    } else if (ch > 0x20 && ch < 0x7F) {
      hasSymbol = true;
    }
  }
  return [hasLower, hasUpper, hasDigit, hasSymbol].where((b) => b).length;
}
