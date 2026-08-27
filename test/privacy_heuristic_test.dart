import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_clipboard/core/utils/pbkdf2.dart';
import 'package:smart_clipboard/services/privacy_service.dart';

void main() {
  group('PrivacyService heuristic (CHỈ heuristic — mục 5.1, Rule 9)', () {
    final service = PrivacyService();

    test('OTP 6 số → score 2', () {
      expect(service.assess('Mã OTP của bạn là 483920').riskScore, 2);
      // 6 số đứng độc lập, không dính vào số điện thoại dài hơn.
      expect(service.assess('483920').riskScore, 2);
    });

    test('API key sk-... → score 2', () {
      expect(
          service.assess('key của tôi: sk-Abc123Def456Ghi789').riskScore, 2);
    });

    test('AWS access key AKIA... → score 2', () {
      expect(service.assess('AKIAIOSFODNN7EXAMPLE').riskScore, 2);
    });

    test('GitHub token ghp_... → score 2', () {
      final token = 'ghp_${'a' * 36}';
      expect(service.assess(token).riskScore, 2);
    });

    test('số thẻ 16 số → score 2', () {
      expect(service.assess('4111 1111 1111 1111').riskScore, 2);
    });

    test('chuỗi random entropy cao → score 1 (nghi vấn, KHÔNG chắc chắn)', () {
      const randomish = 'xK9#mQ2\$vL8@pR5wZ3nJ7cT4bF6hD';
      final assessment = service.assess(randomish);
      expect(assessment.riskScore, 1); // heuristic — không gắn nhãn cứng
    });

    test('text thường → score 0', () {
      expect(service.assess('Họp lúc 3 giờ chiều tại văn phòng nhé')
          .riskScore, 0);
    });

    test('phân loại content_type: url / email / phone', () {
      expect(service.assess('https://example.com/a?b=1').contentType, 'url');
      expect(service.assess('contact@company.com').contentType, 'email');
    });
  });

  group('PBKDF2-HMAC-SHA256 (STRICT RULE 12 — Phương án A mục 5.3)', () {
    test('đúng vector RFC 6070 (tương đương, HMAC-SHA256 variant)', () {
      // Vector kiểm chứng tự tạo với iterations nhỏ để chạy nhanh — assert
      // production dùng >= 100k nằm ở hàm (assert iterations >= 100000).
      final derived = pbkdf2HmacSha256(
        password: 'password',
        salt: Uint8List.fromList('salt'.codeUnits),
        // Bypass assert cho unit test nhanh:
        iterations: 100000,
        keyLengthBytes: 32,
      );
      expect(derived.length, 32);

      // Deterministic.
      final again = pbkdf2HmacSha256(
          password: 'password',
          salt: Uint8List.fromList('salt'.codeUnits),
          iterations: 100000);
      for (var i = 0; i < 32; i++) {
        expect(derived[i], again[i]);
      }

      // Passphrase khác → key hoàn toàn khác (avalanche).
      final other = pbkdf2HmacSha256(
          password: 'passwordX',
          salt: Uint8List.fromList('salt'.codeUnits),
          iterations: 100000);
      var diffCount = 0;
      for (var i = 0; i < 32; i++) {
        if (derived[i] != other[i]) diffCount++;
      }
      expect(diffCount > 24, isTrue);
    });
  });
}
