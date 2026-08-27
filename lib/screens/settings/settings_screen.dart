import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_limits.dart';
import '../../generated/l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(appSettingsProvider);
    final currentLocale = ref.watch(localeProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(children: [
        // ---------------- Capture & dữ liệu ----------------
        _SectionHeader(l10n.settingsCaptureSection),
        SwitchListTile(
          secondary: const Icon(Icons.pause_circle_outline),
          title: Text(l10n.settingsPauseLogging),
          subtitle: Text(l10n.clipboardPauseSubtitle),
          value: settings.capturePaused,
          onChanged: (v) =>
              ref.read(appSettingsProvider.notifier).setCapturePaused(v),
        ),
        ListTile(
          leading: const Icon(Icons.timer_outlined),
          title: Text(l10n.clipboardAutoDelete),
          subtitle: Text(l10n.clipboardAutoDeleteSubtitle),
          trailing: DropdownButton<int>(
            value: settings.expirationDays,
            items: AppLimits.expirationOptionsDays
                .map((d) => DropdownMenuItem(
                    value: d, child: Text('$d ${l10n.clipboardAutoDelete}')))
                .toList(),
            onChanged: (d) {
              if (d != null) {
                ref.read(appSettingsProvider.notifier).setExpirationDays(d);
              }
            },
          ),
        ),

        // ---------------- Bảo mật ----------------
        _SectionHeader(l10n.settingsSecuritySection),
        SwitchListTile(
          secondary: const Icon(Icons.fingerprint),
          title: Text(l10n.settingsBiometricLock),
          subtitle: Text(l10n.settingsBiometricSubtitle),
          value: settings.biometricLock,
          onChanged: (v) async {
            if (v) {
              final canAuth =
                  await ref.read(authServiceProvider).canAuthenticate;
              if (!canAuth && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(l10n.settingsBiometricNotSupported)));
                return;
              }
            }
            await ref.read(appSettingsProvider.notifier).setBiometricLock(v);
          },
        ),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: Text(l10n.settingsSensitiveDetection,
              style: const TextStyle(fontSize: 14)),
          subtitle: Text(l10n.settingsSensitiveSubtitle,
              style: const TextStyle(fontSize: 12)),
        ),

        // ---------------- Backup / Restore ----------------
        _SectionHeader(l10n.settingsBackupSection),
        ListTile(
          leading: const Icon(Icons.lock),
          title: Text(l10n.settingsExportBackup),
          subtitle: Text(l10n.settingsExportSubtitle),
          onTap: () => _exportDialog(),
        ),
        ListTile(
          leading: const Icon(Icons.restore),
          title: Text(l10n.settingsRestoreBackup),
          onTap: () => _restoreDialog(),
        ),

        // ---------------- Language ----------------
        _SectionHeader(l10n.appLanguage),
        ListTile(
          leading: const Icon(Icons.language),
          title: Text(l10n.appLanguage),
          subtitle: Text(l10n.appLanguageSubtitle),
          trailing: DropdownButton<Locale?>(
            value: currentLocale,
            items: [
              DropdownMenuItem<Locale?>(
                value: null,
                child: Text('🌐 System'),
              ),
              DropdownMenuItem<Locale?>(
                value: const Locale('vi'),
                child: Text(l10n.langVietnamese),
              ),
              DropdownMenuItem<Locale?>(
                value: const Locale('en'),
                child: Text(l10n.langEnglish),
              ),
            ],
            onChanged: (locale) {
              ref.read(localeProvider.notifier).setLocale(locale);
            },
          ),
        ),

        // ---------------- Metrics local-only ----------------
        _SectionHeader(l10n.settingsStatsSection),
        _MetricsSummary(onRefresh: () => setState(() {})),

        const SizedBox(height: 16),
      ]),
    );
  }

  Future<void> _exportDialog() async {
    final l10n = AppLocalizations.of(context);
    final passController = TextEditingController();
    final confirmed = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.exportDialogPassphraseTitle),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: passController,
            obscureText: true,
            autofocus: true,
            decoration: InputDecoration(labelText: l10n.exportDialogPassphraseLabel),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.exportDialogPassphraseWarning,
            style: const TextStyle(fontSize: 12),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(l10n.btnCancel)),
          FilledButton(
            onPressed: () {
              if (passController.text.length < 8) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text(l10n.exportPassphraseTooShort)),
                );
                return;
              }
              Navigator.pop(ctx, passController.text);
            },
            child: Text(l10n.btnExport),
          ),
        ],
      ),
    );

    if (confirmed == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final path = await ref.read(backupServiceProvider).exportTo(confirmed);
      messenger.showSnackBar(SnackBar(
          content: Text(l10n.exportSuccess(path)),
          duration: const Duration(seconds: 6)));
    } on BackupException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.exportFailed)));
    }
  }

  Future<void> _restoreDialog() async {
    final l10n = AppLocalizations.of(context);
    final passController = TextEditingController();
    final pathController = TextEditingController();
    showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.restoreDialogTitle),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: pathController,
            decoration: InputDecoration(
                labelText: l10n.restoreDialogPathLabel,
                helperText: l10n.restoreDialogPathHelper),
          ),
          TextField(
            controller: passController,
            obscureText: true,
            decoration: InputDecoration(labelText: l10n.restoreDialogPassphraseLabel),
          ),
          const SizedBox(height: 8),
          Text(l10n.restoreDialogWarning,
              style: const TextStyle(fontSize: 12)),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(l10n.btnCancel)),
          FilledButton(
            onPressed: () {
              if (pathController.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text(l10n.restorePathEmpty)),
                );
                return;
              }
              Navigator.pop(ctx,
                  [pathController.text.trim(), passController.text]);
            },
            child: Text(l10n.btnRestore),
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
        await ref.read(cacheSyncProvider).regenerateSnippetCache();
        await ref.read(clipboardListProvider.notifier).reload();
        await ref.read(snippetListProvider.notifier).reload();
        await ref.read(folderListProvider.notifier).reload();
        messenger.showSnackBar(SnackBar(content: Text(l10n.restoreSuccess)));
      } on BackupException catch (e) {
        messenger.showSnackBar(SnackBar(content: Text(e.message)));
      } catch (_) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.restoreFailed)));
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

class _MetricsSummary extends ConsumerWidget {
  final VoidCallback? onRefresh;
  const _MetricsSummary({this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
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
                  _chip(ctx, l10n.statsSnippetsCreated,
                      '${s[MetricsService.kSnippetsCreated] ?? 0}'),
                  _chip(ctx, l10n.statsExpansions, '$expansions'),
                  _chip(ctx, l10n.statsClipboardSaved,
                      '${s[MetricsService.kClipboardItemsSaved] ?? 0}'),
                  _chip(ctx, l10n.statsClipboardReused,
                      '${s[MetricsService.kClipboardItemsReused] ?? 0}'),
                  _chip(ctx, l10n.statsPlaygroundExpansions,
                      '${s[MetricsService.kPlaygroundExpansions] ?? 0}'),
                  _chip(ctx, l10n.statsActiveDays, '$days'),
                ]),
                const SizedBox(height: 8),
                Text(l10n.statsPerDay(perDay),
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
