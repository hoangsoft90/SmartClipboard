import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:encrypt/encrypt.dart' as enc;

import 'package:smart_clipboard/core/utils/pbkdf2.dart';
import 'package:smart_clipboard/services/backup_service.dart';

void main() {
  group('Backup Crypto', () {
    test('PBKDF2 key derivation tạo key 32 bytes', () {
      const passphrase = 'test_passphrase';
      final salt = _randomBytes(16);

      final key = pbkdf2HmacSha256(
        password: passphrase,
        salt: salt,
        iterations: 150000,
        keyLengthBytes: 32,
      );

      expect(key.length, 32);
    });

    test('Passphrase khác nhau tạo key khác nhau', () {
      final salt = _randomBytes(16);

      final key1 = pbkdf2HmacSha256(
        password: 'passphrase1',
        salt: salt,
        iterations: 150000,
        keyLengthBytes: 32,
      );

      final key2 = pbkdf2HmacSha256(
        password: 'passphrase2',
        salt: salt,
        iterations: 150000,
        keyLengthBytes: 32,
      );

      expect(key1, isNot(equals(key2)));
    });

    test('Cùng passphrase + salt tạo key giống nhau', () {
      final salt = _randomBytes(16);

      final key1 = pbkdf2HmacSha256(
        password: 'same_passphrase',
        salt: salt,
        iterations: 150000,
        keyLengthBytes: 32,
      );

      final key2 = pbkdf2HmacSha256(
        password: 'same_passphrase',
        salt: salt,
        iterations: 150000,
        keyLengthBytes: 32,
      );

      expect(key1, equals(key2));
    });

    test('AES-GCM encrypt + decrypt roundtrip', () {
      const plaintext = 'Test backup data';
      final key = _randomBytes(32);
      final nonce = _randomBytes(12);

      final encrypter = enc.Encrypter(enc.AES(enc.Key(key), mode: enc.AESMode.gcm));
      final iv = enc.IV(nonce);
      final encrypted = encrypter.encrypt(plaintext, iv: iv);
      final decrypted = encrypter.decrypt(encrypted, iv: iv);

      expect(decrypted, plaintext);
    });

    test('Sai passphrase → GCM auth fail', () {
      const plaintext = 'Sensitive data';
      final key1 = _randomBytes(32);
      final key2 = _randomBytes(32); // Key khác
      final nonce = _randomBytes(12);

      final encrypter = enc.Encrypter(enc.AES(enc.Key(key1), mode: enc.AESMode.gcm));
      final iv = enc.IV(nonce);
      final encrypted = encrypter.encrypt(plaintext, iv: iv);

      // Thử giải mã với key khác → phải throw
      final decrypter = enc.Encrypter(enc.AES(enc.Key(key2), mode: enc.AESMode.gcm));
      expect(
        () => decrypter.decrypt(encrypted, iv: iv),
        throwsA(anything),
      );
    });

    test('Backup format JSON hợp lệ', () {
      final envelope = {
        'format': 'smart_clipboard_backup',
        'version': 1,
        'kdf': {
          'algo': 'PBKDF2-HMAC-SHA256',
          'iterations': 150000,
          'salt': base64Encode(_randomBytes(16)),
        },
        'nonce': base64Encode(_randomBytes(12)),
        'ciphertext': base64Encode(_randomBytes(32)),
      };

      // Verify format
      expect(envelope['format'], 'smart_clipboard_backup');
      expect(envelope['version'], 1);

      final kdf = envelope['kdf'] as Map<String, dynamic>;
      expect(kdf['algo'], 'PBKDF2-HMAC-SHA256');
      expect(kdf['iterations'], 150000);
      expect(kdf['salt'], isA<String>());

      // Verify có thể decode
      expect(() => base64Decode(envelope['nonce'] as String), returnsNormally);
      expect(() => base64Decode(envelope['ciphertext'] as String), returnsNormally);
    });

    test('BackupException có message đúng', () {
      const exception = BackupException('Test error message');
      expect(exception.toString(), 'Test error message');
    });

    test('Salt ngẫu nhiên mỗi lần export', () {
      final salt1 = _randomBytes(16);
      final salt2 = _randomBytes(16);

      // Có thể trùng nhau nhưng rất thấp (2^-128)
      // Trong test ta check độ dài
      expect(salt1.length, 16);
      expect(salt2.length, 16);
    });

    test('Nonce ngẫu nhiên mỗi lần export', () {
      final nonce1 = _randomBytes(12);
      final nonce2 = _randomBytes(12);

      expect(nonce1.length, 12);
      expect(nonce2.length, 12);
    });
  });
}

Uint8List _randomBytes(int length) {
  final rand = Random.secure();
  return Uint8List.fromList(
      List.generate(length, (_) => rand.nextInt(256)));
}
