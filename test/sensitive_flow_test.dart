import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'package:smart_clipboard/core/database/migrations.dart';
import 'package:smart_clipboard/repositories/clipboard_repository.dart';
import 'package:smart_clipboard/services/clipboard_service.dart';
import 'package:smart_clipboard/services/metrics_service.dart';
import 'package:smart_clipboard/services/privacy_service.dart';
import 'package:smart_clipboard/core/database/app_database.dart';

void main() {
  group('Sensitive Flow — Data Integrity', () {
    late Database db;
    late ClipboardService service;
    late ClipboardRepository repo;
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
      repo = ClipboardRepository(db);
      meta = MetaDao(db);
      service = ClipboardService(
        repo: repo,
        meta: meta,
        metrics: MetricsService(db),
        privacy: PrivacyService(),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('saveContent lưu chính xác nội dung được truyền vào', () async {
      // Giả lập: Clipboard OS có nội dung A
      const originalText = 'Sensitive data: 1234-5678-9012-3456';

      // Lưu trực tiếp nội dung (không đọc clipboard)
      await service.saveContent(originalText);

      // Kiểm tra DB lưu đúng nội dung
      final rows = await db.query('clipboard_items');
      expect(rows.length, 1);
      expect(rows.first['content'], originalText);
    });

    test('confirmSaveBlockedContent lưu đúng blockedText', () async {
      // Giả lập: User share text bị block
      const blockedText = 'Password: mysecret123';

      // Confirm save với forceSave = true
      final result = await service.confirmSaveBlockedContent(blockedText);

      // Kiểm tra lưu thành công
      expect(result, CaptureResult.saved);

      // Kiểm tra DB lưu đúng nội dung
      final rows = await db.query('clipboard_items');
      expect(rows.length, 1);
      expect(rows.first['content'], blockedText);
    });

    test('saveContent với forceSave bỏ qua pause mode', () async {
      // Bật pause mode
      await meta.setBool('capture_paused', true);

      // Lưu với forceSave = true
      await service.saveContent('Force saved text', forceSave: true);

      // Kiểm tra vẫn lưu được
      final rows = await db.query('clipboard_items');
      expect(rows.length, 1);
      expect(rows.first['content'], 'Force saved text');
    });

    test('saveContent尊重 pause mode khi không force', () async {
      // Bật pause mode
      await meta.setBool('capture_paused', true);

      // Lưu không force
      await service.saveContent('Should not save');

      // Kiểm tra không lưu
      final rows = await db.query('clipboard_items');
      expect(rows.length, 0);
    });

    test('saveContent với expiresAtOverride', () async {
      final customExpiry = DateTime.now().millisecondsSinceEpoch + 86400000;

      await service.saveContent(
        'Expiring text',
        forceExpiresAt: customExpiry,
      );

      final rows = await db.query('clipboard_items');
      expect(rows.length, 1);
      expect(rows.first['expires_at'], customExpiry);
    });

    test('Nội dung khác nhau khi saveContent gọi nhiều lần', () async {
      // Giả lập race condition: clipboard thay đổi giữa các lần gọi
      await service.saveContent('First content');
      await service.saveContent('Second content');

      final rows = await db.query('clipboard_items');
      expect(rows.length, 2);

      final contents = rows.map((r) => r['content'] as String).toList();
      expect(contents, containsAll(['First content', 'Second content']));
    });
  });
}
