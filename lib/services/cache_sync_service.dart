import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Cache Sync Service — cơ chế đồng bộ CHỈ QUA FILE trên disk.
///
/// STRICT RULE 6 [PROCESS BOUNDARY]: Flutter App process và Android IME process
/// là HAI TIẾN TRÌNH HỆ ĐIỀU HÀNH HOÀN TOÀN ĐỘC LẬP, KHÔNG chia sẻ bộ nhớ.
/// Không được viết code giả định object Dart/Kotlin nào tồn tại chung giữa hai
/// bên. Đồng bộ CHỈ qua file `snippets_cache.json` + `cache_version`.
///
/// STRICT RULE 13 [CACHE REGEN]: Sau MỌI thao tác CRUD snippet và sau MỌI
/// schema migration thành công, PHẢI gọi [regenerateSnippetCache]. Nếu cache
/// file không hợp lệ, IME (Phase 1) fallback về empty state — TUYỆT ĐỐI
/// KHÔNG crash (mục 1.3).
///
/// Ghi chú technical debt CÓ CHỦ ĐÍCH: phía IME sẽ poll `cache_version` 2–3s
/// khi visible cho MVP; đây KHÔNG phải kiến trúc tối ưu cuối cùng — bản sau
/// nên nâng cấp lên FileObserver/ContentObserver (mục 1.3).
class CacheSyncService {
  final Database db;
  CacheSyncService(this.db);

  static const String cacheFileName = 'snippets_cache.json';

  /// cache_version lưu trong bảng app_meta (đơn giản hoá thay vì file meta
  /// riêng — phương án tuỳ chọn đã chốt trong schema mục 2).
  static const String cacheVersionMetaKey = 'cache_version';

  Future<File> _cacheFile() async {
    if (kIsWeb) throw UnsupportedError('Cache file không khả dụng trên web');
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, cacheFileName));
  }

  /// FIX 1.4: Đọc cache_version từ SQLite metadata.
  /// Trả về 0 nếu chưa tồn tại (lần chạy đầu tiên).
  Future<int> currentVersion() async {
    final rows = await db.query('app_meta',
        where: 'key = ?', whereArgs: [cacheVersionMetaKey], limit: 1);
    if (rows.isEmpty) return 0;
    return int.tryParse(rows.first['value'] as String? ?? '') ?? 0;
  }

  /// FIX 1.4: Tăng cache_version monotonic trong SQLite Transaction.
  /// Trả về version mới sau khi tăng.
  Future<int> _incrementVersion() async {
    final current = await currentVersion();
    final newVersion = current + 1;
    await db.insert(
      'app_meta',
      {'key': cacheVersionMetaKey, 'value': '$newVersion'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return newVersion;
  }

  /// Ghi đè toàn bộ `trigger → content` đang enabled ra file cache và bump
  /// `cache_version`. Gọi sau mọi CRUD snippet / migration thành công.
  ///
  /// Lưu ý Phase 0: file được ghi sẵn để Phase 1 (Native IME) đọc. Không có
  /// bất kỳ code Kotlin nào được viết ở Phase 0 (giới hạn phạm vi prompt).
  Future<File> regenerateSnippetCache() async {
    // Web: file cache không khả dụng — skip ghi file.
    if (kIsWeb) {
      // FIX 1.4: Dùng monotonic counter thay vì timestamp.
      await _incrementVersion();
      return File('');
    }

    // FIX 1.3: Lưu fullTrigger (bao gồm prefix) làm key trong JSON cache.
    // Ví dụ: ';email' thay vì 'email' — đảm bảo IME tra đúng key.
    final rows = await db.query(
      'snippets',
      columns: ['trigger', 'content', 'prefix'],
      where: 'is_enabled = 1 AND is_archived = 0',
    );
    final triggers = <String, String>{};
    for (final row in rows) {
      final trigger = row['trigger'] as String;
      final prefix = (row['prefix'] as String?) ?? ';';
      // Luôn lưu với prefix để IME match chính xác
      triggers['$prefix$trigger'] = row['content'] as String;
    }

    // FIX 1.4: Monotonic counter — tăng từ DB, KHÔNG dùng timestamp.
    final version = await _incrementVersion();

    final file = await _cacheFile();
    final payload = jsonEncode({
      'cache_version': version,
      'triggers': triggers,
    });
    // Ghi atomically-ish: ghi file tạm rồi rename để IME (Phase 1) ít khi đọc
    // phải file dở dang.
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(payload, flush: true);
    await tmp.rename(file.path);
    return file;
  }

  /// Dùng cho test/khôi phục hỏng: xoá file cache (IME phải fallback empty
  /// state khi file biến mất — mục 1.3, KHÔNG crash).
  Future<void> deleteCacheFile() async {
    final file = await _cacheFile();
    if (await file.exists()) await file.delete();
  }
}
