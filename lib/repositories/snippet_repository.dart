import 'dart:math';

import 'package:sqflite/sqflite.dart';

import '../core/constants/app_limits.dart';
import '../models/folder.dart';
import '../models/snippet.dart';
import '../services/cache_sync_service.dart';

/// Repository bảng `snippets` + `folders`.
///
/// STRICT RULE 13 [CACHE REGEN]: SAU MỌI thao tác CRUD snippet/folder ảnh hưởng
/// tới trigger map, PHẢI gọi `CacheSyncService.regenerateSnippetCache()` —
/// đây là cầu nối duy nhất giữa Flutter App process và IME process (file trên
/// disk, STRICT RULE 6). Không có cơ chế in-memory nào khác trong MVP.
class SnippetRepository {
  final Database db;
  final CacheSyncService cacheSync;
  SnippetRepository(this.db, this.cacheSync);

  // ------------------------- Snippets -------------------------

  Future<List<Snippet>> getAll({bool includeArchived = false}) async {
    final rows = await db.query('snippets',
        where: includeArchived ? null : 'is_archived = 0',
        orderBy: 'updated_at DESC');
    return rows.map(Snippet.fromMap).toList();
  }

  Future<Snippet?> getByTrigger(String fullTrigger) async {
    final trigger = fullTrigger.startsWith(';')
        ? fullTrigger.substring(1)
        : fullTrigger;
    final rows = await db.query('snippets',
        where: 'trigger = ? AND is_enabled = 1 AND is_archived = 0',
        whereArgs: [trigger],
        limit: 1);
    return rows.isEmpty ? null : Snippet.fromMap(rows.first);
  }

  Future<Snippet?> getById(String id) async {
    final rows =
        await db.query('snippets', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Snippet.fromMap(rows.first);
  }

  /// Tạo snippet mới. Vượt Free limit → tự động archive snippet cũ ít dùng
  /// nhất (STRICT RULE 17 — không xoá vật lý), trả về số lượng bị archive.
  Future<int> create({
    required String title,
    required String trigger,
    required String content,
    String? folderId,
    bool isEnabled = true,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('snippets', {
      'id': _randomId(),
      'title': title,
      'trigger': _cleanTrigger(trigger),
      'content': content,
      'prefix': AppLimits.defaultTriggerPrefix,
      'folder_id': folderId,
      'is_enabled': isEnabled ? 1 : 0,
      'usage_count': 0,
      'created_at': now,
      'updated_at': now,
    });
    final archived = await _enforceSnippetFreeLimit();
    await cacheSync.regenerateSnippetCache(); // Rule 13
    return archived;
  }

  Future<void> update(Snippet snippet) async {
    await db.update(
      'snippets',
      {...snippet.toMap(), 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [snippet.id],
    );
    await cacheSync.regenerateSnippetCache(); // Rule 13
  }

  Future<void> setEnabled(String id, bool enabled) async {
    await db.update('snippets', {'is_enabled': enabled ? 1 : 0},
        where: 'id = ?', whereArgs: [id]);
    await cacheSync.regenerateSnippetCache(); // Rule 13
  }

  Future<void> incrementUsage(String id) async {
    await db.rawUpdate(
        'UPDATE snippets SET usage_count = usage_count + 1 WHERE id = ?',
        [id]);
    // usage_count không nằm trong trigger map → không cần regen cache.
  }

  /// Soft-delete: is_archived = 1, KHÔNG xoá vật lý (Rule 17).
  Future<void> archive(String id) async {
    await db.update('snippets', {'is_archived': 1}, where: 'id = ?',
        whereArgs: [id]);
    await cacheSync.regenerateSnippetCache(); // Rule 13
  }

  Future<void> restoreAllArchived() async {
    await db.update('snippets', {'is_archived': 0}, where: 'is_archived = 1');
    await cacheSync.regenerateSnippetCache(); // Rule 13
  }

  /// Xoá vật lý CHỈ khi user chủ động chọn từ UI.
  Future<void> deleteForever(String id) async {
    await db.delete('snippets', where: 'id = ?', whereArgs: [id]);
    await cacheSync.regenerateSnippetCache(); // Rule 13
  }

  Future<int> archivedCount() async {
    final rows = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM snippets WHERE is_archived = 1');
    return rows.first['c'] as int? ?? 0;
  }

  Future<int> _enforceSnippetFreeLimit() async {
    final countRows = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM snippets WHERE is_archived = 0');
    var active = countRows.first['c'] as int? ?? 0;
    var archived = 0;
    while (active > AppLimits.freeActiveSnippets) {
      final victim = await db.query(
        'snippets',
        where: 'is_archived = 0',
        orderBy: 'usage_count ASC, updated_at ASC',
        limit: 1,
      );
      if (victim.isEmpty) break;
      await db.update('snippets', {'is_archived': 1},
          where: 'id = ?', whereArgs: [victim.first['id'] as String]);
      active--;
      archived++;
    }
    return archived;
  }

  String _cleanTrigger(String raw) => raw.trim().replaceAll(RegExp(r'\s'), '');

  // ------------------------- Folders -------------------------

  Future<List<Folder>> getFolders() async {
    final rows = await db.query('folders', orderBy: 'created_at ASC');
    return rows.map(Folder.fromMap).toList();
  }

  Future<bool> canCreateFolder() async {
    final rows = await db
        .rawQuery('SELECT COUNT(*) AS c FROM folders');
    return (rows.first['c'] as int? ?? 0) < AppLimits.freeFolderLimit;
  }

  Future<void> createFolder(String name, {String? icon}) async {
    await db.insert('folders', {
      'id': _randomId(),
      'name': name,
      'icon': icon,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> renameFolder(String id, String name) =>
      db.update('folders', {'name': name}, where: 'id = ?', whereArgs: [id]);

  /// Folder xoá → snippets giữ nguyên dữ liệu, folder_id về NULL
  /// (FOREIGN KEY ON DELETE SET NULL, schema mục 2).
  Future<void> deleteFolder(String id) =>
      db.delete('folders', where: 'id = ?', whereArgs: [id]);

  // ------------------------- Utils -------------------------

  String _randomId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random.secure();
    return String.fromCharCodes(
      List.generate(24, (_) => chars.codeUnitAt(rand.nextInt(chars.length))),
    );
  }
}
