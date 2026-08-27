import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';

/// Banner "Nâng cấp Pro để mở khoá X mục đã lưu" — soft-delete free limit
/// (mục 9): item vượt ngưỡng KHÔNG bị xoá vật lý, chỉ `is_archived=1` và ẩn
/// khỏi UI. Khi mua Pro → restore toàn bộ ngay lập tức (STRICT RULE 17).
///
/// Phase 0: banner hiển thị số mục bị ẩn; luồng IAP thật (`in_app_purchase`)
/// wire-up ở phase IAP — bấm banner hiện dialog giải thích.
class ProUpgradeBanner extends ConsumerWidget {
  const ProUpgradeBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archivedAsync = ref.watch(archivedClipboardCountProvider);
    final snippetArchived = ref.watch(snippetArchivedCountProvider);

    return archivedAsync.maybeWhen(
      data: (count) {
        final snippetCount = snippetArchived.value ?? 0;
        final total = count + snippetCount;
        if (total <= 0) return const SizedBox.shrink();
        return Material(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.workspace_premium),
            title: Text(
              '$total mục đang bị ẩn do giới hạn bản Free',
              style: const TextStyle(fontSize: 13),
            ),
            subtitle: const Text('Nâng cấp Pro để mở khoá toàn bộ',
                style: TextStyle(fontSize: 11)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Smart Clipboard Pro'),
                content: Text(
                  'Bản Free giữ tối đa 50 mục clipboard và 15 snippet đang '
                  'hoạt động. $total mục cũ hơn vẫn được GIỮ AN TOÀN trong '
                  'app (không bị xoá) và sẽ được mở khoá đầy đủ khi nâng cấp '
                  'Pro.\n\nMua Pro qua Google Play (sắp ra mắt).',
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Để sau')),
                ],
              ),
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
