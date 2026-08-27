/// ⚠️ HEURISTIC ONLY — KHÔNG PHẢI SECURITY GUARANTEE (Master Spec mục 5.1,
/// STRICT RULE 9).
///
/// Các pattern dưới đây chỉ dùng để GỢI Ý cho user rằng văn bản *có thể* chứa
/// dữ liệu nhạy cảm, để user quyết định có lưu hay không. Tuyệt đối không được
/// quảng cáo/marketing đây là tính năng "bảo mật tuyệt đối" ở bất kỳ đâu
/// (UI, Store listing, code comment). Entropy cao cũng có thể là random ID/hash
/// hợp lệ — vì vậy output chỉ là `privacy_risk_score` (0/1/2), không gắn nhãn
/// cứng "Đây là Password".
class SensitivePattern {
  final String label;
  final RegExp regex;
  const SensitivePattern(this.label, this.regex);
}

class SensitivePatterns {
  SensitivePatterns._();

  /// OTP thường: 6 chữ số đứng độc lập.
  static final otp = SensitivePattern(
    'otp',
    RegExp(r'(?<!\d)\d{6}(?!\d)'),
  );

  /// Số thẻ ngân hàng: 13–19 chữ số, có thể phân nhóm bằng space hoặc '-'.
  /// (Kiểm tra Luhn là việc của Phase nâng cao; ở đây chỉ là pattern thô.)
  static final cardNumber = SensitivePattern(
    'card_number',
    RegExp(r'\b(?:\d[ -]?){13,19}\b'),
  );

  /// API key phổ biến: OpenAI `sk-`, AWS `AKIA`, GitHub `ghp_`, Slack `xox*-`.
  static final apiKey = SensitivePattern(
    'api_key',
    RegExp(
      r'(?:sk-[A-Za-z0-9]{16,}'
      r'|AKIA[0-9A-Z]{16}'
      r'|ghp_[A-Za-z0-9]{30,}'
      r'|github_pat_[A-Za-z0-9_]{20,}'
      r'|xox[baprs]-[A-Za-z0-9-]{10,})',
    ),
  );

  /// Seed phrase: 12+ từ liên tiếp (BIP39 style, heuristic thô).
  static final seedPhrase = SensitivePattern(
    'seed_phrase',
    RegExp(r'(?:\b[a-z]{3,}\b\s){11,}\b[a-z]{3,}\b'),
  );

  /// Khối private key PEM.
  static final privateKeyBlock = SensitivePattern(
    'private_key',
    RegExp(r'-----BEGIN [A-Z ]*PRIVATE KEY-----'),
  );

  static final all = [
    otp,
    cardNumber,
    apiKey,
    seedPhrase,
    privateKeyBlock,
  ];
}
