import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_limits.dart';
import '../../services/backup_service.dart';
import '../../services/cache_sync_service.dart';
import '../../services/metrics_service.dart';
import '../../state/providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: ListView(children: [
        // ---------------- Capture & dữ liệu ----------------
        const _SectionHeader('Ghi lịch sử'),
        SwitchListTile(
          secondary: const Icon(Icons.pause_circle_outline),
          title: const Text('Tạm dừng ghi Clipboard History'),
          subtitle: const Text(
              'Incognito/Pause Mode — tạm dừng 1 chạm, không nghe lén nền'),
          value: settings.capturePaused,
          onChanged: (v) =>
              ref.read(appSettingsProvider.notifier).setCapturePaused(v),
        ),
        ListTile(
          leading: const Icon(Icons.timer_outlined),
          title: const Text('Tự xoá lịch sử sau'),
          subtitle: const Text('Auto-Expiration Engine (1/7/30 ngày)'),
          trailing: DropdownButton<int>(
            value: settings.expirationDays,
            items: AppLimits.expirationOptionsDays
                .map((d) => DropdownMenuItem(
                    value: d, child: Text('$d ngày')))
                .toList(),
            onChanged: (d) {
              if (d != null) {
                ref.read(appSettingsProvider.notifier).setExpirationDays(d);
              }
            },
          ),
        ),

        // ---------------- Bảo mật ----------------
        const _SectionHeader('Bảo mật'),
        SwitchListTile(
          secondary: const Icon(Icons.fingerprint),
          title: const Text('Khoá app bằng sinh trắc học'),
          subtitle: const Text('Vân tay/khuôn mặt — miễn phí bản Free'),
          value: settings.biometricLock,
          onChanged: (v) async {
            if (v) {
              final canAuth =
                  await ref.read(authServiceProvider).canAuthenticate;
              if (!canAuth && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text(
                        'Thiết bị không hỗ trợ sinh trắc học hoặc chưa cài đặt')));
                return;
              }
            }
            await ref.read(appSettingsProvider.notifier).setBiometricLock(v);
          },
        ),
        const ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('Phát hiện dữ liệu nhạy cảm', style: TextStyle(
              fontSize: 14)),
          subtitle: Text(
              '⚠️ CHỈ LÀ heuristic (regex + entropy) để GỢI Ý — KHÔNG PHẢI '
              'bảo đảm bảo mật tuyệt đối. Entropy cao có thể chỉ là random ID.',
              style: TextStyle(fontSize: 12)),
        ),

        // ---------------- Backup / Restore ----------------
        const _SectionHeader('Sao lưu & Khôi phục'),
        ListTile(
          leading: const Icon(Icons.lock),
          title: const Text('Export backup mã hoá (AES-256-GCM)'),
          subtitle: const Text(
              'Khóa derive từ passphrase của bạn qua PBKDF2 '
              '(≥100k lần lặp). Hãy nhớ passphrase — không ai khôi phục được '
              'nếu quên!'),
          onTap: () => _exportDialog(),
        ),
        ListTile(
          leading: const Icon(Icons.restore),
          title: const Text('Restore từ file backup'),
          onTap: () => _restoreDialog(),
        ),

        // ---------------- Metrics local-only ----------------
        const _SectionHeader('Thống kê (chỉ lưu trên máy)'),
        _MetricsSummary(onRefresh: () => setState(() {})),

        const SizedBox(height: 16),
      ]),
    );
  }

  Future<void> _exportDialog() async {
    final passController = TextEditingController();
    final confirmed = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nhập passphrase cho backup'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: passController,
            obscureText: true,
            autofocus: true,
            decoration:
                const InputDecoration(labelText: 'Passphrase (tự chọn)'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Key mã hoá được tạo từ passphrase này. QUÊN PASSPHRASE = '
            'KHÔNG THỂ RESTORE. Salt + nonce ngẫu nhiên được lưu trong file.',
            style: TextStyle(fontSize: 12),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
          FilledButton(
            onPressed: () {
              if (passController.text.length < 8) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Passphrase phải có ít nhất 8 ký tự.'),
                  ),
                );
                return;
              }
              Navigator.pop(ctx, passController.text);
            },
            child: const Text('Export'),
          ),
        ],
      ),
    );

    if (confirmed == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final path = await ref.read(backupServiceProvider).exportTo(confirmed);
      messenger.showSnackBar(SnackBar(
          content: Text('Đã export: $path'), duration:
              const Duration(seconds: 6)));
    } on BackupException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Export thất bại. Vui lòng thử lại.')));
    }
  }

  Future<void> _restoreDialog() async {
    final passController = TextEditingController();
    final pathController = TextEditingController();
    showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore từ backup'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: pathController,
            decoration: const InputDecoration(
                labelText: 'Đường dẫn file .scbak',
                helperText:
                    'Vd: /data/user/0/.../files/smart_clipboard_backup_....scbak'),
          ),
          TextField(
            controller: passController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Passphrase'),
          ),
          const SizedBox(height: 8),
          const Text(
              '⚠️ Restore sẽ THAY THẾ toàn bộ data hiện tại trong app.',
              style: TextStyle(fontSize: 12)),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
          FilledButton(
            onPressed: () {
              if (pathController.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Vui lòng nhập đường dẫn file backup.'),
                  ),
                );
                return;
              }
              Navigator.pop(ctx,
                  [pathController.text.trim(), passController.text]);
            },
            child: const Text('Restore'),
          ),
        ],
      ),
    ).then((combined) async {
      if (combined == null || !mounted) return;
      final parts = combined as List<String>?;
      if (parts == null || parts.length != 2 || parts[0].isEmpty) return;

      final messenger = ScaffoldMessenger.of(context);
      try {
        await ref
            .read(backupServiceProvider)
            .restoreFrom(parts[0], parts[1]);
        // STRICT RULE 13: sau restore (= CRUD hàng loạt) phải regenerate cache.
        await ref.read(cacheSyncProvider).regenerateSnippetCache();
        await ref.read(clipboardListProvider.notifier).reload();
        await ref.read(snippetListProvider.notifier).reload();
        await ref.read(folderListProvider.notifier).reload();
        messenger.showSnackBar(
            const SnackBar(content: Text('Restore thành công!')));
      } on BackupException catch (e) {
        messenger.showSnackBar(SnackBar(content: Text(e.message)));
      } catch (_) {
        messenger.showSnackBar(const SnackBar(
            content: Text('Restore thất bại. Kiểm tra lại file/passphrase.')));
      }
    });
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(title.toUpperCase(),
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary)),
    );
  }
}

/// Local-only metrics summary (mục 10) — hiển thị số liệu vô hại, không chứa
/// bất kỳ nội dung text nào của user (STRICT RULE 7).
class _MetricsSummary extends ConsumerWidget {
  final VoidCallback? onRefresh;
  const _MetricsSummary({this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<Map<String, int>>(
      future: ref.read(metricsProvider).summary(),
      builder: (ctx, snap) {
        final s = snap.data ?? {};
        final days = s[MetricsService.kDaysActive] ?? 0;
        final expansions = s[MetricsService.kExpansionCount] ?? 0;
        final perDay = days > 0 ? (expansions / days).toStringAsFixed(2) : '0';
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _chip(ctx, 'Snippets đã tạo',
                      '${s[MetricsService.kSnippetsCreated] ?? 0}'),
                  _chip(ctx, 'Lần mở rộng', '$expansions'),
                  _chip(ctx, 'Clipboard đã lưu',
                      '${s[MetricsService.kClipboardItemsSaved] ?? 0}'),
                  _chip(ctx, 'Clipboard tái dùng',
                      '${s[MetricsService.kClipboardItemsReused] ?? 0}'),
                  _chip(ctx, 'Playground expansions',
                      '${s[MetricsService.kPlaygroundExpansions] ?? 0}'),
                  _chip(ctx, 'Ngày active', '$days'),
                ]),
                const SizedBox(height: 8),
                Text(
                  'Mở rộng / ngày active: $perDay\n'
                  '≥ 1 → thói quen dùng Text Expander đã hình thành '
                  '(tiêu chí Go Phase 1 — mục 10 spec)',
                  style: Theme.of(context).textTheme.bodySmall),
              ]),
        );
      },
    );
  }

  Widget _chip(BuildContext ctx, String label, String value) => Chip(
        avatar: Text(value,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(ctx).colorScheme.primary)),
        label: Text(label, style: const TextStyle(fontSize: 11)),
        visualDensity: VisualDensity.compact,
      );
}
