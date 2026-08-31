import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../generated/l10n/app_localizations.dart';
import '../../models/clipboard_item.dart';
import '../../services/privacy_service.dart';
import '../../state/providers.dart';
import '../../widgets/privacy_banner.dart';
import '../../widgets/pro_upgrade_banner.dart';
import '../../widgets/save_snippet_dialog.dart';

class ClipboardHistoryScreen extends ConsumerWidget {
  const ClipboardHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final listAsync = ref.watch(clipboardListProvider);
    final settings = ref.watch(appSettingsProvider);
    final visibleItems = ref.watch(visibleClipboardItemsProvider);
    final filter = ref.watch(clipboardFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.clipboardHistoryTitle),
        actions: [
          IconButton(
            tooltip: settings.capturePaused
                ? l10n.clipboardPauseResumeTooltip
                : l10n.clipboardPauseTooltip,
            icon: Icon(settings.capturePaused
                ? Icons.pause_circle
                : Icons.pause_circle_outline),
            onPressed: () => ref
                .read(appSettingsProvider.notifier)
                .setCapturePaused(!settings.capturePaused),
          ),
        ],
      ),
      body: Column(children: [
        if (settings.capturePaused)
          Material(
            color: Theme.of(context).colorScheme.errorContainer,
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.visibility_off),
              title: Text(l10n.clipboardPaused,
                  style: const TextStyle(fontSize: 13)),
            ),
          ),
        const ProUpgradeBanner(),
        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: _ClipboardSearchBar(
            initialQuery: filter.query,
            onChanged: (value) {
              ref.read(clipboardFilterProvider.notifier).state =
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
                  selected: !filter.favoriteOnly && !filter.pinnedOnly,
                  onSelected: (_) => ref
                      .read(clipboardFilterProvider.notifier)
                      .state = filter.copyWith(
                          favoriteOnly: false, pinnedOnly: false),
                ),
                ChoiceChip(
                  label: Text(l10n.filterFavorites),
                  selected: filter.favoriteOnly,
                  onSelected: (v) => ref
                      .read(clipboardFilterProvider.notifier)
                      .state = filter.copyWith(favoriteOnly: v),
                ),
                ChoiceChip(
                  label: Text(l10n.filterPinned),
                  selected: filter.pinnedOnly,
                  onSelected: (v) => ref
                      .read(clipboardFilterProvider.notifier)
                      .state = filter.copyWith(pinnedOnly: v),
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
                    child: Text(l10n.clipboardEmpty,
                        textAlign: TextAlign.center))
                : RefreshIndicator(
                    onRefresh: () async {
                      await ref.read(clipboardListProvider.notifier).reload();
                    },
                    child: ListView.separated(
                      itemCount: visibleItems.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1),
                      itemBuilder: (ctx, i) =>
                          _ItemTile(item: visibleItems[i]),
                    ),
                  ),
          ),
        ),
      ]),
    );
  }
}

class _ClipboardSearchBar extends StatefulWidget {
  final String initialQuery;
  final ValueChanged<String> onChanged;
  const _ClipboardSearchBar({required this.initialQuery, required this.onChanged});

  @override
  State<_ClipboardSearchBar> createState() => _ClipboardSearchBarState();
}

class _ClipboardSearchBarState extends State<_ClipboardSearchBar> {
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
        hintText: l10n.searchClipboardHint,
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

class _ItemTile extends ConsumerWidget {
  final ClipboardItem item;
  const _ItemTile({required this.item});

  String _timeAgo(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final diff =
        DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(
            item.updatedAt));
    if (diff.inMinutes < 1) return l10n.timeAgoJustNow;
    if (diff.inHours < 1) return l10n.timeAgoMinutes(diff.inMinutes);
    if (diff.inDays < 1) return l10n.timeAgoHours(diff.inHours);
    return l10n.timeAgoDays(diff.inDays);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return ListTile(
      onTap: () async {
        await ref.read(clipboardServiceProvider).copyToSystem(item);
        await ref.read(clipboardListProvider.notifier).reload();
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(l10n.clipboardCopied)));
        }
      },
      title: Text(
        item.content,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Row(children: [
        Text(_timeAgo(context), style: theme.textTheme.bodySmall),
        if (item.copyCount > 1) ...[
          const SizedBox(width: 8),
          Icon(Icons.repeat, size: 12, color: theme.colorScheme.outline),
          Text(' ${item.copyCount}', style: theme.textTheme.bodySmall),
        ],
        if (item.contentType != 'text') ...[
          const SizedBox(width: 8),
          Text(item.contentType, style: theme.textTheme.bodySmall),
        ],
      ]),
      leading: _RiskBadge(score: item.privacyRiskScore),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(
              item.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
              size: 20,
              color: item.isPinned ? theme.colorScheme.primary : null,
            ),
            tooltip: item.isPinned ? l10n.popupUnpin : l10n.popupPin,
            onPressed: () {
              FocusManager.instance.primaryFocus?.unfocus();
              ref.read(clipboardListProvider.notifier).togglePin(item);
            },
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(
              item.isFavorite ? Icons.star : Icons.star_border,
              size: 20,
              color: item.isFavorite ? Colors.amber : null,
            ),
            tooltip: item.isFavorite ? l10n.popupUnfavorite : l10n.popupFavorite,
            onPressed: () {
              FocusManager.instance.primaryFocus?.unfocus();
              ref.read(clipboardListProvider.notifier).toggleFavorite(item);
            },
          ),
          PopupMenuButton<String>(
            onSelected: (action) async {
              // PLAN 11 P0-1: Unfocus before any action to prevent IME re-trigger
              FocusManager.instance.primaryFocus?.unfocus();
              final controller = ref.read(clipboardListProvider.notifier);
              switch (action) {
                case 'pin':
                  await controller.togglePin(item);
                case 'favorite':
                  await controller.toggleFavorite(item);
                case 'copy':
                  await ref.read(clipboardServiceProvider).copyToSystem(item);
                  await controller.reload();
                case 'snippet':
                  if (context.mounted) {
                    await showSaveSnippetDialog(context, ref,
                        initialContent: item.content);
                  }
                case 'archive':
                  await controller.archiveItem(item.id);
                case 'delete':
                  await controller.deleteForever(item.id);
                case 'expiration':
                  await _suggest24hExpiry(ref);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'pin',
                child: Text(item.isPinned ? l10n.popupUnpin : l10n.popupPin),
              ),
              PopupMenuItem(
                value: 'favorite',
                child: Text(item.isFavorite ? l10n.popupUnfavorite : l10n.popupFavorite),
              ),
              PopupMenuItem(value: 'copy', child: Text(l10n.popupCopyAgain)),
              PopupMenuItem(value: 'snippet', child: Text(l10n.popupSaveAsSnippet)),
              if (item.privacyRiskScore >= 1)
                PopupMenuItem(
                    value: 'expiration', child: Text(l10n.popupDeleteAfter24h)),
              PopupMenuItem(value: 'archive', child: Text(l10n.popupHideFromHistory)),
              PopupMenuItem(value: 'delete', child: Text(l10n.popupDeletePermanently)),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _suggest24hExpiry(WidgetRef ref) async {
    await ref.read(clipboardRepoProvider).setExpiry(
        item.id, PrivacyService.suggestedExpiryForSuspect(
            DateTime.now().millisecondsSinceEpoch));
    await ref.read(clipboardListProvider.notifier).reload();
  }
}

class _RiskBadge extends StatelessWidget {
  final int score;
  const _RiskBadge({required this.score});

  @override
  Widget build(BuildContext context) {
    if (score < 1) return const SizedBox(width: 4);
    return PrivacyRiskBadge(score: score);
  }
}
