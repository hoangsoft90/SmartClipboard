import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/clipboard_item.dart';
import '../../services/privacy_service.dart';
import '../../state/providers.dart';
import '../../widgets/privacy_banner.dart';
import '../../widgets/pro_upgrade_banner.dart';
import '../../widgets/save_snippet_dialog.dart';

/// Clipboard History UI — P0.
/// Foreground capture nằm ở HomeScreen (resume); Incognito toggle ở AppBar.
class ClipboardHistoryScreen extends ConsumerWidget {
  const ClipboardHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(clipboardListProvider);
    final settings = ref.watch(appSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử Clipboard'),
        actions: [
          // Incognito / Pause Mode — P0 bắt buộc (mục 5.2): toggle 1 chạm.
          IconButton(
            tooltip: settings.capturePaused
                ? 'Bỏ tạm dừng ghi lịch sử'
                : 'Tạm dừng ghi lịch sử (Incognito)',
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
            child: const ListTile(
              dense: true,
              leading: Icon(Icons.visibility_off),
              title: Text('ĐANG TẠM DỪNG ghi lịch sử clipboard',
                  style: TextStyle(fontSize: 13)),
            ),
          ),
        const ProUpgradeBanner(),
        Expanded(
          child: listAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Lỗi tải dữ liệu')),
            data: (items) => items.isEmpty
                ? const Center(
                    child: Text(
                        'Chưa có nội dung nào.\nSwitch sang app khác rồi quay lại '
                        'để lưu clipboard.',
                        textAlign: TextAlign.center))
                : RefreshIndicator(
                    onRefresh: () async {
                      await ref.read(clipboardListProvider.notifier).reload();
                    },
                    child: ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1),
                      itemBuilder: (ctx, i) => _ItemTile(item: items[i]),
                    ),
                  ),
          ),
        ),
      ]),
    );
  }
}

class _ItemTile extends ConsumerWidget {
  final ClipboardItem item;
  const _ItemTile({required this.item});

  String _timeAgo() {
    final diff =
        DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(
            item.updatedAt));
    if (diff.inMinutes < 1) return 'vừa xong';
    if (diff.inHours < 1) return '${diff.inMinutes} phút trước';
    if (diff.inDays < 1) return '${diff.inHours} giờ trước';
    return '${diff.inDays} ngày trước';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: () async {
        await ref.read(clipboardServiceProvider).copyToSystem(item);
        await ref.read(clipboardListProvider.notifier).reload();
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Đã copy')));
        }
      },
      title: Text(
        item.content,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Row(children: [
        Text(_timeAgo(), style: theme.textTheme.bodySmall),
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
      trailing: PopupMenuButton<String>(
        onSelected: (action) async {
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
              // Xoá vật lý CHỈ khi user chủ động chọn.
              await controller.deleteForever(item.id);
            case 'expiration':
              await _suggest24hExpiry(ref);
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'pin',
            child: Text(item.isPinned ? 'Bỏ ghim' : 'Ghim'),
          ),
          PopupMenuItem(
            value: 'favorite',
            child: Text(item.isFavorite ? 'Bỏ yêu thích' : 'Yêu thích'),
          ),
          const PopupMenuItem(value: 'copy', child: Text('Copy lại')),
          const PopupMenuItem(value: 'snippet', child: Text('Lưu thành Snippet')),
          if (item.privacyRiskScore >= 1)
            const PopupMenuItem(
                value: 'expiration', child: Text('Xoá sau 24h ⚠️ heuristic')),
          const PopupMenuItem(value: 'archive', child: Text('Ẩn khỏi lịch sử')),
          const PopupMenuItem(value: 'delete', child: Text('Xoá vĩnh viễn')),
        ],
      ),
    );
  }

  Future<void> _suggest24hExpiry(WidgetRef ref) async {
    // Banner mục 5.1: gợi ý tự xoá sau 24h cho item nghi vấn nhạy cảm.
    await ref.read(clipboardRepoProvider).setExpiry(
        item.id, PrivacyService.suggestedExpiryForSuspect(
            DateTime.now().millisecondsSinceEpoch));
    await ref.read(clipboardListProvider.notifier).reload();
  }
}

/// Badge hiển thị privacy_risk_score — HEURISTIC ONLY (mục 5.1, Rule 9).
/// Tooltip luôn kèm disclaimer "dự đoán heuristic".
class _RiskBadge extends StatelessWidget {
  final int score;
  const _RiskBadge({required this.score});

  @override
  Widget build(BuildContext context) {
    if (score < 1) return const SizedBox(width: 4);
    return PrivacyRiskBadge(score: score);
  }
}
