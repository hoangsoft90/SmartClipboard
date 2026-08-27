import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';

/// Dialog tạo snippet nhanh (dùng cho Share Sheet fallback và
/// "Save as Snippet" từ lịch sử clipboard).
Future<void> showSaveSnippetDialog(
  BuildContext context,
  WidgetRef ref, {
  String? initialContent,
}) async {
  final titleController = TextEditingController();
  final triggerController = TextEditingController();
  final contentController =
      TextEditingController(text: initialContent ?? '');
  String? folderId;
  final folders = await ref
      .read(snippetRepoProvider)
      .getFolders()
      .then((list) => list
          .map((x) => {'id': x.id, 'name': x.name} as Map<String, Object?>)
          .toList())
      .catchError((Object _) => <Map<String, Object?>>[]);

  if (!context.mounted) return;

  await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) {
      return AlertDialog(
        title: const Text('Tạo snippet mới'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                    labelText: 'Tên (vd: Email công việc)'),
              ),
              TextField(
                controller: triggerController,
                decoration: const InputDecoration(
                    labelText: 'Trigger không dấu cách (vd: email)',
                    prefixText: ';'),
              ),
              TextField(
                controller: contentController,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Nội dung'),
              ),
              if (folders.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: folderId,
                  decoration:
                      const InputDecoration(labelText: 'Folder (tuỳ chọn)'),
                  items: folders
                      .map((f) => DropdownMenuItem(
                          value: f['id'] as String?,
                          child: Text(f['name'] as String? ?? '')))
                      .toList(),
                  onChanged: (v) => setDialogState(() => folderId = v),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Huỷ')),
          FilledButton(
            onPressed: () async {
              final trigger = triggerController.text.trim();
              if (trigger.isEmpty || contentController.text.trim().isEmpty) {
                return;
              }
              final archived = await ref
                  .read(snippetListProvider.notifier)
                  .create(
                    title: titleController.text.trim().isEmpty
                        ? trigger
                        : titleController.text.trim(),
                    trigger: trigger,
                    content: contentController.text.trim(),
                    folderId: folderId,
                  );
              if (!ctx.mounted) return;
              Navigator.pop(ctx, true);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(archived > 0
                    ? 'Đã tạo snippet. $archived snippet cũ bị ẩn do giới hạn '
                        'Free — mua Pro để mở khoá.'
                    : 'Đã tạo snippet ;$trigger'),
              ));
            },
            child: const Text('Lưu'),
          ),
        ],
      );
    }),
  );
  return;
}

/// Nhận text được share từ system sharesheet → chọn lưu Clipboard hay Snippet.
Future<void> showSaveSharedTextDialog(
    BuildContext context, WidgetRef ref, String text) async {
  await showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Nhận text được chia sẻ (${text.length} ký tự)',
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        ListTile(
          leading: const Icon(Icons.history),
          title: const Text('Lưu vào lịch sử Clipboard'),
          onTap: () async {
            Navigator.pop(ctx);
            await ref.read(clipboardServiceProvider).captureFromSystem(
                  forceSave: true, // user chủ động gửi — bỏ qua pause mode?
                );
            await ref.read(clipboardListProvider.notifier).reload();
          },
        ),
        ListTile(
          leading: const Icon(Icons.bolt),
          title: const Text('Tạo Snippet với trigger'),
          onTap: () {
            Navigator.pop(ctx);
            showSaveSnippetDialog(context, ref, initialContent: text);
          },
        ),
      ]),
    ),
  );
}
