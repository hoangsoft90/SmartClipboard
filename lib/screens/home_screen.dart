import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/clipboard_service.dart';
import '../services/share_intent_service.dart';
import '../state/providers.dart';
import 'clipboard/clipboard_history_screen.dart';
import 'playground/playground_screen.dart';
import 'settings/settings_screen.dart';
import 'snippets/snippets_screen.dart';
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

  /// Share Sheet Integration (P0): user chủ động Share text vào app.
  void _registerShareIntent() {
    final service = ShareIntentService();
    _shareIntent = service;
    service.listen((text) {
      if (!mounted) return;
      showSaveSharedTextDialog(context, ref, text);
    });
  }

  // Foreground Capture — STRICT RULE 1: KHÔNG background service. App chỉ đọc
  // clipboard khi lên foreground (resume).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _captureOnResume();
    }
  }

  Future<void> _captureOnResume() async {
    final result =
        await ref.read(clipboardServiceProvider).captureFromSystem();
    await ref.read(clipboardListProvider.notifier).reload();
    await ref.read(archivedClipboardCountProvider.future);

    // Guard:widget có thể bị unmount trong lúc await.
    if (!mounted) return;

    final messages = {
      CaptureResult.saved: 'Đã lưu vào lịch sử',
      CaptureResult.deduplicated: null, // im lặng khi trùng nội dung
      CaptureResult.paused: null, // Incognito mode — không báo spam
      CaptureResult.blockedHighRisk: null,
      CaptureResult.empty: null,
    };
    final msg = messages[result];
    if (msg != null && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    }
    if (result == CaptureResult.blockedHighRisk && mounted) {
      _showHighRiskDialog();
    }
  }

  /// Heuristic nghi vấn CAO (score=2) → hỏi user trước khi lưu.
  /// ⚠️ Đây CHỈ là heuristic gợi ý, không phải security guarantee (mục 5.1).
  void _showHighRiskDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Văn bản có thể nhạy cảm ⚠️'),
        content: const Text(
            'Nội dung trong clipboard trông giống OTP / mật khẩu / API key.\n\n'
            'Lưu vào lịch sử? Nếu lưu, sẽ tự động xoá sau 24h.\n\n'
            '(Phát hiện này chỉ là dự đoán heuristic, không phải bảo đảm.)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Không lưu'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(clipboardServiceProvider)
                  .confirmSaveBlockedContent();
              await ref.read(clipboardListProvider.notifier).reload();
            },
            child: const Text('Lưu & xoá sau 24h'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              const SnackBar(
                content: Text('Nhấn lại để thoát'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else {
          // Double-tap: thoát app.
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
        ]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.history), label: 'Lịch sử'),
            NavigationDestination(icon: Icon(Icons.bolt), label: 'Snippet'),
            NavigationDestination(icon: Icon(Icons.auto_fix_high), label:
                'Playground'),
            NavigationDestination(icon: Icon(Icons.settings), label: 'Cài đặt'),
          ],
        ),
      ),
    );
  }
}

/// Banner nhẹ nhàng mời bật keyboard nếu chưa enable (mục 7) — không spam:
/// chỉ hiện ở Home, dismiss được.
class _KeyboardEnableBanner extends ConsumerWidget {
  final VoidCallback onDismiss;
  const _KeyboardEnableBanner({required this.onDismiss});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(keyboardEnabledProvider);
    return enabled.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (isEnabled) => isEnabled
          ? const SizedBox.shrink()
          : Material(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: SafeArea(
                bottom: false,
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.keyboard),
                  title: const Text(
                      'Bật bàn phím Smart Clipboard để gõ tắt mọi nơi',
                      style: TextStyle(fontSize: 13)),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: onDismiss,
                  ),
                  onTap: () =>
                      ref.read(nativeBridgeProvider).openKeyboardSettings(),
                ),
              ),
            ),
    );
  }
}
