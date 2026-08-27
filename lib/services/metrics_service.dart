import '../core/database/app_database.dart';

/// Local-only Metrics Tracking — Master Spec mục 10.
///
/// STRICT RULE 7: metrics KHÔNG BAO GIỜ chứa nội dung text của user — chỉ
/// counter/flag vô hại. KHÔNG đồng bộ đi đâu cả (local-first 100%,
/// STRICT RULE 8). Metric quan trọng nhất để quyết định Go Phase 1:
/// `expansionCount / activeDay >= 1`.
class MetricsService {
  final MetaDao meta;
  MetricsService(this.meta);

  static const kSnippetsCreated = 'm_snippets_created';
  static const kExpansionCount = 'm_expansion_count';
  static const kClipboardItemsSaved = 'm_clipboard_items_saved';
  static const kClipboardItemsReused = 'm_clipboard_items_reused';
  static const kPlaygroundExpansions = 'm_playground_expansions';
  static const kDaysActive = 'm_days_active';

  Future<void> increment(String key) async {
    await meta.set(key, '${await meta.getInt(key) + 1}');
  }

  Future<int> count(String key) => meta.getInt(key);

  /// Đánh dấu user active hôm nay (chỉ lưu chuỗi ngày yyyy-MM-dd, không content).
  Future<void> markActiveToday() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final days = (await meta.get(kDaysActive))?.split(',') ?? [];
    if (!days.contains(today)) {
      days.add(today);
      await meta.set(kDaysActive, days.where((d) => d.isNotEmpty).join(','));
    }
  }

  Future<int> activeDays() async =>
      (await meta.get(kDaysActive))?.split(',').where((d) => d.isNotEmpty).length ??
          0;

  /// Metric quyết định Go/No-Go đầu tư Native IME (mục 10):
  /// >= 1 → habit thật; < 1 → chưa tạo value, không nên đầu tư nặng IME.
  Future<double> expansionsPerActiveDay() async {
    final days = await activeDays();
    if (days == 0) return 0;
    final total = await count(kExpansionCount);
    return total / days;
  }

  Future<Map<String, int>> summary() async => {
        kSnippetsCreated: await count(kSnippetsCreated),
        kExpansionCount: await count(kExpansionCount),
        kClipboardItemsSaved: await count(kClipboardItemsSaved),
        kClipboardItemsReused: await count(kClipboardItemsReused),
        kPlaygroundExpansions: await count(kPlaygroundExpansions),
        kDaysActive: await activeDays(),
      };
}
