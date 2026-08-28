import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'package:smart_clipboard/core/database/app_database.dart';
import 'package:smart_clipboard/core/database/migrations.dart';

void main() {
  group('Database Schema v1', () {
    late Database db;

    setUp(() async {
      // Tạo database trong memory để test
      db = await openDatabase(
        inMemoryDatabasePath,
        version: DbMigrations.targetVersion,
        onConfigure: (db) async {
          await db.rawQuery('PRAGMA journal_mode=WAL');
          await db.rawQuery('PRAGMA foreign_keys=ON');
        },
        onCreate: (db, version) =>
            DbMigrations.runInTransaction(db, from: 0, to: version),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('WAL mode được bật', () async {
      final result = await db.rawQuery('PRAGMA journal_mode');
      expect(result.first['journal_mode'], 'wal');
    });

    test('Foreign Key constraints được bật', () async {
      final result = await db.rawQuery('PRAGMA foreign_keys');
      expect(result.first['foreign_keys'], 1);
    });

    test('Tất cả 4 bảng tồn tại', () async {
      final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name");

      final tableNames = tables.map((t) => t['name'] as String).toList();
      expect(tableNames, containsAll([
        'clipboard_items',
        'snippets',
        'folders',
        'app_meta',
      ]));
    });

    test('clipboard_items có đúng columns', () async {
      final columns = await db.rawQuery('PRAGMA table_info(clipboard_items)');
      final columnNames = columns.map((c) => c['name'] as String).toSet();

      expect(columnNames, containsAll([
        'id', 'content', 'content_hash', 'content_type',
        'created_at', 'updated_at', 'last_used_at', 'copy_count',
        'is_pinned', 'is_favorite', 'privacy_risk_score',
        'is_archived', 'source_app', 'expires_at',
      ]));
    });

    test('snippets có UNIQUE constraint trên trigger', () async {
      final indexes = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='index' AND tbl_name='snippets'");
      final indexNames = indexes.map((i) => i['name'] as String).toSet();
      expect(indexNames, contains('idx_snippet_trigger'));
    });

    test('clipboard_items có UNIQUE index trên content_hash', () async {
      final indexes = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='index' AND tbl_name='clipboard_items'");
      final indexNames = indexes.map((i) => i['name'] as String).toSet();
      expect(indexNames, contains('idx_clipboard_hash'));
    });

    test('Foreign Key ON DELETE SET NULL hoạt động cho snippets.folder_id', () async {
      // Tạo folder
      await db.insert('folders', {
        'id': 'folder1',
        'name': 'Test Folder',
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });

      // Tạo snippet có folder_id
      await db.insert('snippets', {
        'id': 'snippet1',
        'title': 'Test',
        'trigger': 'test',
        'content': 'content',
        'folder_id': 'folder1',
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      });

      // Xóa folder
      await db.delete('folders', where: 'id = ?', whereArgs: ['folder1']);

      // Kiểm tra snippet vẫn tồn tại nhưng folder_id = null
      final rows = await db.query('snippets', where: 'id = ?', whereArgs: ['snippet1']);
      expect(rows.length, 1);
      expect(rows.first['folder_id'], isNull);
    });
  });

  group('MetaDao — Monotonic Cache Version', () {
    late Database db;
    late MetaDao meta;

    setUp(() async {
      db = await openDatabase(
        inMemoryDatabasePath,
        version: DbMigrations.targetVersion,
        onConfigure: (db) async {
          await db.rawQuery('PRAGMA journal_mode=WAL');
          await db.rawQuery('PRAGMA foreign_keys=ON');
        },
        onCreate: (db, version) =>
            DbMigrations.runInTransaction(db, from: 0, to: version),
      );
      meta = MetaDao(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('cache_version mặc định là 0', () async {
      final version = await meta.getInt(MetaDao.cacheVersionKey);
      expect(version, 0);
    });

    test('set + get function bình thường', () async {
      await meta.set('test_key', 'test_value');
      final value = await meta.get('test_key');
      expect(value, 'test_value');
    });

    test('setBool + getBool function bình thường', () async {
      await meta.setBool('bool_key', true);
      expect(await meta.getBool('bool_key'), true);

      await meta.setBool('bool_key', false);
      expect(await meta.getBool('bool_key'), false);
    });

    test('getInt với fallback', () async {
      expect(await meta.getInt('nonexistent', fallback: 42), 42);
      await meta.set('number', '123');
      expect(await meta.getInt('number'), 123);
    });

    test('ConflictAlgorithm.replace hoạt động', () async {
      await meta.set('key', 'value1');
      await meta.set('key', 'value2');
      final value = await meta.get('key');
      expect(value, 'value2');
    });
  });
}
