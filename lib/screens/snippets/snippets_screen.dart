import 'dart:async';

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
    final visibleItems = ref.watch(visibleSnippetsProvider);
    final filter = ref.watch(snippetFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.snippetsTitle),
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
      body: Column(children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: _SnippetSearchBar(
            initialQuery: filter.query,
            onChanged: (value) {
              ref.read(snippetFilterProvider.notifier).state =
                  filter.copyWith(query: value);
            },
          ),
        ),
        // Filter chips
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: Text(l10n.filterAll),
                  selected: filter.mode == SnippetFilterMode.all,
                  onSelected: (_) => ref
                      .read(snippetFilterProvider.notifier)
                      .state = filter.copyWith(mode: SnippetFilterMode.all),
                ),
                ChoiceChip(
                  label: Text(l10n.filterEnabled),
                  selected: filter.mode == SnippetFilterMode.enabled,
                  onSelected: (_) => ref
                      .read(snippetFilterProvider.notifier)
                      .state = filter.copyWith(mode: SnippetFilterMode.enabled),
                ),
                ChoiceChip(
                  label: Text(l10n.filterDisabled),
                  selected: filter.mode == SnippetFilterMode.disabled,
                  onSelected: (_) => ref
                      .read(snippetFilterProvider.notifier)
                      .state = filter.copyWith(mode: SnippetFilterMode.disabled),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: listAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(l10n.clipboardLoadError)),
            data: (_) => visibleItems.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(l10n.snippetsEmpty,
                          textAlign: TextAlign.center),
                    ))
                : ListView.separated(
                    itemCount: visibleItems.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) =>
                        _SnippetTile(snippet: visibleItems[i]),
                  ),
          ),
        ),
      ]),
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

class _SnippetSearchBar extends StatefulWidget {
  final String initialQuery;
  final ValueChanged<String> onChanged;
  const _SnippetSearchBar({required this.initialQuery, required this.onChanged});

  @override
  State<_SnippetSearchBar> createState() => _SnippetSearchBarState();
}

class _SnippetSearchBarState extends State<_SnippetSearchBar> {
  Timer? _debounce;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TextField(
      controller: _controller,
      decoration: InputDecoration(
        hintText: l10n.searchSnippetsHint,
        prefixIcon: const Icon(Icons.search),
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onChanged: (value) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 300), () {
          widget.onChanged(value);
        });
      },
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
