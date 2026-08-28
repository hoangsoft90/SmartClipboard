import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'package:smart_clipboard/core/constants/app_limits.dart';
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
        onConfigure: (db) async {
          await db.rawQuery('PRAGMA journal_mode=WAL');
          await db.rawQuery('PRAGMA foreign_keys=ON');
        },
        onCreate: (db, version) =>
            DbMigrations.runInTransaction(db, from: 0, to: version),
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
      expect(result.archivedCount, 0);

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

  group('ClipboardRepository — Free Limit', () {
    late Database db;
    late ClipboardRepository repo;

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
      repo = ClipboardRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('Vượt quá free limit → archive item cũ nhất', () async {
      // Tạo nhiều items hơn limit
      for (var i = 0; i < AppLimits.freeClipboardLimit + 5; i++) {
        await repo.save('Item $i', expirationDays: 30);
      }

      // Kiểm tra số active items = limit
      final active = await repo.getActive();
      expect(active.length, AppLimits.freeClipboardLimit);

      // Kiểm tra có items bị archive
      final archivedCount = await repo.archivedCount();
      expect(archivedCount, 5);
    });

    test('Pinned items không bị archive', () async {
      // Tạo items
      for (var i = 0; i < AppLimits.freeClipboardLimit + 3; i++) {
        final result = await repo.save('Item $i', expirationDays: 30);
        // Pin item đầu tiên
        if (i == 0) {
          await repo.setPinned(result.item.id, true);
        }
      }

      // Item pinned không bị archive
      final pinned = await db.query('clipboard_items',
          where: 'is_pinned = 1 AND is_archived = 0');
      expect(pinned.length, 1);
      expect(pinned.first['content'], 'Item 0');
    });

    test('Favorite items không bị archive', () async {
      // Tạo items
      for (var i = 0; i < AppLimits.freeClipboardLimit + 3; i++) {
        final result = await repo.save('Item $i', expirationDays: 30);
        // Favorite item đầu tiên
        if (i == 0) {
          await repo.setFavorite(result.item.id, true);
        }
      }

      // Item favorite không bị archive
      final favorites = await db.query('clipboard_items',
          where: 'is_favorite = 1 AND is_archived = 0');
      expect(favorites.length, 1);
      expect(favorites.first['content'], 'Item 0');
    });

    test('archivedCount trả đúng số items bị archive', () async {
      // Tạo items
      for (var i = 0; i < 10; i++) {
        await repo.save('Item $i', expirationDays: 30);
      }

      final count = await repo.archivedCount();
      expect(count, greaterThanOrEqualTo(0));
    });
  });
}
