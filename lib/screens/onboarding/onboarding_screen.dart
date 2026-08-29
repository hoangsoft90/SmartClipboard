import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../generated/l10n/app_localizations.dart';
import '../../state/providers.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _page == 0) {
          _finish(context);
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: const [
                  _IntroPage(),
                  _KeyboardPage(),
                  _SecurityWarningPage(),
                  _OemBatteryPage(),
                  _ShareSheetPage(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => _go(context, last: true),
                    child: Text(l10n.btnSkip),
                  ),
                  FilledButton(
                    onPressed: () =>
                        _page < 4 ? _controller.nextPage(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut)
                        : _finish(context),
                    child: Text(_page < 4 ? l10n.btnNext : l10n.onboardingGetStarted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  void _go(BuildContext context, {bool last = false}) {
    if (last) {
      _finish(context);
      return;
    }
    _controller.nextPage(
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  void _finish(BuildContext context) async {
    final container = ProviderScope.containerOf(context);
    await container.read(appSettingsProvider.notifier).completeOnboarding();
  }
}

class _IntroPage extends StatelessWidget {
  const _IntroPage();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_stories,
              size: 96, color: theme.colorScheme.primary),
          const SizedBox(height: 24),
          Text(l10n.onboardingTitle1,
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(l10n.onboardingSubtitle1,
              style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.offline_bolt),
            title: const Text('100% Local-first'),
            subtitle: const Text(
                'Không server, không cloud, không gửi nội dung ra ngoài thiết bị.'),
          ),
          ListTile(
            leading: const Icon(Icons.gavel),
            title: Text(l10n.onboardingTitle2),
            subtitle: Text(l10n.onboardingSubtitle2),
          ),
        ],
      ),
    );
  }
}

class _KeyboardPage extends ConsumerStatefulWidget {
  const _KeyboardPage();

  @override
  ConsumerState<_KeyboardPage> createState() => _KeyboardPageState();
}

class _KeyboardPageState extends ConsumerState<_KeyboardPage> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final activationState =
        ref.watch(keyboardActivationStateProvider).value ??
            KeyboardActivationState.disabled;
    final isDisabled =
        activationState == KeyboardActivationState.disabled;
    final isActive =
        activationState == KeyboardActivationState.active;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.keyboard_alt_outlined,
              size: 96, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 24),
          Text(l10n.onboardingTitle4,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            l10n.onboardingSubtitle4,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (isDisabled)
            Card(
              color: Colors.amber,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  l10n.playgroundKeyboardSubtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          if (!isDisabled && !isActive)
            Card(
              color: Colors.orange,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Keyboard enabled! Tap below to switch to Smart Clipboard.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          if (isActive)
            Card(
              color: Colors.green,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Smart Clipboard is your active keyboard!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () async {
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
            icon: Icon(
              isActive ? Icons.check_circle : Icons.settings,
            ),
            label: Text(
              switch (activationState) {
                KeyboardActivationState.disabled =>
                    l10n.onboardingEnableKeyboard,
                KeyboardActivationState.enabledNotActive =>
                    'Switch to Smart Clipboard',
                KeyboardActivationState.active =>
                    l10n.playgroundKeyboardEnabled,
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(l10n.onboardingSubtitle4,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
}

class _SecurityWarningPage extends StatelessWidget {
  const _SecurityWarningPage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shield_outlined,
              size: 96, color: theme.colorScheme.primary),
          const SizedBox(height: 24),
          Text(
            'Cảnh báo bảo mật Android',
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Card(
            color: theme.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    "Android sẽ hiện cảnh báo bảo mật tiêu chuẩn cho mọi "
                    "bàn phím: 'Bàn phím này có thể đọc mọi thứ bạn gõ, "
                    "bao gồm mật khẩu và số thẻ.'",
                    style: TextStyle(
                      color: theme.colorScheme.onErrorContainer,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Đây là cảnh báo mặc định của Android cho MỌI IME, '
                    'không riêng gì Smart Clipboard.',
                    style: TextStyle(
                      color: theme.colorScheme.onErrorContainer,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.offline_bolt),
            title: const Text('100% Local-first'),
            subtitle: const Text(
                'Không có quyền Internet, không gửi dữ liệu ra ngoài.'),
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Không lưu mật khẩu'),
            subtitle: const Text(
                'Smart Clipboard KHÔNG đọc ô nhập mật khẩu (password field).'),
          ),
        ],
      ),
    );
  }
}

class _OemBatteryPage extends StatelessWidget {
  const _OemBatteryPage();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.battery_saver,
              size: 96, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text('Mẹo cho máy Xiaomi / Oppo / Samsung',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          const Text(
            'Một số máy Việt Nam (MIUI, ColorOS, One UI) có quản lý pin '
            'nghiêm ngặt, có thể làm bàn phím/snippet mới không cập nhật kịp.\n\n'
            'Khuyến nghị:\n'
            '• Vào Cài đặt > Pin > Tối ưu hoá pin\n'
            '• Chọn Smart Clipboard → "Không giới hạn" (Không tối ưu)\n'
            '• MIUI: thêm app vào danh sách bảo vệ khởi động tự động',
          ),
          const SizedBox(height: 8),
          Text(l10n.onboardingSkipHint,
              style: const TextStyle(fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
}

class _ShareSheetPage extends StatelessWidget {
  const _ShareSheetPage();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.share,
              size: 96, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 24),
          Text(l10n.onboardingTitle3,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text(
            l10n.onboardingSubtitle3,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
