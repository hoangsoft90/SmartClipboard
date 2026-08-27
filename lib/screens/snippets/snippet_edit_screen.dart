import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/snippet.dart';
import '../../services/expansion_engine.dart';
import '../../state/providers.dart';

/// Tạo / sửa snippet. Trigger được validate: không rỗng, không chứa
/// whitespace/delimiter (vì expansion chỉ xét token liền mạch — mục 4.2).
class SnippetEditScreen extends ConsumerStatefulWidget {
  final Snippet? existing;
  const SnippetEditScreen({super.key, this.existing});

  @override
  ConsumerState<SnippetEditScreen> createState() => _SnippetEditScreenState();
}

class _SnippetEditScreenState extends ConsumerState<SnippetEditScreen> {
  late final TextEditingController _title;
  late final TextEditingController _trigger;
  late final TextEditingController _content;
  String? _folderId;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final s = widget.existing;
    _title = TextEditingController(text: s?.title ?? '');
    _trigger = TextEditingController(text: s?.trigger ?? '');
    _content = TextEditingController(text: s?.content ?? '');
    _folderId = s?.folderId;
  }

  @override
  void dispose() {
    _title.dispose();
    _trigger.dispose();
    _content.dispose();
    super.dispose();
  }

  String? _validateTrigger(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return 'Không được để trống';
    // Token của expansion engine không chứa space/dấu câu — delimiter là ký tự
    // kích hoạt nên không thể nằm trong trigger.
    if (RegExp(r'[\s.,!?]').hasMatch(t)) {
      return 'Trigger chỉ gồm chữ/số/ký hiệu liền mạch (không space, dấu câu)';
    }
    return null;
  }

  Future<void> _save() async {
    final triggerError = _validateTrigger(_trigger.text);
    if (_content.text.trim().isEmpty || triggerError != null) {
      setState(() {});
      return;
    }

    final controller = ref.read(snippetListProvider.notifier);
    int archived = 0;
    if (_isEditing) {
      await controller.save(widget.existing!.copyWith(
        title: _title.text.trim().isEmpty
            ? _trigger.text.trim()
            : _title.text.trim(),
        trigger: _trigger.text.trim(),
        content: _content.text.trim(),
        folderId: _folderId,
      ));
    } else {
      archived = await controller.create(
        title: _title.text.trim().isEmpty
            ? _trigger.text.trim()
            : _title.text.trim(),
        trigger: _trigger.text.trim(),
        content: _content.text.trim(),
        folderId: _folderId,
      );
    }

    if (!mounted) return;
    // Lưu message + messenger TRƯỚC khi pop (context sẽ không hợp lệ sau pop).
    final messenger = ScaffoldMessenger.of(context);
    final triggerText = _trigger.text.trim();
    final msg = archived > 0
        ? 'Đã lưu. $archived snippet ít dùng nhất bị ẩn do giới hạn Free '
            '(dữ liệu vẫn giữ nguyên — mua Pro để mở khoá).'
        : 'Đã lưu snippet ;$triggerText';
    Navigator.pop(context);
    messenger.showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _delete() async {
    if (!_isEditing) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá snippet?'),
        content: const Text(
            'Xoá vĩnh viễn snippet này khỏi database? '
            '(Không thể hoàn tác)'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Huỷ')),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Xoá vĩnh viễn')),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(snippetListProvider.notifier).deleteForever(
          widget.existing!.id);
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  bool get _hasChanges {
    if (_isEditing) {
      final s = widget.existing!;
      return _title.text.trim() != s.title ||
          _trigger.text.trim() != s.trigger ||
          _content.text.trim() != s.content ||
          _folderId != s.folderId;
    }
    return _title.text.isNotEmpty ||
        _trigger.text.isNotEmpty ||
        _content.text.isNotEmpty;
  }

  Future<bool> _confirmDiscard() async {
    if (!_hasChanges) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thoát without saving?'),
        content: const Text('Bạn có thay đổi chưa lưu. Thoát sẽ mất nội dung.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Ở lại')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Thoát')),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final folders = ref.watch(folderListProvider).value ?? [];
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _confirmDiscard();
        if (shouldPop && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(_isEditing ? 'Sửa snippet' : 'Snippet mới')),
        body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _title,
            decoration:
                const InputDecoration(labelText: 'Tên (vd: Email công việc)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _trigger,
            autofillHints: null,
            decoration: InputDecoration(
              labelText: 'Trigger',
              prefixText: ';',
              helperText:
                  'Gõ ;${_trigger.text.isEmpty ? "trigger" : _trigger.text} + '
                  'dấu cách để mở rộng',
              errorText: _validateTrigger(_trigger.text),
            ),
            inputFormatters: [
              NoWhitespaceInputFormatter(),
            ],
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _content,
            maxLines: 8,
            decoration: const InputDecoration(
                labelText: 'Nội dung sẽ được chèn',
                alignLabelWithHint: true,
                border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            value: _folderId,
            decoration: const InputDecoration(labelText: 'Folder'),
            items: [
              const DropdownMenuItem<String?>(
                  value: null, child: Text('(Không folder)')),
              ...folders.map((f) => DropdownMenuItem<String?>(
                  value: f['id'] as String?,
                  child: Text(f['name'] as String? ?? ''))),
            ],
            onChanged: (v) => setState(() => _folderId = v),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: Text(_isEditing ? 'Lưu thay đổi' : 'Tạo snippet'),
          ),
          if (_isEditing)
            TextButton.icon(
              onPressed: _delete,
              icon: Icon(Icons.delete_forever,
                  color: Theme.of(context).colorScheme.error),
              label: Text('Xoá vĩnh viễn',
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
        ],
      ),
      ), // Scaffold
    ); // PopScope
  }
}

/// Chặn whitespace trong trigger ngay khi gõ.
class NoWhitespaceInputFormatter extends TextInputFormatter {
  static const delimiters = ExpansionEngine.delimiters;
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final filtered = newValue.text
        .split('')
        .where((ch) => !RegExp(r'\s').hasMatch(ch))
        .join();
    if (filtered == newValue.text) return newValue;
    return newValue.copyWith(text: filtered,
        selection: TextSelection.collapsed(offset: filtered.length));
  }
}
