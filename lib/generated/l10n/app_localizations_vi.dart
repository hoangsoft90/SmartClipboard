// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get appTitle => 'Smart Clipboard';

  @override
  String get tabClipboard => 'Lịch sử';

  @override
  String get tabSnippets => 'Snippet';

  @override
  String get tabPlayground => 'Playground';

  @override
  String get tabSettings => 'Cài đặt';

  @override
  String get btnEnable => 'Bật';

  @override
  String get btnCancel => 'Huỷ';

  @override
  String get btnSave => 'Lưu';

  @override
  String get btnCreate => 'Tạo';

  @override
  String get btnExport => 'Export';

  @override
  String get btnRestore => 'Restore';

  @override
  String get btnExit => 'Thoát';

  @override
  String get btnStay => 'Ở lại';

  @override
  String get btnSkip => 'Bỏ qua';

  @override
  String get btnLater => 'Để sau';

  @override
  String get btnCopy => 'Copy';

  @override
  String get btnRename => 'Đổi tên';

  @override
  String get btnDelete => 'Xoá';

  @override
  String get btnClose => 'Đóng';

  @override
  String get btnBack => 'Quay lại';

  @override
  String get btnDone => 'Xong';

  @override
  String get btnNext => 'Tiếp theo';

  @override
  String get clipboardHistoryTitle => 'Lịch sử Clipboard';

  @override
  String get clipboardEmpty =>
      'Chưa có nội dung nào.\nSwitch sang app khác rồi quay lại để lưu clipboard.';

  @override
  String get clipboardLoadError => 'Lỗi tải dữ liệu';

  @override
  String get clipboardCopied => 'Đã copy';

  @override
  String get clipboardSavedToHistory => 'Đã lưu vào lịch sử';

  @override
  String get clipboardPaused => 'ĐANG TẠM DỪNG ghi lịch sử clipboard';

  @override
  String get clipboardPauseResumeTooltip => 'Bỏ tạm dừng ghi lịch sử';

  @override
  String get clipboardPauseTooltip => 'Tạm dừng ghi lịch sử (Incognito)';

  @override
  String get clipboardPauseSubtitle =>
      'Incognito/Pause Mode — tạm dừng 1 chạm, không nghe lén nền';

  @override
  String get clipboardAutoDelete => 'Tự xoá lịch sử sau';

  @override
  String get clipboardAutoDeleteSubtitle =>
      'Auto-Expiration Engine (1/7/30 ngày)';

  @override
  String get popupCopyAgain => 'Copy lại';

  @override
  String get popupSaveAsSnippet => 'Lưu thành Snippet';

  @override
  String get popupDeleteAfter24h => 'Xoá sau 24h ⚠️ heuristic';

  @override
  String get popupHideFromHistory => 'Ẩn khỏi lịch sử';

  @override
  String get popupDeletePermanently => 'Xoá vĩnh viễn';

  @override
  String get popupPin => 'Ghim';

  @override
  String get popupUnpin => 'Bỏ ghim';

  @override
  String get popupFavorite => 'Yêu thích';

  @override
  String get popupUnfavorite => 'Bỏ yêu thích';

  @override
  String get snippetsTitle => 'Snippets (Gõ tắt)';

  @override
  String get snippetsEmpty =>
      'Chưa có snippet nào.\nTạo snippet ở tab \"Snippet\" trước, rồi quay lại đây thử gõ tắt!';

  @override
  String get snippetsNew => 'Snippet mới';

  @override
  String get snippetNewTitle => 'Tạo snippet mới';

  @override
  String get snippetTitleLabel => 'Tên (vd: Email công việc)';

  @override
  String get snippetTriggerLabel => 'Trigger không dấu cách (vd: email)';

  @override
  String get snippetTriggerPrefix => 'Tiền tố trigger';

  @override
  String get snippetContentLabel => 'Nội dung';

  @override
  String get snippetFolderOptional => 'Folder (tuỳ chọn)';

  @override
  String get snippetCreated => 'Đã tạo snippet';

  @override
  String snippetCreatedWithArchived(Object count) {
    return 'Đã tạo snippet. $count snippet cũ bị ẩn do giới hạn Free — mua Pro để mở khoá.';
  }

  @override
  String get snippetDeleteTitle => 'Xoá snippet?';

  @override
  String get snippetDiscardTitle => 'Thoát without saving?';

  @override
  String get snippetDiscardContent =>
      'Bạn có thay đổi chưa lưu. Thoát sẽ mất nội dung.';

  @override
  String get snippetEnable => 'Bật';

  @override
  String get snippetDisable => 'Tắt';

  @override
  String get snippetUsage => 'Lượt dùng';

  @override
  String get foldersTitle => 'Folders';

  @override
  String get foldersEmpty => 'Chưa có folder nào';

  @override
  String get foldersNew => 'Folder mới';

  @override
  String get foldersFreeLimit => 'Giới hạn bản Free';

  @override
  String get foldersRename => 'Đổi tên folder';

  @override
  String get playgroundTitle => '✨ Smart Expander Playground';

  @override
  String playgroundHintText(Object trigger) {
    return 'Nhập trigger (vd: $trigger) rồi gõ dấu cách...';
  }

  @override
  String get playgroundHelperText =>
      'Mẹo: ;;email → xuất ra ;email (escape). Trigger chỉ mở rộng khi theo sau bởi Space/Enter/dấu câu.';

  @override
  String get playgroundNoSnippets =>
      'Chưa có snippet nào. Tạo snippet ở tab \"Snippet\" trước, rồi quay lại đây thử gõ tắt!';

  @override
  String playgroundPrefixDefault(Object prefix) {
    return 'Prefix mặc định: \"$prefix\" (Pro: cho phép đổi)';
  }

  @override
  String get playgroundKeyboardEnabled => 'Bàn phím Smart Clipboard đã bật';

  @override
  String get playgroundKeyboardDisabled =>
      '💡 Bật keyboard Smart Clipboard để dùng ngay trên mọi ứng dụng!';

  @override
  String get playgroundKeyboardSubtitle =>
      '🔧 Tính năng sẽ có ở Phase 1 — hiện tại chỉ dùng được trong Playground';

  @override
  String get playgroundKeyboardPhase0 =>
      'Bàn phím Smart Clipboard chưa khả dụng ở Phase 0. Đang phát triển!';

  @override
  String playgroundExpanded(Object trigger) {
    return 'Đã mở rộng $trigger';
  }

  @override
  String get playgroundCopyResult => 'Copy kết quả';

  @override
  String get playgroundCopied => 'Đã copy';

  @override
  String get settingsTitle => 'Cài đặt';

  @override
  String get settingsPauseLogging => 'Tạm dừng ghi Clipboard History';

  @override
  String get settingsAutoDelete => 'Tự xoá lịch sử sau';

  @override
  String get settingsBiometricLock => 'Khoá app bằng sinh trắc học';

  @override
  String get settingsBiometricSubtitle =>
      'Vân tay/khuôn mặt — miễn phí bản Free';

  @override
  String get settingsBiometricNotSupported =>
      'Thiết bị không hỗ trợ sinh trắc học hoặc chưa cài đặt';

  @override
  String get settingsSensitiveDetection => 'Phát hiện dữ liệu nhạy cảm';

  @override
  String get settingsSensitiveSubtitle =>
      '⚠️ CHỈ LÀ heuristic (regex + entropy) để GỢI Ý — KHÔNG PHẢI bảo đảm bảo mật tuyệt đối. Entropy cao có thể chỉ là random ID.';

  @override
  String get settingsExportBackup => 'Export backup mã hoá (AES-256-GCM)';

  @override
  String get settingsExportSubtitle =>
      'Khóa derive từ passphrase của bạn qua PBKDF2 (≥100k lần lặp). Hãy nhớ passphrase — không ai khôi phục được nếu quên!';

  @override
  String get settingsRestoreBackup => 'Restore từ file backup';

  @override
  String get settingsBackupSection => 'Sao lưu & Khôi phục';

  @override
  String get settingsSecuritySection => 'Bảo mật';

  @override
  String get settingsCaptureSection => 'Ghi lịch sử';

  @override
  String get settingsStatsSection => 'Thống kê (chỉ lưu trên máy)';

  @override
  String get settingsKeyboardBgColor => 'Màu nền bàn phím';

  @override
  String get exportDialogPassphraseTitle => 'Nhập passphrase cho backup';

  @override
  String get exportDialogPassphraseLabel => 'Passphrase (tự chọn)';

  @override
  String get exportDialogPassphraseWarning =>
      'Key mã hoá được tạo từ passphrase này. QUÊN PASSPHRASE = KHÔNG THỂ RESTORE. Salt + nonce ngẫu nhiên được lưu trong file.';

  @override
  String get exportPassphraseTooShort => 'Passphrase phải có ít nhất 8 ký tự.';

  @override
  String exportSuccess(Object path) {
    return 'Đã export: $path';
  }

  @override
  String get exportFailed => 'Export thất bại. Vui lòng thử lại.';

  @override
  String get exportInProgress => 'Đang export... Vui lòng chờ.';

  @override
  String get restoreDialogTitle => 'Restore từ backup';

  @override
  String get restoreDialogPathLabel => 'Đường dẫn file .scbak';

  @override
  String get restoreDialogPathHelper =>
      'Vd: /data/user/0/.../files/smart_clipboard_backup_....scbak';

  @override
  String get restoreDialogPassphraseLabel => 'Passphrase';

  @override
  String get restoreDialogWarning =>
      '⚠️ Restore sẽ THAY THẾ toàn bộ data hiện tại trong app.';

  @override
  String get restorePathEmpty => 'Vui lòng nhập đường dẫn file backup.';

  @override
  String get restoreSuccess => 'Restore thành công!';

  @override
  String get restoreFailed => 'Restore thất bại. Kiểm tra lại file/passphrase.';

  @override
  String get restoreInProgress => 'Đang khôi phục... Không đóng hộp thoại này.';

  @override
  String get statsSnippetsCreated => 'Snippets đã tạo';

  @override
  String get statsExpansions => 'Lần mở rộng';

  @override
  String get statsClipboardSaved => 'Clipboard đã lưu';

  @override
  String get statsClipboardReused => 'Clipboard tái dùng';

  @override
  String get statsPlaygroundExpansions => 'Playground expansions';

  @override
  String get statsActiveDays => 'Ngày active';

  @override
  String statsPerDay(Object value) {
    return 'Mở rộng / ngày active: $value\n≥ 1 → thói quen dùng Text Expander đã hình thành (tiêu chí Go Phase 1 — mục 10 spec)';
  }

  @override
  String get highRiskTitle => 'Văn bản có thể nhạy cảm ⚠️';

  @override
  String get highRiskContent =>
      'Nội dung trong clipboard trông giống OTP / mật khẩu / API key.\n\nLưu vào lịch sử? Nếu lưu, sẽ tự động xoá sau 24h.\n\n(Phát hiện này chỉ là dự đoán heuristic, không phải bảo đảm.)';

  @override
  String get highRiskDontSave => 'Không lưu';

  @override
  String get highRiskSaveAndDelete => 'Lưu & xoá sau 24h';

  @override
  String shareReceived(Object length) {
    return 'Nhận text được chia sẻ ($length ký tự)';
  }

  @override
  String get shareSaveToHistory => 'Lưu vào lịch sử Clipboard';

  @override
  String get shareCreateSnippet => 'Tạo Snippet với trigger';

  @override
  String get onboardingTitle1 => 'Smart Clipboard';

  @override
  String get onboardingSubtitle1 => 'Lưu một lần. Dán ở bất cứ đâu.';

  @override
  String get onboardingTitle2 => 'Gõ tắt mọi nơi';

  @override
  String get onboardingSubtitle2 =>
      'Gõ ;email → mở rộng thành email của bạn. Hoạt động trên mọi ứng dụng!';

  @override
  String get onboardingTitle3 => 'Bảo mật trước tiên';

  @override
  String get onboardingSubtitle3 =>
      '100% local. Không cloud. Dữ liệu không bao giờ rời khỏi thiết bị.';

  @override
  String get onboardingTitle4 => 'Bật bàn phím';

  @override
  String get onboardingSubtitle4 =>
      'Tính năng này sẽ khả dụng trong bản cập nhật tới.';

  @override
  String get onboardingSkipHint =>
      'Bạn có thể bỏ qua bước này và quay lại sau.';

  @override
  String get onboardingEnableKeyboard => 'Bật bàn phím (Phase 1)';

  @override
  String get onboardingGetStarted => 'Bắt đầu';

  @override
  String get lockGateTitle => 'Smart Clipboard đã bị khoá';

  @override
  String get lockGateSubtitle => 'Xác thực để mở';

  @override
  String get proUpgradeTitle => 'Smart Clipboard Pro';

  @override
  String get proUpgradeSubtitle => 'Nâng cấp Pro để mở khoá toàn bộ';

  @override
  String get proUpgradePrice => 'Mua một lần';

  @override
  String get appLanguage => 'Ngôn ngữ ứng dụng';

  @override
  String get appLanguageSubtitle => 'Chọn ngôn ngữ bạn muốn';

  @override
  String get langVietnamese => 'Tiếng Việt';

  @override
  String get langEnglish => 'English';

  @override
  String get timeAgoJustNow => 'vừa xong';

  @override
  String timeAgoMinutes(Object minutes) {
    return '$minutes phút trước';
  }

  @override
  String timeAgoHours(Object hours) {
    return '$hours giờ trước';
  }

  @override
  String timeAgoDays(Object days) {
    return '$days ngày trước';
  }

  @override
  String get searchClipboardHint => 'Tìm trong clipboard...';

  @override
  String get searchSnippetsHint => 'Tìm snippet...';

  @override
  String get filterAll => 'Tất cả';

  @override
  String get filterFavorites => 'Yêu thích';

  @override
  String get filterPinned => 'Đã ghim';

  @override
  String get filterEnabled => 'Đang bật';

  @override
  String get filterDisabled => 'Đã tắt';
}
