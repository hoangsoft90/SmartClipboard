import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../services/cache_sync_service.dart';
import 'migrations.dart';

/// SQLite Helper — nguồn sự thật DUY NHẤT của app (không Hive, không file data
/// song song). STRICT RULE 3: BẮT BUỘC PRAGMA journal_mode=WAL khi khởi tạo.
class AppDatabase {
  AppDatabase._();

  static Future<Database> open() async {
    final dir = await getDatabasesPath();
    return openDatabase(
      p.join(dir, 'smart_clipboard.db'),
      version: DbMigrations.targetVersion,
      onConfigure: _onConfigure,
      onCreate: (db, version) =>
          DbMigrations.runInTransaction(db, from: 0, to: version),
      onUpgrade: (db, from, to) =>
          DbMigrations.runInTransaction(db, from: from, to: to),
    );
  }

  static Future<void> _onConfigure(Database db) async {
    // STRICT RULE 3: WAL mode bắt buộc.
    await db.execute('PRAGMA journal_mode=WAL');
    // Bật FK để ON DELETE SET NULL của snippets.folder_id hoạt động đúng.
    await db.execute('PRAGMA foreign_keys=ON');
  }
}

/// DAO nhỏ đọc/ghi bảng app_meta (settings, cache_version, metrics local-only).
/// app_meta KHÔNG BAO GIỜ chứa nội dung text của user (STRICT RULE 7).
class MetaDao {
  final Database db;
  MetaDao(this.db);

  /// Key chuẩn hoá cho metrics local-only (mục 10) — không chứa nội dung text.
  static const cacheVersionKey = CacheSyncService.cacheVersionMetaKey;

  Future<String?> get(String key) async {
    final rows = await db
        .query('app_meta', where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> set(String key, String value) async {
    await db.insert(
      'app_meta',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> getInt(String key, {int fallback = 0}) async {
    final raw = await get(key);
    return raw == null ? fallback : int.tryParse(raw) ?? fallback;
  }

  Future<bool> getBool(String key, {bool fallback = false}) async =>
      (await getInt(key, fallback: fallback ? 1 : 0)) == 1;

  Future<void> setBool(String key, bool value) => set(key, value ? '1' : '0');
}
