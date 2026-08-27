import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';

/// Onboarding flow kép — Master Spec mục 7.
///
/// Màn 1: Giới thiệu "Personal Text Memory" + cam kết 100% Privacy.
/// Màn 2: Hướng dẫn bật System Keyboard (Direct Intent Settings qua
///        MethodChannel — Phase 0 là stub, Kotlin thuộc Phase 1).
/// Màn 3: Hướng dẫn battery optimization theo hãng máy phổ biến tại VN
///        (MIUI/ColorOS/One UI) — STRICT RULE (mục 7.1): phải hiển thị rõ,
///        không block nếu user bỏ qua.
/// Màn 4: Share Sheet fallback — biến hạn chế "không đọc clipboard nền"
///        thành lợi thế chủ động. KHÔNG dùng Floating Widget trong MVP.
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        // Ngăn user back ra khỏi onboarding — phải finish hoặc skip.
        // Nếu ở page đầu tiên, cho phép exit (user thực sự muốn thoát).
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
                    child: const Text('Bỏ qua'),
                  ),
                  FilledButton(
                    onPressed: () =>
                        _page < 3 ? _controller.nextPage(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut)
                        : _finish(context),
                    child: Text(_page < 3 ? 'Tiếp' : 'Bắt đầu dùng'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ), // Scaffold
    ); // PopScope
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
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_stories,
              size: 96, color: theme.colorScheme.primary),
          const SizedBox(height: 24),
          Text('Personal Text Memory',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          const Text('Lưu một lần. Dán ở bất cứ đâu.',
              style: TextStyle(fontSize: 16)),
          const SizedBox(height: 24),
          const ListTile(
            leading: Icon(Icons.offline_bolt),
            title: Text('100% Local-first'),
            subtitle: Text(
                'Không server, không cloud, không gửi nội dung ra ngoài thiết bị.'),
          ),
          const ListTile(
            leading: Icon(Icons.gavel),
            title: Text('Gõ tắt mọi nơi'),
            subtitle: Text('Tạo snippet ;email → gõ ;email và dấu cách → '
                'được thay bằng địa chỉ đầy đủ.'),
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
  bool? _enabled;

  Future<void> _checkStatus() async {
    final enabled =
        await ref.read(nativeBridgeProvider).isKeyboardEnabled();
    if (mounted) setState(() => _enabled = enabled);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.keyboard_alt_outlined,
              size: 96, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 24),
          Text('Bật bàn phím Smart Clipboard',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          const Text(
            'Để gõ tắt ở MỌI ứng dụng, hãy:\n'
            '1. Bấm "Enable Keyboard" bên dưới\n'
            '2. Bật công tắc của Smart Clipboard trong Cài đặt hệ thống\n'
            '3. Chọn Smart Clipboard làm bàn phím mặc định',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () async {
              await ref.read(nativeBridgeProvider).openKeyboardSettings();
              await _checkStatus();
            },
            icon: const Icon(Icons.settings),
            label: const Text('Enable Keyboard'),
          ),
          OutlinedButton(
            onPressed: _checkStatus,
            child: Text(_enabled == null
                ? 'Kiểm tra trạng thái'
                : (_enabled!
                    ? '✅ Đã bật bàn phím'
                    : '⏳ Chưa bật — bạn có thể bật sau')),
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
          const Text('Bạn có thể bỏ qua bước này và quay lại sau.',
              style: TextStyle(fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
}

class _ShareSheetPage extends StatelessWidget {
  const _ShareSheetPage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.share,
              size: 96, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 24),
          Text('Chia sẻ vào app bất cứ lúc nào',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          const Text(
            'Thấy text hữu ích trên web/tin nhắn? Bấm Share → chọn '
            '"Smart Clipboard" để lưu thành lịch sử hoặc snippet.\n\n'
            'App không nghe lén nền — bạn chủ động gửi text vào app. '
            'Đó chính là cách chúng tôi giữ sự riêng tư của bạn.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
