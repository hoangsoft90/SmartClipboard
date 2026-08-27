import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_limits.dart';
import '../../services/expansion_engine.dart';
import '../../services/metrics_service.dart';
import '../../state/providers.dart';

/// Expander Playground — P0 BẮT BUỘC (Master Spec mục 6, STRICT RULE 20).
///
/// User gõ `;email` + Space trong text field lớn → thấy expansion NGAY LẬP
/// TỨC, không cần cài keyboard. Đây là công cụ onboarding mạnh nhất và công cụ
/// đo product-market fit sớm nhất (metric `playground_expansions` — mục 10).
class PlaygroundScreen extends ConsumerStatefulWidget {
  const PlaygroundScreen({super.key});

  @override
  ConsumerState<PlaygroundScreen> createState() => _PlaygroundScreenState();
}

class _PlaygroundScreenState extends ConsumerState<PlaygroundScreen> {
  final _controller = TextEditingController();
  String? _lastExpandedContent;
  String? _lastExpandedTrigger;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    final engine = ref.read(expansionEngineProvider);
    final outcome = engine.processInput(text);
    if (!outcome.changed) return;

    // Thay thế buffer + đưa caret về cuối. Dart String ops là an toàn UTF-16
    // code unit (STRICT RULE 15 áp dụng cho native IME — Phase 1).
    _controller.value = TextEditingValue(
      text: outcome.outputText,
      selection: TextSelection.collapsed(offset: outcome.outputText.length),
    );

    if (outcome.expandedTrigger != null && outcome.expandedSnippetId != null) {
      setState(() {
        _lastExpandedTrigger = outcome.expandedTrigger;
        _lastExpandedContent = engine.triggerToContent[outcome.expandedTrigger];
      });
      _trackUsage(outcome);
    }
  }

  Future<void> _trackUsage(ExpansionOutcome outcome) async {
    await ref.read(metricsProvider).increment(MetricsService.kExpansionCount);
    await ref
        .read(metricsProvider)
        .increment(MetricsService.kPlaygroundExpansions);
    await ref.read(metricsProvider).markActiveToday();
    if (outcome.expandedSnippetId != null) {
      await ref
          .read(snippetRepoProvider)
          .incrementUsage(outcome.expandedSnippetId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final snippetCount =
        ref.watch(snippetListProvider).value?.where((s) => s.isEnabled).length ??
            0;
    final keyboardEnabled = ref.watch(keyboardEnabledProvider).value ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('✨ Smart Expander Playground')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _controller,
            maxLines: 8,
            onChanged: _onChanged,
            decoration: InputDecoration(
              hintText: 'Nhập trigger (vd: ${snippetCount > 0 ? ";trigger" : ";email"}) rồi gõ dấu cách...',
              border: const OutlineInputBorder(),
              helperText:
                  'Mẹo: ;;email → xuất ra ;email (escape). Trigger chỉ mở rộng '
                  'khi theo sau bởi Space/Enter/dấu câu.',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),

          if (_lastExpandedContent != null)
            Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment:
                    CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.auto_fix_high,
                        size: 18,
                        color:
                            Theme.of(context).colorScheme.onSecondaryContainer),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                          'Đã mở rộng $_lastExpandedTrigger',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context)
                                  .colorScheme.onSecondaryContainer)),
                    ),
                    IconButton(
                      tooltip: 'Copy kết quả',
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(
                            text: _lastExpandedContent ?? ''));
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Đã copy')));
                      },
                    ),
                  ]),
                  const SizedBox(height: 8),
                  SelectableText(_lastExpandedContent!),
                ]),
              ),
            ),

          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: Icon(keyboardEnabled
                  ? Icons.check_circle
                  : Icons.keyboard_alt_outlined),
              title: Text(keyboardEnabled
                  ? 'Bàn phím Smart Clipboard đã bật'
                  : '💡 Bật keyboard Smart Clipboard để dùng ngay trên mọi ứng '
                      'dụng!'),
              subtitle: keyboardEnabled ? null : const Text(
                  '🔧 Tính năng sẽ có ở Phase 1 — hiện tại chỉ dùng được '
                  'trong Playground',
                  style: TextStyle(fontSize: 12)),
              trailing: keyboardEnabled
                  ? null
                  : TextButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Bàn phím Smart Clipboard chưa khả '
                                'dụng ở Phase 0. Đang phát triển!'),
                            duration: Duration(seconds: 3),
                          ),
                        );
                      },
                      child: const Text('Bật'),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          if (snippetCount == 0)
            const Text(
                'Chưa có snippet nào. Tạo snippet ở tab "Snippet" trước, '
                'rồi quay lại đây thử gõ tắt!',
                textAlign: TextAlign.center),
          Text(
            'Prefix mặc định: "${AppLimits.defaultTriggerPrefix}" '
            '(Pro: cho phép đổi)',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
