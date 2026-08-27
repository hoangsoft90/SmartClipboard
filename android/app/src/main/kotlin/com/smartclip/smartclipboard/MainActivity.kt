package com.smartclip.smartclipboard

import io.flutter.embedding.android.FlutterActivity

/**
 * MainActivity — Phase 0 stub.
 * KHÔNG có MethodChannel handler nào (chỉ stub từ Dart side trả false).
 * Phase 1 sẽ thêm: clipboard monitoring service, keyboard IME integration.
 *
 * STRICT RULE 6: Flutter App process và Android IME process là hai tiến trình
 * OS độc lập, KHÔNG chia sẻ bộ nhớ. Sync chỉ qua file cache.
 */
class MainActivity : FlutterActivity()
