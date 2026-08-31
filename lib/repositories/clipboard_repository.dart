import 'dart:math';

import 'package:sqflite/sqflite.dart';

import '../core/utils/content_normalizer.dart';
import '../models/clipboard_item.dart';
import '../services/privacy_service.dart';

class ClipboardSaveResult {
  final ClipboardItem item;

  /// true nếu trùng hash → chỉ UPDATE last_used_at + copy_count+1 (mục 2.1).
  final bool wasDeduplicated;

  const ClipboardSaveResult({
    required this.item,
    required this.wasDeduplicated,
  });
}

/// Repository bảng `clipboard_items`.
///
/// Deduplication — Master Spec mục 2.1:
/// IF content_hash đã tồn tại → UPDATE last_used_at = now, copy_count+1
/// ELSE → INSERT bản ghi mới.
///
/// STRICT RULE 17 [SOFT DELETE]: khi vượt Free limit, item cũ nhất bị đánh
/// dấu `is_archived=1` (ẩn khỏi UI) — KHÔNG xoá vật lý. Restore khi mua Pro.
class ClipboardRepository {
  final Database db;
  final PrivacyService privacy;
  ClipboardRepository(this.db, {PrivacyService? privacy})
      : privacy = privacy ?? PrivacyService();

  String _newId() => _randomId();

  /// Lưu nội dung clipboard với dedup + heuristic + auto-expiration.
  /// Trả về kết quả để service/UI quyết định banner & metrics.
  Future<ClipboardSaveResult> save(
    String rawContent, {
    String? sourceApp,
    required int expirationDays,
    int? expiresAtOverride,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final hash = contentHash(rawContent);

    // --- Dedup theo content_hash ---
    final existing = await db.query('clipboard_items',
        where: 'content_hash = ?', whereArgs: [hash], limit: 1);
    if (existing.isNotEmpty) {
      final id = existing.first['id'] as String;
      await db.update(
        'clipboard_items',
        {'last_used_at': now, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [id],
      );
      final item = ClipboardItem.fromMap((await db.query('clipboard_items',
              where: 'id = ?', whereArgs: [id], limit: 1))
          .first);
      return ClipboardSaveResult(item: item, wasDeduplicated: true);
    }

    // --- Insert mới ---
    final assessment = privacy.assess(rawContent);
    final expiresAt = expiresAtOverride ??
        PrivacyService.expiryForDays(now, expirationDays);
    final item = ClipboardItem(
      id: _newId(),
      content: rawContent,
      contentHash: hash,
      contentType: assessment.contentType,
      createdAt: now,
      updatedAt: now,
      sourceApp: sourceApp,
      expiresAt: expiresAt,
      privacyRiskScore: assessment.riskScore,
    );
    await db.insert('clipboard_items', item.toMap());

    return ClipboardSaveResult(
      item: item,
      wasDeduplicated: false,
    );
  }

  /// Danh sách active hiển thị trên UI: pinned trước, rồi mới nhất.
  Future<List<ClipboardItem>> getActive({bool includeArchived = false}) async {
    final rows = await db.query(
      'clipboard_items',
      where: includeArchived ? null : 'is_archived = 0',
      orderBy: 'is_pinned DESC, created_at DESC',
    );
    return rows.map(ClipboardItem.fromMap).toList();
  }

  Future<int> archivedCount() async {
    final rows = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM clipboard_items WHERE is_archived = 1');
    return rows.first['c'] as int? ?? 0;
  }

  /// User tái sử dụng item → update last_used/copy_count + metric.
  Future<void> markUsed(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.rawUpdate(
      'UPDATE clipboard_items SET last_used_at = ?, updated_at = ?, '
      'copy_count = copy_count + 1 WHERE id = ?',
      [now, now, id],
    );
  }

  Future<void> setPinned(String id, bool pinned) =>
      _updateFlag(id, 'is_pinned', pinned);
  Future<void> setFavorite(String id, bool favorite) =>
      _updateFlag(id, 'is_favorite', favorite);

  Future<void> _updateFlag(String id, String column, bool value) =>
      db.update('clipboard_items', {column: value ? 1 : 0, 'updated_at':
          DateTime.now().millisecondsSinceEpoch},
          where: 'id = ?', whereArgs: [id]);

  /// Soft-delete (ẩn khỏi UI). Dữ liệu vẫn còn trong DB.
  Future<void> archive(String id) => _updateFlag(id, 'is_archived', true);

  /// Đặt/gỡ thời điểm hết hạn (vd banner "Tự động xoá sau 24h?" mục 5.1).
  Future<void> setExpiry(String id, int? expiresAtMs) => db.update(
        'clipboard_items',
        {
          'expires_at': expiresAtMs,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [id],
      );

  /// Xoá vật lý CHỈ khi user chủ động chọn (không bao giờ chạy tự động).
  Future<void> deleteForever(String id) =>
      db.delete('clipboard_items', where: 'id = ?', whereArgs: [id]);

  /// Auto-Expiration Engine (P0): xoá vật lý các item ĐÃ HẾT HẠN của lịch sử
  /// clipboard. Đây là hành vi đúng spec mục 8 ("Tự xoá lịch sử sau 1/7/30
  /// ngày") — khác với soft-delete khi vượt Free limit. Item pinned được miễn.
  Future<int> purgeExpired() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    return db.delete('clipboard_items',
        where: 'expires_at IS NOT NULL AND expires_at < ? '
            'AND is_pinned = 0 AND is_archived = 0',
        whereArgs: [now]);
  }

  /// Restore toàn bộ item đã archive (khi mua Pro).
  Future<void> restoreAllArchived() => db.update(
      'clipboard_items', {'is_archived': 0},
      where: 'is_archived = 1');

  String _randomId() {
    const chars =
        'abcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random.secure();
    return String.fromCharCodes(
      List.generate(24, (_) => chars.codeUnitAt(rand.nextInt(chars.length))),
    );
  }
}
