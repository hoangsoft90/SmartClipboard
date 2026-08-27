import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// PBKDF2-HMAC-SHA256 theo RFC 2898 — tự triển khai từ package `crypto`
/// (nằm trong whitelist mục 14) để KHÔNG phải import package ngoài danh sách.
///
/// STRICT RULE 12: Backup key PHẢI derive từ passphrase user qua PBKDF2/Argon2
/// với tối thiểu 100.000 iterations. KHÔNG hardcode key, KHÔNG derive từ device
/// ID, KHÔNG lưu key raw cạnh file backup. Salt ngẫu nhiên được lưu cùng file
/// backup (salt không phải bí mật) — Phương án A, Master Spec mục 5.3.
Uint8List pbkdf2HmacSha256({
  required String password,
  required List<int> salt,
  required int iterations,
  int keyLengthBytes = 32,
}) {
  assert(iterations >= 100000, 'PBKDF2 phải >= 100k iterations (STRICT RULE 12)');
  final hmac = Hmac(sha256, utf8.encode(password));
  final blockCount = (keyLengthBytes + 31) ~/ 32;
  final output = BytesBuilder();

  for (var blockIndex = 1; blockIndex <= blockCount; blockIndex++) {
    // U1 = HMAC(P, S || INT_MSB32(blockIndex))
    final seed = BytesBuilder()
      ..add(salt)
      ..addByte(0)
      ..addByte(0)
      ..addByte(0)
      ..addByte(blockIndex);
    var u = Uint8List.fromList(hmac.convert(seed.toBytes()).bytes);
    final t = Uint8List.fromList(u);

    // U2..Uc; T = U1 ^ U2 ^ ... ^ Uc
    for (var i = 1; i < iterations; i++) {
      u = Uint8List.fromList(hmac.convert(u).bytes);
      for (var j = 0; j < t.length; j++) {
        t[j] ^= u[j];
      }
    }
    output.add(t);
  }

  final bytes = output.toBytes();
  return Uint8List.sublistView(bytes, 0, keyLengthBytes);
}
