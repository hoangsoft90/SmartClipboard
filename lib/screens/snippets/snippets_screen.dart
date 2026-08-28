import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../generated/l10n/app_localizations.dart';
import '../../models/snippet.dart';
import '../../state/providers.dart';
import '../../widgets/save_snippet_dialog.dart';
import 'folders_screen.dart';
import 'snippet_edit_screen.dart';

class SnippetsScreen extends ConsumerWidget {
  const SnippetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final listAsync = ref.watch(snippetListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.snippetsTitle),
        // FIX 3.1: Thêm nút truy cập FoldersScreen
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_outlined),
            tooltip: l10n.foldersTitle,
            onPressed: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const FoldersScreen()));
            },
          ),
        ],
      ),
      body: listAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.clipboardLoadError)),
        data: (items) => items.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(l10n.snippetsEmpty,
                      textAlign: TextAlign.center),
                ))
            : ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) =>
                    _SnippetTile(snippet: items[i]),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'snippet_fab',
        onPressed: () {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SnippetEditScreen()));
        },
        label: Text(l10n.snippetsNew),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

class _SnippetTile extends ConsumerWidget {
  final Snippet snippet;
  const _SnippetTile({required this.snippet});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      leading: Icon(
        snippet.isEnabled ? Icons.bolt : Icons.bolt_outlined,
        color: snippet.isEnabled
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.outline,
      ),
      title: Text(snippet.title),
      subtitle: Text(';${snippet.trigger}',
          style: TextStyle(
              fontFamily: 'monospace',
              color: Theme.of(context).colorScheme.outline)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (snippet.usageCount > 0)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text('${snippet.usageCount}',
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.outline)),
          ),
        PopupMenuButton<String>(
          onSelected: (action) async {
            final ctrl = ref.read(snippetListProvider.notifier);
            switch (action) {
              case 'toggle':
                await ctrl.toggleEnabled(snippet);
              case 'edit':
                if (context.mounted) {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => SnippetEditScreen(
                              snippetId: snippet.id)));
                }
              case 'delete':
                await ctrl.archive(snippet.id);
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
                value: 'toggle',
                child: Text(snippet.isEnabled
                    ? l10n.snippetDisable
                    : l10n.snippetEnable)),
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(
                value: 'delete', child: Text(l10n.btnDelete)),
          ],
        ),
      ]),
    );
  }
}
