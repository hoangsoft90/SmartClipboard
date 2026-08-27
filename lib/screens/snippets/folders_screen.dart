import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_limits.dart';
import '../../generated/l10n/app_localizations.dart';
import '../../state/providers.dart';

class FoldersScreen extends ConsumerWidget {
  const FoldersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final foldersAsync = ref.watch(folderListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.foldersTitle)),
      body: foldersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.clipboardLoadError)),
        data: (folders) => folders.isEmpty
            ? Center(child: Text(l10n.foldersEmpty))
            : ListView.builder(
                itemCount: folders.length,
                itemBuilder: (ctx, i) {
                  final folder = folders[i];
                  return ListTile(
                    leading: const Icon(Icons.folder),
                    title: Text(folder['name'] as String? ?? ''),
                    trailing: PopupMenuButton<String>(
                      onSelected: (action) async {
                        final controller =
                            ref.read(folderListProvider.notifier);
                        if (action == 'rename') {
                          _renameDialog(context, ref,
                              folder['id'] as String,
                              folder['name'] as String? ?? '');
                        } else if (action == 'delete') {
                          await controller.delete(folder['id'] as String);
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'rename', child: Text(l10n.btnRename)),
                        PopupMenuItem(value: 'delete', child: Text(l10n.btnDelete)),
                      ],
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final repo = ref.read(snippetRepoProvider);
          if (!await repo.canCreateFolder()) {
            if (!context.mounted) return;
            showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(l10n.foldersFreeLimit),
                content: Text(
                    'Bản Free tối đa ${AppLimits.freeFolderLimit} folders. '
                    'Dữ liệu hiện tại KHÔNG bị xoá — nâng cấp Pro để tạo '
                    'không giới hạn.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(l10n.btnLater)),
                ],
              ),
            );
            return;
          }
          _createDialog(context, ref);
        },
        icon: const Icon(Icons.create_new_folder_outlined),
        label: Text(l10n.foldersNew),
      ),
    );
  }

  void _createDialog(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final nameController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.foldersNew),
        content: TextField(controller: nameController,
            autofocus: true,
            decoration: InputDecoration(labelText: l10n.snippetTitleLabel)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(l10n.btnCancel)),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              await ref.read(folderListProvider.notifier).create(name);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
            },
            child: Text(l10n.btnCreate),
          ),
        ],
      ),
    );
  }

  void _renameDialog(BuildContext context, WidgetRef ref, String id,
      String currentName) {
    final l10n = AppLocalizations.of(context);
    final nameController = TextEditingController(text: currentName);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.foldersRename),
        content: TextField(controller: nameController, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(l10n.btnCancel)),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              await ref.read(folderListProvider.notifier).rename(id, name);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
            },
            child: Text(l10n.btnSave),
          ),
        ],
      ),
    );
  }
}
