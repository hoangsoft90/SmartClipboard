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

  Future<int> currentVersion() async {
    final rows = await db.query('app_meta',
        where: 'key = ?', whereArgs: [cacheVersionMetaKey], limit: 1);
    if (rows.isEmpty) return 0;
    return int.tryParse(rows.first['value'] as String? ?? '') ?? 0;
  }

  /// Ghi đè toàn bộ `trigger → content` đang enabled ra file cache và bump
  /// `cache_version`. Gọi sau mọi CRUD snippet / migration thành công.
  ///
  /// Lưu ý Phase 0: file được ghi sẵn để Phase 1 (Native IME) đọc. Không có
  /// bất kỳ code Kotlin nào được viết ở Phase 0 (giới hạn phạm vi prompt).
  Future<File> regenerateSnippetCache() async {
    // Web: file cache không khả dụng — skip ghi file.
    if (kIsWeb) {
      // Vẫn bump cache_version trong DB để consistency.
      final version = DateTime.now().millisecondsSinceEpoch;
      await db.insert(
        'app_meta',
        {'key': cacheVersionMetaKey, 'value': '$version'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      // Return dummy file reference — caller không dùng path trên web.
      return File('');
    }

    final rows = await db.query(
      'snippets',
      columns: ['trigger', 'content'],
      where: 'is_enabled = 1 AND is_archived = 0',
    );
    final triggers = <String, String>{
      for (final row in rows)
        row['trigger'] as String: row['content'] as String,
    };

    // cache_version = timestamp tăng dần mỗi lần regen.
    final version = DateTime.now().millisecondsSinceEpoch;
    await db.insert(
      'app_meta',
      {'key': cacheVersionMetaKey, 'value': '$version'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

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
