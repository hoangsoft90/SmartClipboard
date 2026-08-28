import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

import '../core/constants/app_limits.dart';
import '../core/database/app_database.dart';
import '../models/clipboard_item.dart';
import '../repositories/clipboard_repository.dart';
import 'metrics_service.dart';
import 'privacy_service.dart';

enum CaptureResult {
  saved,
  deduplicated,
  blockedHighRisk, // score = 2 — chờ user xác nhận
  paused, // Incognito/Pause Mode bật — không ghi (mục 5.2)
  empty,
}

/// Foreground Clipboard Capture — Master Spec mục 8.
///
/// STRICT RULE 1 [NO BACKGROUND SPY]: KHÔNG có background service nghe lén
/// clipboard 24/7. App CHỈ đọc clipboard khi app lên foreground (resume) —
/// đây là hành vi duy nhất được phép ở MVP.
class ClipboardService {
  final ClipboardRepository repo;
  final MetaDao meta;
  final MetricsService metrics;
  final PrivacyService privacy;

  ClipboardService({
    required this.repo,
    required this.meta,
    required this.metrics,
    required this.privacy,
  });

  // ========================================================================
  // FIX 1.2: Tách biệt đọc clipboard hệ thống và lưu nội dung
  // ========================================================================

  /// Đọc clipboard hệ thống và xử lý logic capture.
  /// KHÔNG lưu trực tiếp — trả về kết quả để caller quyết định.
  Future<CaptureResult> captureFromSystem() async {
    // Web: clipboard capture không khả dụng qua hệ thống.
    if (kIsWeb) return CaptureResult.empty;

    // Incognito / Pause Mode (P0 bắt buộc, mục 5.2): toggle 1 chạm dừng ghi.
    if (await meta.getBool('capture_paused')) {
      return CaptureResult.paused;
    }

    final data = await Clipboard.getData('text/plain');
    final text = data?.text;
    if (text == null || text.trim().isEmpty) return CaptureResult.empty;

    // Heuristic trước khi lưu (CHỈ heuristic — mục 5.1).
    final assessment = privacy.assess(text);
    if (assessment.level == PrivacyRiskLevel.highRisk) {
      return CaptureResult.blockedHighRisk;
    }

    // An toàn để lưu — gọi saveContent
    await saveContent(text);
    return CaptureResult.saved;
  }

  /// FIX 1.2: Lưu trực tiếp nội dung `rawText` vào DB.
  /// KHÔNG đọc lại Clipboard OS — tránh race condition khi clipboard đã đổi.
  ///
  /// [rawText]: nội dung cần lưu
  /// [forceSave]: nếu true, bỏ qua pause mode (dùng khi user confirm save)
  /// [forceExpiresAt]: nếu specified, ghi đè expiration
  Future<void> saveContent(
    String rawText, {
    bool forceSave = false,
    int? forceExpiresAt,
  }) async {
    if (kIsWeb) return;

    // Nếu không force, kiểm tra pause mode
    if (!forceSave && await meta.getBool('capture_paused')) {
      return;
    }

    final expirationDays = await meta.getInt('expiration_days',
        fallback: AppLimits.expirationOptionsDays.last);
    final result = await repo.save(
      rawText,
      sourceApp: null,
      expirationDays: expirationDays,
      expiresAtOverride: forceExpiresAt,
    );
    // Local-only metrics — không chứa nội dung text (mục 10, Rule 7).
    await metrics.increment(result.wasDeduplicated
        ? MetricsService.kClipboardItemsReused
        : MetricsService.kClipboardItemsSaved);
    await metrics.markActiveToday();
  }

  /// FIX 1.2: User xác nhận LƯU nội dung bị block.
  /// Nhận trực tiếp `blockedText` — KHÔNG đọc lại clipboard.
  Future<CaptureResult> confirmSaveBlockedContent(String blockedText) async {
    await saveContent(
      blockedText,
      forceSave: true,
      forceExpiresAt:
          PrivacyService.suggestedExpiryForSuspect(
              DateTime.now().millisecondsSinceEpoch),
    );
    return CaptureResult.saved;
  }

  /// Copy item từ history ra system clipboard + metrics reuse.
  Future<void> copyToSystem(ClipboardItem item) async {
    await Clipboard.setData(ClipboardData(text: item.content));
    await repo.markUsed(item.id);
    await metrics.increment(MetricsService.kClipboardItemsReused);
    await metrics.markActiveToday();
  }
}
