import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'package:smart_clipboard/core/database/migrations.dart';
import 'package:smart_clipboard/repositories/clipboard_repository.dart';
import 'package:smart_clipboard/services/privacy_service.dart';

void main() {
  group('ClipboardRepository — Dedup', () {
    late Database db;
    late ClipboardRepository repo;

    setUp(() async {
      db = await openDatabase(
        inMemoryDatabasePath,
        version: DbMigrations.targetVersion,
        onConfigure: (database) async {
          await database.rawQuery('PRAGMA journal_mode=WAL');
          await database.rawQuery('PRAGMA foreign_keys=ON');
        },
        onCreate: (database, version) =>
            DbMigrations.runInTransaction(database, from: 0, to: version),
      );
      repo = ClipboardRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('Lưu chuỗi mới → INSERT bản ghi mới', () async {
      final result = await repo.save('Hello World', expirationDays: 30);

      expect(result.wasDeduplicated, false);
      expect(result.item.content, 'Hello World');

      // Kiểm tra trong DB
      final rows = await db.query('clipboard_items');
      expect(rows.length, 1);
    });

    test('Lưu chuỗi trùng hash → UPDATE last_used_at + copy_count', () async {
      // Lưu lần đầu
      final result1 = await repo.save('Duplicate Test', expirationDays: 30);
      expect(result1.wasDeduplicated, false);

      // Lưu lại cùng nội dung
      final result2 = await repo.save('Duplicate Test', expirationDays: 30);
      expect(result2.wasDeduplicated, true);
      expect(result2.item.id, result1.item.id); // Cùng ID

      // copy_count phải tăng
      final rows = await db.query('clipboard_items');
      expect(rows.length, 1); // Vẫn chỉ 1 bản ghi
      expect(rows.first['copy_count'], 2);
    });

    test('Nội dung khác nhau → hash khác nhau → 2 bản ghi', () async {
      await repo.save('Content A', expirationDays: 30);
      await repo.save('Content B', expirationDays: 30);

      final rows = await db.query('clipboard_items');
      expect(rows.length, 2);
    });

    test('Content hash ổn định', () async {
      final result1 = await repo.save('Stable Hash Test', expirationDays: 30);
      final result2 = await repo.save('Stable Hash Test', expirationDays: 30);

      expect(result1.item.contentHash, result2.item.contentHash);
    });
  });

  group('ClipboardRepository — No Free Limits', () {
    late Database db;
    late ClipboardRepository repo;

    setUp(() async {
      db = await openDatabase(
        inMemoryDatabasePath,
        version: DbMigrations.targetVersion,
        onConfigure: (database) async {
          await database.rawQuery('PRAGMA journal_mode=WAL');
          await database.rawQuery('PRAGMA foreign_keys=ON');
        },
        onCreate: (database, version) =>
            DbMigrations.runInTransaction(database, from: 0, to: version),
      );
      repo = ClipboardRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('Không có giới hạn — lưu nhiều items đều hoạt động', () async {
      // Tạo 60 items — không có archive nào vì free limits đã bị xóa
      for (var i = 0; i < 60; i++) {
        await repo.save('Item $i', expirationDays: 30);
      }

      final active = await repo.getActive();
      expect(active.length, 60);
    });

    test('archivedCount trả 0 khi không có item nào bị archive', () async {
      for (var i = 0; i < 10; i++) {
        await repo.save('Item $i', expirationDays: 30);
      }

      final count = await repo.archivedCount();
      expect(count, 0);
    });
  });
}
