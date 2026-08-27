import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// Share Sheet Integration — Fallback chính thay Floating Widget
/// (Floating Widget đã bị LOẠI khỏi MVP — mục 7, quyết định chốt mục 11).
///
/// User share text từ Chrome/Gmail/Messenger → Smart Clipboard xuất hiện
/// trong system sharesheet → app nhận text và cho phép Save as Clipboard /
/// Save as Snippet.
///
/// Web: Share Intent không khả dụng — feature bị vô hiệu hoá trên web.
/// Yêu cầu manifest (merge sau `flutter create`): intent-filter ACTION_SEND
/// với mimeType text/plain trên MainActivity — xem README.
class ShareIntentService {
  StreamSubscription? _subscription;

  /// Platform guard: share intent chỉ khả dụng trên mobile.
  bool get _isSupported => !kIsWeb;

  /// Lắng nghe text được share vào app (kể cả khi app đang chạy ngầm).
  /// Web: no-op — share intent không hỗ trợ trên web.
  void listen(void Function(String text) onTextReceived) {
    if (!_isSupported) return;
    _subscription = ReceiveSharingIntent.instance.getMediaStream().listen(
      (files) => _handle(files, onTextReceived),
      onError: (Object _) {/* best-effort — không crash */},
    );
    ReceiveSharingIntent.instance.getInitialMedia().then((files) {
      _handle(files, onTextReceived);
      ReceiveSharingIntent.instance.reset();
    }).catchError((Object _) {});
  }

  void _handle(List<SharedMediaFile> files, void Function(String) onText) {
    for (final file in files) {
      if (file.type == SharedMediaType.text && file.path.isNotEmpty) {
        onText(file.path); // plugin đưa text content trong trường `path`
      }
    }
  }

  void dispose() => _subscription?.cancel();
}
