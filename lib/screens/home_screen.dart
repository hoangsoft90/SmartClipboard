import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../generated/l10n/app_localizations.dart';
import '../services/clipboard_service.dart';
import '../services/share_intent_service.dart';
import '../state/providers.dart';
import 'clipboard/clipboard_history_screen.dart';
import 'playground/playground_screen.dart';
import 'settings/settings_screen.dart';
import 'snippets/snippets_screen.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/save_snippet_dialog.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  int _tab = 0;
  bool _keyboardBannerDismissed = false;
  ShareIntentService? _shareIntent;

  // FIX 1.2: Lưu text bị block để truyền trực tiếp vào saveContent()
  String? _blockedText;

  // Safe Back: double-tap trong 2s để thoát app (mục 3.1).
  DateTime? _lastBackPress;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _registerShareIntent();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shareIntent?.dispose();
    super.dispose();
  }

  void _registerShareIntent() {
    final service = ShareIntentService();
    _shareIntent = service;
    service.listen((text) {
      if (!mounted) return;
      showSaveSharedTextDialog(context, ref, text);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _captureOnResume();
    }
  }

  Future<void> _captureOnResume() async {
    // FIX 1.2: Đọc clipboard TRƯỚC để có text cho trường hợp blocked
    final data = await Clipboard.getData('text/plain');
    final text = data?.text;

    final result =
        await ref.read(clipboardServiceProvider).captureFromSystem();
    await ref.read(clipboardListProvider.notifier).reload();

    if (!mounted) return;

    final l10n = AppLocalizations.of(context);
    final messages = {
      CaptureResult.saved: l10n.clipboardSavedToHistory,
      CaptureResult.deduplicated: null,
      CaptureResult.paused: null,
      CaptureResult.blockedHighRisk: null,
      CaptureResult.empty: null,
    };
    final msg = messages[result];
    if (msg != null && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    }
    if (result == CaptureResult.blockedHighRisk && mounted) {
      // FIX 1.2: Lưu text bị block để truyền trực tiếp vào saveContent()
      _blockedText = text;
      _showHighRiskDialog();
    }
  }

  void _showHighRiskDialog() {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.highRiskTitle),
        content: Text(l10n.highRiskContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.highRiskDontSave),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // FIX 1.2: Truyền trực tiếp blockedText — KHÔNG đọc lại clipboard
              final textToSave = _blockedText ?? '';
              _blockedText = null; // Clear sau khi dùng
              await ref
                  .read(clipboardServiceProvider)
                  .confirmSaveBlockedContent(textToSave);
              await ref.read(clipboardListProvider.notifier).reload();
            },
            child: Text(l10n.highRiskSaveAndDelete),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;

        final now = DateTime.now();
        final isFirstBack = _lastBackPress == null ||
            now.difference(_lastBackPress!) > const Duration(seconds: 2);

        if (isFirstBack) {
          _lastBackPress = now;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.btnBack),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: Column(children: [
          if (!_keyboardBannerDismissed)
            _KeyboardEnableBanner(onDismiss: () =>
                setState(() => _keyboardBannerDismissed = true)),
          Expanded(
            child: IndexedStack(index: _tab, children: const [
              ClipboardHistoryScreen(),
              SnippetsScreen(),
              PlaygroundScreen(),
              SettingsScreen(),
            ]),
          ),
          const BannerAdWidget(),
        ]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: [
            NavigationDestination(
                icon: const Icon(Icons.history), label: l10n.tabClipboard),
            NavigationDestination(
                icon: const Icon(Icons.bolt), label: l10n.tabSnippets),
            NavigationDestination(
                icon: const Icon(Icons.auto_fix_high),
                label: l10n.tabPlayground),
            NavigationDestination(
                icon: const Icon(Icons.settings), label: l10n.tabSettings),
          ],
        ),
      ),
    );
  }
}

class _KeyboardEnableBanner extends ConsumerWidget {
  final VoidCallback onDismiss;
  const _KeyboardEnableBanner({required this.onDismiss});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final activationState =
        ref.watch(keyboardActivationStateProvider).value ??
            KeyboardActivationState.disabled;

    // Chỉ hiển thị banner khi chưa active
    if (activationState == KeyboardActivationState.active) {
      return const SizedBox.shrink();
    }

    final isDisabled =
        activationState == KeyboardActivationState.disabled;

    return Material(
      color: isDisabled
          ? Theme.of(context).colorScheme.errorContainer
          : Theme.of(context).colorScheme.tertiaryContainer,
      child: SafeArea(
        bottom: false,
        child: ListTile(
          dense: true,
          leading: Icon(
            isDisabled ? Icons.keyboard : Icons.swap_horiz,
            color: isDisabled
                ? Theme.of(context).colorScheme.onErrorContainer
                : Theme.of(context).colorScheme.onTertiaryContainer,
          ),
          title: Text(
            isDisabled
                ? l10n.playgroundKeyboardDisabled
                : l10n.playgroundKeyboardEnabled,
            style: TextStyle(
              fontSize: 13,
              color: isDisabled
                  ? Theme.of(context).colorScheme.onErrorContainer
                  : Theme.of(context).colorScheme.onTertiaryContainer,
            ),
          ),
          subtitle: Text(
            isDisabled
                ? l10n.playgroundKeyboardSubtitle
                : 'Tap to switch to Smart Clipboard',
            style: const TextStyle(fontSize: 11),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: onDismiss,
          ),
          onTap: () async {
            if (isDisabled) {
              await ref
                  .read(nativeBridgeProvider)
                  .openKeyboardSettings();
            } else {
              await ref
                  .read(nativeBridgeProvider)
                  .showKeyboardPicker();
            }
            ref.invalidate(keyboardActivationStateProvider);
          },
        ),
      ),
    );
  }
}
