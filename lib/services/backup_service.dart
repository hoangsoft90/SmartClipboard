import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../core/utils/pbkdf2.dart';

/// Encrypted Backup / Restore — Master Spec mục 5.3 + STRICT RULE 12.
///
/// Phương án A (đã chốt, KHÔNG thay đổi):
/// - AES-256-GCM, nonce ngẫu nhiên MỖI lần export, không tái sử dụng.
/// - Key derive từ passphrase USER TỰ NHẬP lúc export, qua PBKDF2-HMAC-SHA256
///   (>= 100.000 iterations). KHÔNG hardcode key, KHÔNG derive từ device ID.
/// - Salt ngẫu nhiên lưu CÙNG file backup (không phải bí mật).
/// - User phải nhớ passphrase để restore — trade-off UX chấp nhận được, nhất
///   quán với positioning "privacy-first".
class BackupService {
  static const int kdfIterations = 150000; // >= 100k (STRICT RULE 12)
  static const int saltBytes = 16;
  static const int gcmNonceBytes = 12;
  static const String formatId = 'smart_clipboard_backup';
  static const int formatVersion = 1;
  final Database _db;

  BackupService(this._db);

  /// Export toàn bộ data (folders, snippets — kể cả archived, clipboard_items)
  /// ra file mã hoá trong thư mục Documents. Trả về đường dẫn file để UI hiển thị.
  /// Web: Backup/Restore không khả dụng (dart:io + path_provider).
  Future<String> exportTo(String passphrase) async {
    if (kIsWeb) throw const BackupException('Backup không khả dụng trên web.');
    final payload = jsonEncode({
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'folders': await _db.query('folders'),
      'snippets': await _db.query('snippets'),
      'clipboard_items': await _db.query('clipboard_items'),
    });

    final salt = _randomBytes(saltBytes);
    final key = _deriveKey(passphrase, salt);
    // GCM nonce ngẫu nhiên mỗi lần export — không tái sử dụng (Rule 12).
    final iv = enc.IV.fromSecureRandom(gcmNonceBytes);
    final encrypter =
        enc.Encrypter(enc.AES(enc.Key(key), mode: enc.AESMode.gcm));
    final encrypted = encrypter.encrypt(payload, iv: iv);

    final envelope = jsonEncode({
      'format': formatId,
      'version': formatVersion,
      'kdf': {
        'algo': 'PBKDF2-HMAC-SHA256',
        'iterations': kdfIterations,
        'salt': base64Encode(salt),
      },
      'nonce': base64Encode(iv.bytes),
      'ciphertext': base64Encode(encrypted.bytes),
    });

    final dir = await getApplicationDocumentsDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/smart_clipboard_backup_$ts.scbak');
    await file.writeAsString(envelope, flush: true);
    return file.path;
  }

  /// Restore: derive key từ passphrase + salt trong file → giải mã → xoá sạch
  /// bảng data rồi ghi lại. Caller PHẢI gọi regenerateSnippetCache() sau khi
  /// restore thành công (STRICT RULE 13) — làm ở tầng trên cùng transaction
  /// logic của app.
  Future<void> restoreFrom(String path, String passphrase) async {
    if (kIsWeb) throw const BackupException('Restore không khả dụng trên web.');
    final file = File(path);
    if (!await file.exists()) {
      throw const BackupException('File backup không tồn tại.');
    }

    Map<String, dynamic> envelope;
    try {
      envelope = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      throw const BackupException('File backup không đúng định dạng.');
    }
    if (envelope['format'] != formatId) {
      throw const BackupException('Đây không phải file backup của app.');
    }

    final kdf = envelope['kdf'] as Map<String, dynamic>;
    final iterations = kdf['iterations'] as int;
    if (iterations < 100000) {
      throw const BackupException('KDF iterations không hợp lệ.');
    }
    final salt = base64Decode(kdf['salt'] as String);
    final nonce = base64Decode(envelope['nonce'] as String);
    final ciphertext = base64Decode(envelope['ciphertext'] as String);

    final key = _deriveKey(passphrase, salt);
    final encrypter =
        enc.Encrypter(enc.AES(enc.Key(key), mode: enc.AESMode.gcm));
    String payloadText;
    try {
      payloadText = encrypter.decrypt(
        enc.Encrypted(ciphertext),
        iv: enc.IV(nonce),
      );
    } catch (_) {
      // Sai passphrase hoặc file hỏng → GCM auth fail.
      throw const BackupException(
          'Sai passphrase hoặc file bị hỏng. Không thể giải mã.');
    }

    final payload = jsonDecode(payloadText) as Map<String, dynamic>;
    await _db.transaction((txn) async {
      await txn.delete('clipboard_items');
      await txn.delete('snippets');
      await txn.delete('folders');
      for (final row in (payload['folders'] as List)) {
        await txn.insert('folders', Map<String, Object?>.from(row as Map));
      }
      for (final row in (payload['snippets'] as List)) {
        await txn.insert('snippets', Map<String, Object?>.from(row as Map));
      }
      for (final row in (payload['clipboard_items'] as List)) {
        await txn.insert(
            'clipboard_items', Map<String, Object?>.from(row as Map));
      }
    });
  }

  Uint8List _deriveKey(String passphrase, Uint8List salt) =>
      pbkdf2HmacSha256(
        password: passphrase,
        salt: salt,
        iterations: kdfIterations,
        keyLengthBytes: 32,
      );

  Uint8List _randomBytes(int length) {
    final rand = Random.secure();
    return Uint8List.fromList(
        List.generate(length, (_) => rand.nextInt(256)));
  }
}

class BackupException implements Exception {
  final String message;
  const BackupException(this.message);
  @override
  String toString() => message;
}
