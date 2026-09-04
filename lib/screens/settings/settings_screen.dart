import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_limits.dart';
import '../../generated/l10n/app_localizations.dart';
import '../../services/backup_service.dart';
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
                    value: d, child: Text(l10n.clipboardAutoDeleteOption(d))))
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

        // ---------------- Pro (Rewarded Ad) ----------------
        _SectionHeader(l10n.settingsProSection),
        _ProStatusSection(),

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
                child: Text('🌐 ${l10n.langSystem}'),
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

        // ---------------- Appearance > Theme ----------------
        _SectionHeader(l10n.settingsAppearanceSection),
        _ThemeModePicker(),

        // ---------------- PLAN 7 P1-5: Keyboard background color ----------------
        _SectionHeader(l10n.settingsKeyboardBgColor),
        _KeyboardBgColorPicker(
          currentColor: settings.keyboardBgColor,
          onColorSelected: (hex) {
            ref.read(appSettingsProvider.notifier).setKeyboardBgColor(hex);
          },
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
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ExportRestoreDialog(
        l10n: l10n,
        passController: passController,
        onExport: (passphrase) async {
          try {
            final path =
                await ref.read(backupServiceProvider).exportTo(passphrase);
            // FIX 3.2: Mở Share Sheet để user lưu file ra chỗ tùy chọn
            await ref.read(nativeBridgeProvider).shareFile(path);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(l10n.exportSuccess(path)),
                  duration: const Duration(seconds: 6)));
            }
            return null; // success
          } on BackupException catch (e) {
            return _backupErrorMessage(l10n, e);
          } catch (_) {
            return l10n.exportFailed;
          }
        },
      ),
    );
  }

  Future<void> _restoreDialog() async {
    final l10n = AppLocalizations.of(context);
    if (!mounted) return;

    // FIX 3.2: Mở SAF File Picker trước khi hiện dialog
    final pickedPath = await ref.read(nativeBridgeProvider).pickBackupFile();
    if (pickedPath == null) return; // User hủy

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _RestoreBackupDialog(
        l10n: l10n,
        initialPath: pickedPath, // FIX 3.2: Điền sẵn path từ file picker
        onRestore: (path, passphrase) async {
          try {
            await ref.read(backupServiceProvider).restoreFrom(path, passphrase);
            await ref.read(cacheSyncProvider).regenerateSnippetCache();
            await ref.read(clipboardListProvider.notifier).reload();
            await ref.read(snippetListProvider.notifier).reload();
            await ref.read(folderListProvider.notifier).reload();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.restoreSuccess)));
            }
            return null; // success
          } on BackupException catch (e) {
            return _backupErrorMessage(l10n, e);
          } catch (_) {
            return l10n.restoreFailed;
          }
        },
      ),
    );
  }
}

class _KeyboardBgColorPicker extends StatelessWidget {
  final String currentColor;
  final ValueChanged<String> onColorSelected;

  const _KeyboardBgColorPicker({
    required this.currentColor,
    required this.onColorSelected,
  });

  // PLAN 7 P1-5: Preset colors — no color-picker package needed
  static const presets = [
    '#FFFFFF',
    '#E0E0E0',
    '#D6E4FF',
    '#1C1C1E',
  ];

  String _label(String hex, AppLocalizations l10n) {
    return switch (hex) {
      '#FFFFFF' => l10n.colorWhite,
      '#E0E0E0' => l10n.colorGray,
      '#D6E4FF' => l10n.colorBlue,
      _ => l10n.colorBlack,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: presets.map((hex) {
          final selected = currentColor.toUpperCase() == hex.toUpperCase();
          final color = Color(int.parse('FF${hex.substring(1)}', radix: 16));
          final isDark = (0.299 * color.red + 0.587 * color.green + 0.114 * color.blue) / 255 < 0.5;
          return GestureDetector(
            onTap: () => onColorSelected(hex),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected ? Theme.of(context).colorScheme.primary : Colors.grey.shade400,
                  width: selected ? 3 : 1,
                ),
              ),
              child: Center(
                child: Text(
                  _label(hex, l10n),
                  style: TextStyle(
                    fontSize: 9,
                    color: isDark ? Colors.white : Colors.black,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Map BackupErrorCode → chuỗi đã localize (l10n).
String _backupErrorMessage(AppLocalizations l10n, BackupException e) {
  return switch (e.code) {
    BackupErrorCode.webUnsupported => l10n.backupErrorWebUnsupported,
    BackupErrorCode.fileNotFound => l10n.backupErrorFileNotFound,
    BackupErrorCode.invalidFormat => l10n.backupErrorInvalidFormat,
    BackupErrorCode.notAppBackup => l10n.backupErrorNotAppBackup,
    BackupErrorCode.invalidKdf => l10n.backupErrorInvalidKdf,
    BackupErrorCode.decryptFailed => l10n.backupErrorDecrypt,
  };
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

// ------------------------------------------------------------------
// Export Dialog — Stateful để quản lý loading + error inline
// ------------------------------------------------------------------
class _ExportRestoreDialog extends StatefulWidget {
  final AppLocalizations l10n;
  final TextEditingController passController;
  final Future<String?> Function(String passphrase) onExport;

  const _ExportRestoreDialog({
    required this.l10n,
    required this.passController,
    required this.onExport,
  });

  @override
  State<_ExportRestoreDialog> createState() => _ExportRestoreDialogState();
}

class _ExportRestoreDialogState extends State<_ExportRestoreDialog> {
  bool _loading = false;
  String? _error;

  Future<void> _doExport() async {
    final pass = widget.passController.text;
    if (pass.length < 8) {
      setState(() => _error = widget.l10n.exportPassphraseTooShort);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final error = await widget.onExport(pass);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return AlertDialog(
      title: Text(l10n.exportDialogPassphraseTitle),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
          controller: widget.passController,
          obscureText: true,
          autofocus: true,
          enabled: !_loading,
          decoration:
              InputDecoration(labelText: l10n.exportDialogPassphraseLabel),
        ),
        const SizedBox(height: 8),
        Text(l10n.exportDialogPassphraseWarning,
            style: const TextStyle(fontSize: 12)),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.error, fontSize: 13)),
        ],
        if (_loading) ...[
          const SizedBox(height: 16),
          const LinearProgressIndicator(),
          const SizedBox(height: 8),
          Text(l10n.exportInProgress, style: const TextStyle(fontSize: 12)),
        ],
      ]),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: Text(l10n.btnCancel),
        ),
        FilledButton(
          onPressed: _loading ? null : _doExport,
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l10n.btnExport),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------
// Restore Dialog — Stateful: validate path + loading + error inline
// ------------------------------------------------------------------
class _RestoreBackupDialog extends StatefulWidget {
  final AppLocalizations l10n;
  final String? initialPath; // FIX 3.2: Path từ SAF File Picker
  final Future<String?> Function(String path, String passphrase) onRestore;

  const _RestoreBackupDialog({
    required this.l10n,
    this.initialPath,
    required this.onRestore,
  });

  @override
  State<_RestoreBackupDialog> createState() => _RestoreBackupDialogState();
}

class _RestoreBackupDialogState extends State<_RestoreBackupDialog> {
  final _passController = TextEditingController();
  late final TextEditingController _pathController;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // FIX 3.2: Điền sẵn path từ SAF File Picker
    _pathController = TextEditingController(text: widget.initialPath ?? '');
  }

  @override
  void dispose() {
    _passController.dispose();
    _pathController.dispose();
    super.dispose();
  }

  Future<void> _doRestore() async {
    final path = _pathController.text.trim();
    final pass = _passController.text;

    // Validate ngay — KHÔNG dismiss dialog nếu path rỗng
    if (path.isEmpty) {
      setState(() => _error = widget.l10n.restorePathEmpty);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final error = await widget.onRestore(path, pass);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return AlertDialog(
      title: Text(l10n.restoreDialogTitle),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
          controller: _pathController,
          enabled: !_loading,
          decoration: InputDecoration(
              labelText: l10n.restoreDialogPathLabel,
              helperText: l10n.restoreDialogPathHelper),
        ),
        TextField(
          controller: _passController,
          obscureText: true,
          enabled: !_loading,
          decoration:
              InputDecoration(labelText: l10n.restoreDialogPassphraseLabel),
        ),
        const SizedBox(height: 8),
        Text(l10n.restoreDialogWarning,
            style: const TextStyle(fontSize: 12)),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.error, fontSize: 13)),
        ],
        if (_loading) ...[
          const SizedBox(height: 16),
          const LinearProgressIndicator(),
          const SizedBox(height: 8),
          Text(l10n.restoreInProgress, style: const TextStyle(fontSize: 12)),
        ],
      ]),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: Text(l10n.btnCancel),
        ),
        FilledButton(
          onPressed: _loading ? null : _doRestore,
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l10n.btnRestore),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------
// Pro Status Section — Rewarded Ad unlock (rolling 24h)
// ------------------------------------------------------------------
class _ProStatusSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isProAsync = ref.watch(isProActiveProvider);

    return isProAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (isPro) {
        if (isPro) {
          return _ProActiveSection();
        }
        return _ProLockedSection();
      },
    );
  }
}

class _ProActiveSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entitlement = ref.watch(entitlementServiceProvider);

    return FutureBuilder<DateTime?>(
      future: entitlement.expiresAt,
      builder: (ctx, snap) {
        final expires = snap.data;
        final localTime = expires?.toLocal();
        final timeStr = localTime != null
            ? '${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}'
            : '??:??';

        return ListTile(
          leading: const Icon(Icons.workspace_premium),
          title: Text(AppLocalizations.of(context).proActiveTitle,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold)),
          subtitle: Text(AppLocalizations.of(context).proActiveUntil(timeStr)),
        );
      },
    );
  }
}

class _ProLockedSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      leading: const Icon(Icons.workspace_premium_outlined),
      title: Text(l10n.proUnlockTitle),
      subtitle: Text(l10n.proUnlockSubtitle),
      trailing: FilledButton.tonal(
        onPressed: () => _watchAd(context, ref),
        child: Text(l10n.btnWatchAd),
      ),
    );
  }

  void _watchAd(BuildContext context, WidgetRef ref) {
    final adService = ref.read(rewardedAdServiceProvider);
    final entitlement = ref.read(entitlementServiceProvider);

    adService.showAd(
      onEarned: () async {
        await entitlement.unlockFromRewardedAd();
        ref.invalidate(isProActiveProvider);
        if (context.mounted) {
          final l10n = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.proUnlockedSnackbar)),
          );
        }
      },
      onFailed: () {
        if (context.mounted) {
          final l10n = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.adFailedSnackbar)),
          );
        }
      },
    );
  }
}

// ------------------------------------------------------------------
// Theme Mode Picker — System / Light / Dark
// ------------------------------------------------------------------
class _ThemeModePicker extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(themeModeProvider);
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        RadioListTile<ThemeMode>(
          secondary: const Icon(Icons.brightness_auto),
          title: Text(l10n.themeSystem),
          subtitle: Text(l10n.themeSystemSubtitle),
          value: ThemeMode.system,
          groupValue: currentMode,
          onChanged: (mode) {
            if (mode != null) {
              ref.read(themeModeProvider.notifier).setThemeMode(mode);
            }
          },
        ),
        RadioListTile<ThemeMode>(
          secondary: const Icon(Icons.light_mode),
          title: Text(l10n.themeLight),
          value: ThemeMode.light,
          groupValue: currentMode,
          onChanged: (mode) {
            if (mode != null) {
              ref.read(themeModeProvider.notifier).setThemeMode(mode);
            }
          },
        ),
        RadioListTile<ThemeMode>(
          secondary: const Icon(Icons.dark_mode),
          title: Text(l10n.themeDark),
          value: ThemeMode.dark,
          groupValue: currentMode,
          onChanged: (mode) {
            if (mode != null) {
              ref.read(themeModeProvider.notifier).setThemeMode(mode);
            }
          },
        ),
      ],
    );
  }
}
