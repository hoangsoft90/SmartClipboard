import 'package:flutter/material.dart';

/// Badge cảnh báo privacy_risk_score (0/1/2).
///
/// ⚠️ STRICT RULE 9 [HEURISTIC BOUNDARY]: tính năng này chỉ là Heuristic/Gợi ý
/// dựa trên Regex + Entropy — KHÔNG được quảng cáo là giải pháp bảo mật tuyệt
/// đối ở bất kỳ đâu. Tooltip/badge phải luôn mang tính "gợi ý", không khẳng định
/// "đây là mật khẩu/OTP".
class PrivacyRiskBadge extends StatelessWidget {
  /// 1 = nghi vấn, 2 = rủi ro cao (heuristic only).
  final int score;
  const PrivacyRiskBadge({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    final isHigh = score >= 2;
    return Tooltip(
      message: isHigh
          ? 'Heuristic: văn bản có thể chứa dữ liệu nhạy cảm '
              '(OTP/mật khẩu/API key?). Chỉ là dự đoán.'
          : 'Heuristic: văn bản trông ngẫu nhiên, có thể nhạy cảm. '
              'Chỉ là dự đoán.',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: isHigh
              ? Theme.of(context).colorScheme.errorContainer
              : Theme.of(context).colorScheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(isHigh ? Icons.gpp_maybe : Icons.help_outline,
              size: 14,
              color: isHigh
                  ? Theme.of(context).colorScheme.onErrorContainer
                  : Theme.of(context).colorScheme.onTertiaryContainer),
        ]),
      ),
    );
  }
}
