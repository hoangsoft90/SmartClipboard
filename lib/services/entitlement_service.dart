import 'package:sqflite/sqflite.dart';

/// EntitlementService — single source of truth for Pro status.
///
/// Pro is unlocked by watching a Rewarded Ad. Each ad = 24h rolling Pro.
/// Stores expiry as UTC epoch millis in app_meta table (key: 'pro_expiry').
///
/// Rolling 24h chosen over calendar day to avoid:
/// - Timezone/DST edge cases
/// - Bad UX at day boundary (watching ad at 23:50 = only 10 min Pro)
class EntitlementService {
  final Database _db;
  EntitlementService(this._db);

  static const _expiryKey = 'pro_expiry';

  /// Unlock Pro for 24h from now (rolling).
  Future<void> unlockFromRewardedAd() async {
    final expiry = DateTime.now().toUtc().add(const Duration(hours: 24));
    await _db.insert(
      'app_meta',
      {'key': _expiryKey, 'value': '${expiry.millisecondsSinceEpoch}'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Check if Pro is currently active.
  Future<bool> get isProActive async {
    final expiryMs = await _getProExpiry();
    if (expiryMs == null) return false;
    return DateTime.now().toUtc().millisecondsSinceEpoch < expiryMs;
  }

  /// Get Pro expiry time (UTC).
  Future<DateTime?> get expiresAt async {
    final expiryMs = await _getProExpiry();
    if (expiryMs == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(expiryMs, isUtc: true);
  }

  /// Clear Pro status (for testing/debug).
  Future<void> clearPro() async {
    await _db.delete('app_meta', where: 'key = ?', whereArgs: [_expiryKey]);
  }

  Future<int?> _getProExpiry() async {
    final rows = await _db.query(
      'app_meta',
      where: 'key = ?',
      whereArgs: [_expiryKey],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return int.tryParse(rows.first['value'] as String? ?? '');
  }
}
