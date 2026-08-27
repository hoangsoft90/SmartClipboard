import '../core/constants/app_limits.dart';

/// Kết quả xử lý một lần "gõ xong delimiter" trong text field nội bộ.
class ExpansionOutcome {
  /// Text mới sau khi xử lý (== input nếu không đổi).
  final String outputText;

  /// Có xảy ra thay thế/escape hay không.
  final bool changed;

  /// Trigger của snippet vừa expand (null nếu chỉ escape hoặc không đổi).
  final String? expandedTrigger;

  /// Id snippet vừa expand (nếu caller cung cấp map id theo trigger).
  final String? expandedSnippetId;

  const ExpansionOutcome({
    required this.outputText,
    this.changed = false,
    this.expandedTrigger,
    this.expandedSnippetId,
  });

  const ExpansionOutcome.unchanged(String text)
      : this(outputText: text);
}

/// In-App Expansion Engine — dùng bởi Expander Playground (P0 bắt buộc,
/// STRICT RULE 20) và mọi text field expansion nội bộ app.
///
/// Trigger rules chính thức — Master Spec mục 4.2 (STRICT RULE 14):
/// - Trigger chỉ expand khi theo sau bởi delimiter: Space/Enter/Tab hoặc
///   dấu câu `.` `,` `!` `?`.
/// - Escape: gõ `;;email` → xuất ra `;email` (một dấu `;`), bỏ qua expansion.
/// - Instant mode (expand ngay không cần delimiter): KHÔNG làm ở MVP — dễ
///   false-trigger (vd phá `user@email.com`).
///
/// Lưu ý STRICT RULE 15 [UTF-16 OFFSET]: rule này áp dụng cho logic xoá text
/// trên native IME (Phase 1, `deleteSurroundingText`). Trong app, việc thay
/// thế chạy trên Dart String (UTF-16 code unit inherently) qua
/// replaceRange nên không lệch ký tự.
class ExpansionEngine {
  final Map<String, String> triggerToContent;
  final Map<String, String>? triggerToId;
  final String prefix;

  ExpansionEngine({
    required this.triggerToContent,
    this.triggerToId,
    this.prefix = AppLimits.defaultTriggerPrefix,
  })  : assert(prefix.length == 1, 'Prefix hiện chỉ hỗ trợ 1 ký tự');

  static const String delimiters = AppLimits.expansionDelimiters;

  RegExp get _tokenPattern => RegExp(r'([^\s.,!?]+)$');

  /// Xử lý buffer text hiện tại (thường gọi trong onChanged sau khi user gõ
  /// thêm một ký tự delimiter).
  ExpansionOutcome processInput(String input) {
    if (input.isEmpty) return ExpansionOutcome.unchanged(input);

    final lastChar = input.substring(input.length - 1);
    // Chỉ xét ngay sau khi user gõ delimiter (rule mục 4.2).
    if (!delimiters.contains(lastChar)) {
      return ExpansionOutcome.unchanged(input);
    }

    final body = input.substring(0, input.length - 1);
    final match = _tokenPattern.firstMatch(body);
    if (match == null) return ExpansionOutcome.unchanged(input);

    final token = match.group(1)!;
    if (!token.startsWith(prefix)) return ExpansionOutcome.unchanged(input);

    // Escape: `;;abc` → xuất ra `;abc`, giữ nguyên phần còn lại của token.
    if (token.startsWith('$prefix$prefix')) {
      final unescaped = token.substring(1); // bỏ bớt một prefix
      final newBody =
          body.replaceRange(match.start, body.length, unescaped);
      return ExpansionOutcome(
        outputText: newBody + lastChar,
        changed: true,
      );
    }

    final trigger = token.substring(prefix.length);
    final content = triggerToContent[trigger];
    if (content == null) return ExpansionOutcome.unchanged(input);

    final newBody = body.replaceRange(match.start, body.length, content);
    return ExpansionOutcome(
      outputText: newBody + lastChar,
      changed: true,
      expandedTrigger: trigger,
      expandedSnippetId: triggerToId?[trigger],
    );
  }
}
