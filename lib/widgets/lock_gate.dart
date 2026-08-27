import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';

/// Biometric App Lock gate (P0 Free — mục 8). Bọc quanh child; chỉ render
/// child sau khi user xác thực vân tay/khuôn mặt thành công.
/// Web: Biometric không khả dụng — luôn render child trực tiếp.
class LockGate extends ConsumerStatefulWidget {
  final Widget child;
  const LockGate({super.key, required this.child});

  @override
  ConsumerState<LockGate> createState() => _LockGateState();
}

class _LockGateState extends ConsumerState<LockGate> {
  bool _unlocked = false;
  bool _authenticating = false;

  Future<void> _authenticate({bool autoAttempt = true}) async {
    if (_authenticating || _unlocked) return;
    // Web: Biometric không khả dụng — luôn mở.
    if (kIsWeb) {
      if (mounted) setState(() => _unlocked = true);
      return;
    }
    setState(() => _authenticating = true);
    final ok = await ref.read(authServiceProvider).authenticate();
    if (!mounted) return;
    setState(() {
      _authenticating = false;
      _unlocked = ok;
    });
    // Không tự retry vô hạn nếu user hủy — hiển thị nút thử lại thủ công.
    assert(autoAttempt || true);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
  }

  @override
  Widget build(BuildContext context) {
    if (_unlocked) return widget.child;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline,
                size: 64,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            const Text('Smart Clipboard đã bị khoá'),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed:
                  _authenticating ? null : () => _authenticate(autoAttempt: false),
              icon: _authenticating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.fingerprint),
              label: Text(_authenticating ? 'Đang xác thực...' : 'Mở khoá'),
            ),
          ],
        ),
      ),
    );
  }
}
