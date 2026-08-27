import 'package:flutter_test/flutter_test.dart';
import 'package:smart_clipboard/services/expansion_engine.dart';

void main() {
  Map<String, String> triggers = {};
  Map<String, String> ids = {};
  late ExpansionEngine engine;

  setUp(() {
    triggers = {
      'email': 'contact@company.com',
      'addr': '123 Đường ABC, Hà Nội',
    };
    ids = {'email': 'id-email', 'addr': 'id-addr'};
    engine =
        ExpansionEngine(triggerToContent: triggers, triggerToId: ids);
  });

  test('expand khi trigger theo sau bởi Space (STRICT RULE 14)', () {
    final r = engine.processInput(';email ');
    expect(r.changed, isTrue);
    expect(r.outputText, 'contact@company.com ');
    expect(r.expandedTrigger, 'email');
    expect(r.expandedSnippetId, 'id-email');
  });

  test('KHÔNG expand khi chưa gõ delimiter', () {
    final r = engine.processInput(';email');
    expect(r.changed, isFalse);
    expect(r.outputText, ';email');
  });

  test('delimiter là dấu câu cũng kích hoạt (. , ! ?)', () {
    expect(engine.processInput(';email.').outputText,
        'contact@company.com.');
    expect(engine.processInput(';email!').outputText,
        'contact@company.com!');
    expect(engine.processInput(';email,\n').outputText,
        'contact@company.com,\n');
  });

  test('Enter/Tab là delimiter', () {
    expect(engine.processInput(';email\n').changed, isTrue);
    expect(engine.processInput(';addr\t').outputText,
        '123 Đường ABC, Hà Nội\t');
  });

  test('escape ;;email + space → ;email + space (không expand)', () {
    final r = engine.processInput(';;email ');
    expect(r.changed, isTrue);
    expect(r.outputText, ';email ');
  });

  test('trigger lạ → không đổi', () {
    final r = engine.processInput(';nothing ');
    expect(r.changed, isFalse);
  });

  test('trigger nằm giữa từ (không có biên token) → KHÔNG expand '
      '(tránh phá user@email.com — mục 4.2 instant mode bị loại)', () {
    // Token trích ra là 'user;email' — không bắt đầu bằng prefix.
    final r = engine.processInput('user;email ');
    expect(r.changed, isFalse);
  });

  test('emoji dính liền prefix tạo MỘT token duy nhất → KHÔNG expand '
      '(token rule: chỉ token bắt đầu bằng prefix mới xét)', () {
    triggers['x'] = '😀 emoji 🇻🇳';
    final r = engine.processInput('😀;x ');
    expect(r.changed, isFalse); // token là '😀;x' — an toàn, không false-trigger
  });

  test('có khoảng trắng trước trigger → thay thế đúng với nội dung emoji/Unicode', () {
    triggers['x'] = '😀 emoji 🇻🇳';
    final r = engine.processInput('xinh ;x ');
    expect(r.outputText, 'xinh 😀 emoji 🇻🇳 ');
  });

  test('text dài phía trước giữ nguyên', () {
    final r = engine.processInput('Gửi cho anh em: ;email ');
    expect(r.outputText, 'Gửi cho anh em: contact@company.com ');
  });
}
