import 'package:flutter_test/flutter_test.dart';
import 'package:smart_clipboard/core/utils/content_normalizer.dart';

void main() {
  group('normalizeContent (mục 2.1)', () {
    test('trim + collapse whitespace', () {
      expect(normalizeContent('  hello   world \n\t foo  '),
          'hello world foo');
    });

    test('Unicode NFC xấp xỉ: é composed == e + combining acute', () {
      // 'é' single code point vs 'e' + U+0301 combining acute.
      expect(
          normalizeContent('caf\u00E9'), normalizeContent('cafe\u0301'));
    });

    test('tiếng Việt decomposed == precomposed (dedup đúng dấu tiếng Việt)', () {
      // 'ế' precomposed (U+1EBF) vs 'e' + circumflex + acute (decomposed).
      const precomposed = '\u1EBF';
      final decomposed = 'e\u0302\u0301';
      expect(normalizeContent(precomposed), normalizeContent(decomposed));

      // 'đường' giữ nguyên (đ không có canonical decomposition).
      expect(normalizeContent('đường'), 'đường');
    });

    test('chuỗi khác nhau → normalize khác nhau', () {
      expect(normalizeContent('abc') != normalizeContent('abd'), isTrue);
    });
  });

  group('contentHash', () {
    test('hash ổn định và chỉ phụ thuộc nội dung đã normalize', () {
      final h1 = contentHash('Hello   World');
      final h2 = contentHash(' hello world ');
      expect(h1, h2);
      expect(h1.length, 64); // SHA256 hex
    });
  });
}
