import 'package:sqflite/sqflite.dart';

/// Migration runner — Master Spec mục 2.2.
///
/// STRICT RULE: migration chạy THEO TRANSACTION. Nếu migration fail → app
/// KHÔNG được phép hoạt động với cache cũ/không hợp lệ. Sau khi migration
/// THÀNH CÔNG, caller bắt buộc gọi `CacheSyncService.regenerateSnippetCache()`
/// ngay lập tức trước khi coi app "sẵn sàng" (STRICT RULE 13).
class DbMigrations {
  DbMigrations._();

  static const int targetVersion = 2;

  /// v1 — schema gốc, sao chép nguyên văn từ Master Spec mục 2.
  static const List<String> v1Statements = [
    '''
    CREATE TABLE clipboard_items (
        id TEXT PRIMARY KEY,
        content TEXT NOT NULL,
        content_hash TEXT NOT NULL,
        content_type TEXT DEFAULT 'text',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        last_used_at INTEGER,
        copy_count INTEGER DEFAULT 1,
        is_pinned INTEGER DEFAULT 0,
        is_favorite INTEGER DEFAULT 0,
        privacy_risk_score INTEGER DEFAULT 0,
        is_archived INTEGER DEFAULT 0,
        source_app TEXT,
        expires_at INTEGER
    )
    ''',
    'CREATE UNIQUE INDEX idx_clipboard_hash ON clipboard_items(content_hash)',
    'CREATE INDEX idx_clipboard_created ON clipboard_items(created_at)',
    'CREATE INDEX idx_clipboard_pinned ON clipboard_items(is_pinned)',
    'CREATE INDEX idx_clipboard_archived ON clipboard_items(is_archived)',
    '''
    CREATE TABLE snippets (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        trigger TEXT UNIQUE NOT NULL,
        content TEXT NOT NULL,
        prefix TEXT DEFAULT ';',
        folder_id TEXT,
        is_enabled INTEGER DEFAULT 1,
        is_archived INTEGER DEFAULT 0,
        usage_count INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (folder_id) REFERENCES folders(id) ON DELETE SET NULL
    )
    ''',
    'CREATE INDEX idx_snippet_trigger ON snippets(trigger)',
    'CREATE INDEX idx_snippet_archived ON snippets(is_archived)',
    '''
    CREATE TABLE folders (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        icon TEXT,
        created_at INTEGER NOT NULL
    )
    ''',
    '''
    CREATE TABLE app_meta (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
    )
    ''',
  ];

  /// Chạy migration trong transaction. [from] là version hiện tại của DB.
  static Future<void> runInTransaction(
    Database db, {
    required int from,
    required int to,
  }) async {
    await db.transaction((txn) async {
      if (from < 1 && to >= 1) {
        for (final statement in v1Statements) {
          await txn.execute(statement);
        }
      }
      // v2 — Remove Free Limits: restore all archived items
      if (from < 2 && to >= 2) {
        // Unarchive all clipboard items that were archived due to Free limits
        await txn.rawUpdate(
            'UPDATE clipboard_items SET is_archived = 0 WHERE is_archived = 1');
        // Unarchive all snippets that were archived due to Free limits
        await txn.rawUpdate(
            'UPDATE snippets SET is_archived = 0 WHERE is_archived = 1');
        // Mark migration complete
        await txn.insert('app_meta', {
          'key': 'limits_model_version',
          'value': '2',
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }
}
