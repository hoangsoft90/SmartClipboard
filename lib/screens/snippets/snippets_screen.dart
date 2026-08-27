import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/snippet.dart';
import '../../state/providers.dart';
import '../../widgets/pro_upgrade_banner.dart';
import 'folders_screen.dart';
import 'snippet_edit_screen.dart';

/// Snippet & Folder Management — P0 (mục 8: Manual Snippets & Triggers).
class SnippetsScreen extends ConsumerWidget {
  const SnippetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(snippetListProvider);
    final foldersAsync = ref.watch(folderListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Snippets (Gõ tắt)'),
        actions: [
          IconButton(
            tooltip: 'Quản lý folder',
            icon: const Icon(Icons.folder_open),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const FoldersScreen())),
          ),
        ],
      ),
      body: Column(children: [
        const ProUpgradeBanner(),
        Expanded(
          child: listAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Lỗi tải dữ liệu')),
            data: (snippets) => snippets.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bolt, size: 64,
                            color: Theme.of(context).colorScheme.outline),
                        const SizedBox(height: 12),
                        const Text('Chưa có snippet nào.\n'
                            'Bấm + để tạo gõ tắt đầu tiên (;email...)'),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: snippets.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final s = snippets[i];
                      final folderName = foldersAsync.value
                          ?.where((f) => f['id'] == s.folderId)
                          .map((f) => f['name'] as String?)
                          .firstWhere((_) => true,
                              orElse: () => null);
                      return _SnippetTile(
                          snippet: s, folderName: folderName);
                    },
                  ),
          ),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const SnippetEditScreen())),
        icon: const Icon(Icons.add),
        label: const Text('Snippet mới'),
      ),
    );
  }
}

class _SnippetTile extends ConsumerWidget {
  final Snippet snippet;
  final String? folderName;
  const _SnippetTile({required this.snippet, this.folderName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      onTap: () async {
        await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    SnippetEditScreen(existing: snippet)));
        ref.read(snippetListProvider.notifier).reload();
      },
      title: Text(snippet.title),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(snippet.fullTrigger,
                style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color:
                        Theme.of(context).colorScheme.onSecondaryContainer)),
          ),
          if (folderName != null) ...[
            const SizedBox(width: 8),
            Icon(Icons.folder, size: 12,
                color: Theme.of(context).colorScheme.outline),
            Text(' $folderName', style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(width: 8),
          Icon(Icons.touch_app, size: 12,
              color: Theme.of(context).colorScheme.outline),
          Text(' ${snippet.usageCount}',
              style: Theme.of(context).textTheme.bodySmall),
        ]),
        Text(snippet.content,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall),
      ]),
      trailing: Switch(
        value: snippet.isEnabled,
        onChanged: (_) =>
            ref.read(snippetListProvider.notifier).toggleEnabled(snippet),
      ),
    );
  }
}
