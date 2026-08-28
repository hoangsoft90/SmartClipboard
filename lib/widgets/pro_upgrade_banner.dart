import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../generated/l10n/app_localizations.dart';
import '../state/providers.dart';

class ProUpgradeBanner extends ConsumerWidget {
  const ProUpgradeBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
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
            // FIX 3.3: Hiển thị rõ ràng hơn lý do items bị ẩn
            title: Text(
              '$total mục đã bị ẩn tự động',
              style: const TextStyle(fontSize: 13),
            ),
            subtitle: Text(
              'Giới hạn bản Free: 50 clipboard + 15 snippet. '
              'Dữ liệu được giữ an toàn, nâng cấp Pro để mở khoá.',
              style: const TextStyle(fontSize: 11),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(l10n.proUpgradeTitle),
                content: Text(
                  'Bản Free giữ tối đa 50 mục clipboard và 15 snippet đang '
                  'hoạt động. $total mục cũ hơn vẫn được GIỮ AN TOÀN trong '
                  'app (không bị xoá) và sẽ được mở khoá đầy đủ khi nâng cấp '
                  'Pro.\n\nMua Pro qua Google Play (sắp ra mắt).',
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(l10n.btnLater)),
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
