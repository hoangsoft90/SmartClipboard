import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../generated/l10n/app_localizations.dart';
import '../state/providers.dart';

Future<void> showSaveSnippetDialog(
  BuildContext context,
  WidgetRef ref, {
  String? initialContent,
}) async {
  final l10n = AppLocalizations.of(context);
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
        title: Text(l10n.snippetNewTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(labelText: l10n.snippetTitleLabel),
              ),
              TextField(
                controller: triggerController,
                decoration: InputDecoration(
                    labelText: l10n.snippetTriggerLabel,
                    prefixText: ';'),
              ),
              TextField(
                controller: contentController,
                maxLines: 4,
                decoration: InputDecoration(labelText: l10n.snippetContentLabel),
              ),
              if (folders.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: folderId,
                  decoration: InputDecoration(labelText: l10n.snippetFolderOptional),
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
              child: Text(l10n.btnCancel)),
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
                    ? l10n.snippetCreatedWithArchived(archived)
                    : '${l10n.snippetCreated} ;$trigger'),
              ));
            },
            child: Text(l10n.btnSave),
          ),
        ],
      );
    }),
  );
  return;
}

Future<void> showSaveSharedTextDialog(
    BuildContext context, WidgetRef ref, String text) async {
  final l10n = AppLocalizations.of(context);
  await showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(l10n.shareReceived(text.length),
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        ListTile(
          leading: const Icon(Icons.history),
          title: Text(l10n.shareSaveToHistory),
          onTap: () async {
            Navigator.pop(ctx);
            // FIX 1.2: Truyền trực tiếp shared text vào saveContent()
            // KHÔNG đọc lại clipboard — tránh race condition
            await ref.read(clipboardServiceProvider).saveContent(
                  text,
                  forceSave: true,
                );
            await ref.read(clipboardListProvider.notifier).reload();
          },
        ),
        ListTile(
          leading: const Icon(Icons.bolt),
          title: Text(l10n.shareCreateSnippet),
          onTap: () {
            Navigator.pop(ctx);
            showSaveSnippetDialog(context, ref, initialContent: text);
          },
        ),
      ]),
    ),
  );
}
