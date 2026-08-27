import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_limits.dart';
import '../../state/providers.dart';

class FoldersScreen extends ConsumerWidget {
  const FoldersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foldersAsync = ref.watch(folderListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Folders')),
      body: foldersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(child: Text('Lỗi tải dữ liệu')),
        data: (folders) => folders.isEmpty
            ? const Center(child: Text('Chưa có folder nào'))
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
                          // Xoá folder → snippet giữ nguyên, folder_id = NULL
                          // (FOREIGN KEY ON DELETE SET NULL — schema mục 2).
                          await controller.delete(folder['id'] as String);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'rename', child: Text('Đổi tên')),
                        PopupMenuItem(value: 'delete', child: Text('Xoá')),
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
                title: const Text('Giới hạn bản Free'),
                content: Text(
                    'Bản Free tối đa ${AppLimits.freeFolderLimit} folders. '
                    'Dữ liệu hiện tại KHÔNG bị xoá — nâng cấp Pro để tạo '
                    'không giới hạn.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Để sau')),
                ],
              ),
            );
            return;
          }
          _createDialog(context, ref);
        },
        icon: const Icon(Icons.create_new_folder_outlined),
        label: const Text('Folder mới'),
      ),
    );
  }

  void _createDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Folder mới'),
        content: TextField(controller: nameController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Tên folder')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              await ref.read(folderListProvider.notifier).create(name);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
            },
            child: const Text('Tạo'),
          ),
        ],
      ),
    );
  }

  void _renameDialog(BuildContext context, WidgetRef ref, String id,
      String currentName) {
    final nameController = TextEditingController(text: currentName);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đổi tên folder'),
        content: TextField(controller: nameController, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              await ref.read(folderListProvider.notifier).rename(id, name);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }
}
