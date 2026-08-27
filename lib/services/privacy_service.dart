import '../core/constants/app_limits.dart';
import '../core/constants/sensitive_patterns.dart';
import '../core/utils/entropy.dart';

enum PrivacyRiskLevel {
  safe, //    score 0
  suspect, // score 1 — nghi vấn, lưu + banner gợi ý xoá sau 24h
  highRisk, // score 2 — nghi vấn cao, KHÔNG tự lưu nếu user không xác nhận
}

class PrivacyAssessment {
  final int riskScore;
  final String contentType;
  final List<String> matchedPatterns;

  const PrivacyAssessment({
    required this.riskScore,
    required this.contentType,
    this.matchedPatterns = const [],
  });

  PrivacyRiskLevel get level {
    switch (riskScore) {
      case 2:
        return PrivacyRiskLevel.highRisk;
      case 1:
        return PrivacyRiskLevel.suspect;
      default:
        return PrivacyRiskLevel.safe;
    }
  }
}

/// Sensitive Data Heuristic — Master Spec mục 5.1.
///
/// ⚠️⚠️ CHỈ LÀ HEURISTIC, KHÔNG PHẢI SECURITY GUARANTEE ⚠️⚠️
///
/// Output là `privacy_risk_score` (0/1/2) DỰA TRÊN ĐOÁN — regex có thể miss,
/// entropy cao có thể chỉ là random ID/hash hợp lệ. KHÔNG được gắn nhãn cứng
/// "Đây là Password", KHÔNG được quảng cáo đây là bảo mật tuyệt đối ở bất kỳ
/// đâu (UI, Store listing, comment) — STRICT RULE 9.
///
/// Giải pháp "thật" cho niềm tin user là Incognito/Pause Mode (mục 5.2) chứ
/// không phải việc cố đoán đúng bằng heuristic.
class PrivacyService {
  /// Ngưỡng entropy (bits/char) coi như "biến thiên cao".
  static const double _highEntropyThreshold = 3.5;

  /// Độ dài tối thiểu để cân nhắc entropy check (tránh false-positive trên
  /// chuỗi ngắn ngẫu nhiên tự nhiên).
  static const int _entropyMinLength = 16;

  PrivacyService();

  PrivacyAssessment assess(String content) {
    if (content.trim().isEmpty) {
      return const PrivacyAssessment(
          riskScore: 0, contentType: 'text');
    }

    final matched = <String>[];

    // 1) Regex patterns "chắc chắn" → score 2.
    for (final pattern in SensitivePatterns.all) {
      if (pattern.regex.hasMatch(content)) matched.add(pattern.label);
    }
    if (matched.isNotEmpty) {
      return PrivacyAssessment(
          riskScore: 2, contentType: 'sensitive', matchedPatterns: matched);
    }

    // 2) Entropy cao + nhiều lớp ký tự → score 1 (nghi vấn, không chắc).
    final trimmed =
        content.length <= 256 ? content : content.substring(0, 256);
    final entropy = shannonEntropy(trimmed);
    if (trimmed.length >= _entropyMinLength &&
        entropy >= _highEntropyThreshold &&
        charClassCount(trimmed) >= 3) {
      matched.add('high_entropy');
      return PrivacyAssessment(
          riskScore: 1, contentType: 'sensitive', matchedPatterns: matched);
    }

    return PrivacyAssessment(
        riskScore: 0, contentType: _classify(content));
  }

  /// Phân loại content_type (metadata hiển thị, không phải security boundary).
  String _classify(String content) {
    final t = content.trim();
    if (RegExp(r'^https?://\S+$', caseSensitive: false).hasMatch(t)) {
      return 'url';
    }
    if (RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(t)) return 'email';
    if (RegExp(r'^\+?[\d\s\-()]{7,}$').hasMatch(t)) return 'phone';
    return 'text';
  }

  /// expires_at gợi ý khi user đồng ý banner "Tự động xoá sau 24h?" (mục 5.1).
  static int suggestedExpiryForSuspect(int nowMs) =>
      nowMs + AppLimits.sensitiveAutoDeleteHours * 3600 * 1000;

  /// expires_at mặc định theo setting Auto-Expiration (1/7/30 ngày — P0).
  static int expiryForDays(int nowMs, int days) =>
      nowMs + days * 86400000;
}
