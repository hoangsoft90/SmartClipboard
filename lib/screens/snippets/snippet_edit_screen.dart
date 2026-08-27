import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../generated/l10n/app_localizations.dart';
import '../../models/snippet.dart';
import '../../services/expansion_engine.dart';
import '../../state/providers.dart';

class SnippetEditScreen extends ConsumerStatefulWidget {
  final String? snippetId;
  final Snippet? existing;
  const SnippetEditScreen({super.key, this.snippetId, this.existing});

  @override
  ConsumerState<SnippetEditScreen> createState() => _SnippetEditScreenState();
}

class _SnippetEditScreenState extends ConsumerState<SnippetEditScreen> {
  late final TextEditingController _title;
  late final TextEditingController _trigger;
  late final TextEditingController _content;
  String? _folderId;
  Snippet? _loadedSnippet;

  bool get _isEditing => _loadedSnippet != null;

  @override
  void initState() {
    super.initState();
    _loadedSnippet = widget.existing;
    _title = TextEditingController(text: _loadedSnippet?.title ?? '');
    _trigger = TextEditingController(text: _loadedSnippet?.trigger ?? '');
    _content = TextEditingController(text: _loadedSnippet?.content ?? '');
    _folderId = _loadedSnippet?.folderId;
    _loadSnippetIfNeeded();
  }

  Future<void> _loadSnippetIfNeeded() async {
    if (widget.snippetId != null && widget.existing == null) {
      final snippet = await ref.read(snippetRepoProvider).getById(widget.snippetId!);
      if (snippet != null && mounted) {
        setState(() {
          _loadedSnippet = snippet;
          _title.text = snippet.title;
          _trigger.text = snippet.trigger;
          _content.text = snippet.content;
          _folderId = snippet.folderId;
        });
      }
    }
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
      await controller.save(_loadedSnippet!.copyWith(
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
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final triggerText = _trigger.text.trim();
    final msg = archived > 0
        ? l10n.snippetCreatedWithArchived(archived)
        : '${l10n.snippetCreated} ;$triggerText';
    Navigator.pop(context);
    messenger.showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _delete() async {
    if (!_isEditing) return;
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.snippetDeleteTitle),
        content: Text(
            '${l10n.popupDeletePermanently} snippet này? (${l10n.btnCancel} không thể hoàn tác)'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.btnCancel)),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.popupDeletePermanently)),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(snippetListProvider.notifier).deleteForever(
          _loadedSnippet!.id);
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  bool get _hasChanges {
    if (_isEditing) {
      final s = _loadedSnippet!;
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
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.snippetDiscardTitle),
        content: Text(l10n.snippetDiscardContent),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.btnStay)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.btnExit)),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
        appBar: AppBar(title: Text(_isEditing ? 'Sửa snippet' : l10n.snippetsNew)),
        body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _title,
            decoration: InputDecoration(labelText: l10n.snippetTitleLabel),
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
            decoration: InputDecoration(
                labelText: l10n.snippetContentLabel,
                alignLabelWithHint: true,
                border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            value: _folderId,
            decoration: InputDecoration(labelText: l10n.snippetFolderOptional),
            items: [
              DropdownMenuItem<String?>(
                  value: null, child: Text('(${l10n.btnCancel})')),
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
            label: Text(_isEditing ? l10n.btnSave : l10n.snippetCreated),
          ),
          if (_isEditing)
            TextButton.icon(
              onPressed: _delete,
              icon: Icon(Icons.delete_forever,
                  color: Theme.of(context).colorScheme.error),
              label: Text(l10n.popupDeletePermanently,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
        ],
      ),
      ),
    );
  }
}

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
