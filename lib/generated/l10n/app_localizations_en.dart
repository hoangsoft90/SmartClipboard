// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Smart Clipboard';

  @override
  String get tabClipboard => 'History';

  @override
  String get tabSnippets => 'Snippet';

  @override
  String get tabPlayground => 'Playground';

  @override
  String get tabSettings => 'Settings';

  @override
  String get btnEnable => 'Enable';

  @override
  String get btnCancel => 'Cancel';

  @override
  String get btnSave => 'Save';

  @override
  String get btnCreate => 'Create';

  @override
  String get btnExport => 'Export';

  @override
  String get btnRestore => 'Restore';

  @override
  String get btnExit => 'Exit';

  @override
  String get btnStay => 'Stay';

  @override
  String get btnSkip => 'Skip';

  @override
  String get btnLater => 'Later';

  @override
  String get btnCopy => 'Copy';

  @override
  String get btnRename => 'Rename';

  @override
  String get btnEdit => 'Edit';

  @override
  String get btnDelete => 'Delete';

  @override
  String get btnClose => 'Close';

  @override
  String get btnBack => 'Back';

  @override
  String get btnDone => 'Done';

  @override
  String get btnNext => 'Next';

  @override
  String get clipboardHistoryTitle => 'Clipboard History';

  @override
  String get clipboardEmpty =>
      'No content yet.\nSwitch to another app and come back to save clipboard.';

  @override
  String get clipboardLoadError => 'Failed to load data';

  @override
  String get clipboardCopied => 'Copied';

  @override
  String get clipboardSavedToHistory => 'Saved to history';

  @override
  String get clipboardPaused => 'CLIPBOARD LOGGING PAUSED';

  @override
  String get clipboardPauseResumeTooltip => 'Resume clipboard logging';

  @override
  String get clipboardPauseTooltip => 'Pause clipboard logging (Incognito)';

  @override
  String get clipboardPauseSubtitle =>
      'Incognito/Pause Mode — one-tap pause, no background logging';

  @override
  String get clipboardAutoDelete => 'Auto-delete history after';

  @override
  String get clipboardAutoDeleteSubtitle =>
      'Auto-Expiration Engine (1/7/30 days)';

  @override
  String clipboardAutoDeleteOption(Object days) {
    return '$days days';
  }

  @override
  String get popupCopyAgain => 'Copy again';

  @override
  String get popupSaveAsSnippet => 'Save as Snippet';

  @override
  String get popupDeleteAfter24h => 'Delete after 24h ⚠️ heuristic';

  @override
  String get popupHideFromHistory => 'Hide from history';

  @override
  String get popupDeletePermanently => 'Delete permanently';

  @override
  String get popupPin => 'Pin';

  @override
  String get popupUnpin => 'Unpin';

  @override
  String get popupFavorite => 'Favorite';

  @override
  String get popupUnfavorite => 'Unfavorite';

  @override
  String get snippetsTitle => 'Snippets (Text Expander)';

  @override
  String get snippetsEmpty =>
      'No snippets yet.\nCreate a snippet first, then come back to try text expansion!';

  @override
  String get snippetsNew => 'New Snippet';

  @override
  String get snippetNewTitle => 'Create new snippet';

  @override
  String get snippetTitleLabel => 'Name (e.g. Work email)';

  @override
  String get snippetTriggerLabel => 'Trigger without spaces (e.g. email)';

  @override
  String get snippetTriggerPrefix => 'Trigger prefix';

  @override
  String get snippetContentLabel => 'Content';

  @override
  String get snippetFolderOptional => 'Folder (optional)';

  @override
  String get snippetCreated => 'Snippet created';

  @override
  String snippetCreatedWithArchived(Object count) {
    return 'Snippet created. $count old snippet(s) hidden due to Free limit — upgrade to Pro to unlock.';
  }

  @override
  String get snippetDeleteTitle => 'Delete snippet?';

  @override
  String get snippetDiscardTitle => 'Exit without saving?';

  @override
  String get snippetDiscardContent =>
      'You have unsaved changes. Exiting will lose them.';

  @override
  String get snippetEnable => 'Enable';

  @override
  String get snippetDisable => 'Disable';

  @override
  String get snippetUsage => 'Usage';

  @override
  String get foldersTitle => 'Folders';

  @override
  String get foldersEmpty => 'No folders yet';

  @override
  String get foldersNew => 'New Folder';

  @override
  String get foldersFreeLimit => 'Free version limit';

  @override
  String get foldersRename => 'Rename folder';

  @override
  String get playgroundTitle => '✨ Smart Expander Playground';

  @override
  String playgroundHintText(Object trigger) {
    return 'Enter a trigger (e.g. $trigger) then press space...';
  }

  @override
  String get playgroundHelperText =>
      'Tip: ;;email → outputs ;email (escape). Triggers only expand after Space/Enter/punctuation.';

  @override
  String get playgroundNoSnippets =>
      'No snippets yet. Create snippets in the \"Snippet\" tab first, then come back to try shortcuts!';

  @override
  String playgroundPrefixDefault(Object prefix) {
    return 'Default prefix: \"$prefix\" (Pro: customizable)';
  }

  @override
  String get playgroundKeyboardEnabled => 'Smart Clipboard keyboard enabled';

  @override
  String get playgroundKeyboardDisabled =>
      '💡 Enable Smart Clipboard keyboard to use it in all apps!';

  @override
  String get playgroundKeyboardSubtitle =>
      '🔧 Feature coming in Phase 1 — currently only available in Playground';

  @override
  String get playgroundKeyboardPhase0 =>
      'Smart Clipboard keyboard not available in Phase 0. Under development!';

  @override
  String playgroundExpanded(Object trigger) {
    return 'Expanded $trigger';
  }

  @override
  String get playgroundCopyResult => 'Copy result';

  @override
  String get playgroundCopied => 'Copied';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsPauseLogging => 'Pause Clipboard History logging';

  @override
  String get settingsAutoDelete => 'Auto-delete history after';

  @override
  String get settingsBiometricLock => 'Lock app with biometrics';

  @override
  String get settingsBiometricSubtitle => 'Fingerprint/Face — Free version';

  @override
  String get settingsBiometricNotSupported =>
      'Device does not support biometrics or not configured';

  @override
  String get settingsSensitiveDetection => 'Sensitive data detection';

  @override
  String get settingsSensitiveSubtitle =>
      '⚠️ HEURISTIC ONLY (regex + entropy) for SUGGESTIONS — NOT a security guarantee. High entropy could just be a random ID.';

  @override
  String get settingsExportBackup => 'Export encrypted backup (AES-256-GCM)';

  @override
  String get settingsExportSubtitle =>
      'Key derived from your passphrase via PBKDF2 (≥100k iterations). Remember your passphrase — no one can restore without it!';

  @override
  String get settingsRestoreBackup => 'Restore from backup file';

  @override
  String get settingsBackupSection => 'Backup & Restore';

  @override
  String get settingsSecuritySection => 'Security';

  @override
  String get settingsCaptureSection => 'Logging';

  @override
  String get settingsStatsSection => 'Statistics (local only)';

  @override
  String get settingsKeyboardBgColor => 'Keyboard background color';

  @override
  String get exportDialogPassphraseTitle => 'Enter passphrase for backup';

  @override
  String get exportDialogPassphraseLabel => 'Passphrase (your choice)';

  @override
  String get exportDialogPassphraseWarning =>
      'Encryption key is derived from this passphrase. FORGETTING PASSPHRASE = CANNOT RESTORE. Salt + nonce are stored in the file.';

  @override
  String get exportPassphraseTooShort =>
      'Passphrase must be at least 8 characters.';

  @override
  String exportSuccess(Object path) {
    return 'Exported: $path';
  }

  @override
  String get exportFailed => 'Export failed. Please try again.';

  @override
  String get exportInProgress => 'Exporting... Please wait.';

  @override
  String get restoreDialogTitle => 'Restore from backup';

  @override
  String get restoreDialogPathLabel => 'Backup file path (.scbak)';

  @override
  String get restoreDialogPathHelper =>
      'e.g. /data/user/0/.../files/smart_clipboard_backup_....scbak';

  @override
  String get restoreDialogPassphraseLabel => 'Passphrase';

  @override
  String get restoreDialogWarning =>
      '⚠️ Restore will REPLACE all current data in the app.';

  @override
  String get restorePathEmpty => 'Please enter backup file path.';

  @override
  String get restoreSuccess => 'Restore successful!';

  @override
  String get restoreFailed => 'Restore failed. Check file/passphrase.';

  @override
  String get restoreInProgress => 'Restoring... Do not close this dialog.';

  @override
  String get statsSnippetsCreated => 'Snippets created';

  @override
  String get statsExpansions => 'Expansions';

  @override
  String get statsClipboardSaved => 'Clipboard saved';

  @override
  String get statsClipboardReused => 'Clipboard reused';

  @override
  String get statsPlaygroundExpansions => 'Playground expansions';

  @override
  String get statsActiveDays => 'Active days';

  @override
  String statsPerDay(Object value) {
    return 'Expansions / active day: $value\n≥ 1 → Text Expander habit formed (Go Phase 1 criteria — spec section 10)';
  }

  @override
  String get highRiskTitle => 'Content may be sensitive ⚠️';

  @override
  String get highRiskContent =>
      'Clipboard content looks like OTP / password / API key.\n\nSave to history? If saved, will auto-delete after 24h.\n\n(This detection is heuristic only, not a security guarantee.)';

  @override
  String get highRiskDontSave => 'Don\'t save';

  @override
  String get highRiskSaveAndDelete => 'Save & delete after 24h';

  @override
  String shareReceived(Object length) {
    return 'Shared text ($length characters)';
  }

  @override
  String get shareSaveToHistory => 'Save to Clipboard History';

  @override
  String get shareCreateSnippet => 'Create Snippet with trigger';

  @override
  String get onboardingTitle1 => 'Smart Clipboard';

  @override
  String get onboardingSubtitle1 => 'Save once. Paste anywhere.';

  @override
  String get onboardingTitle2 => 'Text expander everywhere';

  @override
  String get onboardingSubtitle2 =>
      'Type ;email → expands to your email. Works in any app!';

  @override
  String get onboardingTitle3 => 'Privacy first';

  @override
  String get onboardingSubtitle3 =>
      '100% local. No cloud. Your data never leaves your device.';

  @override
  String get onboardingTitle4 => 'Enable keyboard';

  @override
  String get onboardingSubtitle4 =>
      'This feature will be available in the next update.';

  @override
  String get onboardingSkipHint => 'You can skip this and come back later.';

  @override
  String get onboardingEnableKeyboard => 'Enable keyboard (Phase 1)';

  @override
  String get onboardingGetStarted => 'Get Started';

  @override
  String get lockGateTitle => 'Smart Clipboard is locked';

  @override
  String get lockGateSubtitle => 'Authenticate to unlock';

  @override
  String get proUpgradeTitle => 'Smart Clipboard Pro';

  @override
  String get proUpgradeSubtitle => 'Upgrade to Pro to unlock everything';

  @override
  String get proUpgradePrice => 'Lifetime purchase';

  @override
  String get appLanguage => 'App language';

  @override
  String get appLanguageSubtitle => 'Choose your preferred language';

  @override
  String get langVietnamese => 'Vietnamese';

  @override
  String get langEnglish => 'English';

  @override
  String get timeAgoJustNow => 'just now';

  @override
  String timeAgoMinutes(Object minutes) {
    return '${minutes}m ago';
  }

  @override
  String timeAgoHours(Object hours) {
    return '${hours}h ago';
  }

  @override
  String timeAgoDays(Object days) {
    return '${days}d ago';
  }

  @override
  String get searchClipboardHint => 'Search clipboard...';

  @override
  String get searchSnippetsHint => 'Search snippets...';

  @override
  String get filterAll => 'All';

  @override
  String get filterFavorites => 'Favorites';

  @override
  String get filterPinned => 'Pinned';

  @override
  String get filterEnabled => 'Enabled';

  @override
  String get filterDisabled => 'Disabled';

  @override
  String get snippetEditTitle => 'Edit snippet';

  @override
  String get triggerLabel => 'Trigger';

  @override
  String triggerHelperText(Object trigger) {
    return 'Type ;$trigger + space to expand';
  }

  @override
  String get triggerErrorEmpty => 'Cannot be empty';

  @override
  String get triggerErrorInvalid =>
      'Trigger must be letters/numbers/symbols without spaces or punctuation';

  @override
  String get snippetDeleteConfirm =>
      'Delete this snippet? This cannot be undone.';

  @override
  String get privacyHeuristicHigh =>
      'Heuristic: text may contain sensitive data (OTP/password/API key?). Prediction only.';

  @override
  String get privacyHeuristicLow =>
      'Heuristic: text looks random, may be sensitive. Prediction only.';

  @override
  String get onboardingLocalFirstTitle => '100% Local-first';

  @override
  String get onboardingLocalFirstSubtitle =>
      'Clipboard and snippet content NEVER leaves your device.';

  @override
  String get onboardingSecurityTitle => 'Android security warning';

  @override
  String get onboardingSecurityBody =>
      'Android will show a standard security warning for every keyboard: \'This keyboard can read everything you type, including passwords and card numbers.\'';

  @override
  String get onboardingSecurityNote =>
      'This is Android\'s default warning for ALL keyboards, not specific to Smart Clipboard.';

  @override
  String get onboardingPrivacySubtitle =>
      'Your clipboard/snippet content never leaves your device. Network is only used for ads (not personalized by your copied content) and anonymous error reporting.';

  @override
  String get onboardingNoPasswordTitle => 'No password storage';

  @override
  String get onboardingNoPasswordSubtitle =>
      'The keyboard does not read/save content from system password fields. If you copy a password to the clipboard, use Incognito Mode or delete it manually after use.';

  @override
  String get onboardingOemTitle => 'Tips for Xiaomi / Oppo / Samsung devices';

  @override
  String get onboardingOemBody =>
      'Some devices (MIUI, ColorOS, One UI) have strict battery management that may prevent the keyboard/snippets from updating in time.\n\nRecommended:\n• Settings > Battery > Battery optimization\n• Select Smart Clipboard → \"No restrictions\" (No optimization)\n• MIUI: add the app to the auto-start protection list';

  @override
  String get onboardingKeyboardEnabledNotActive =>
      'Keyboard enabled! Tap below to switch to Smart Clipboard.';

  @override
  String get onboardingKeyboardActive =>
      'Smart Clipboard is your active keyboard!';

  @override
  String get onboardingSwitchKeyboard => 'Switch to Smart Clipboard';

  @override
  String get playgroundTapToSwitch => 'Tap to switch to Smart Clipboard';

  @override
  String get playgroundActiveSubtitle =>
      'Try typing ;email + Space in Telegram';

  @override
  String get btnSwitch => 'Switch';

  @override
  String get langSystem => 'System';

  @override
  String get settingsProSection => 'Pro';

  @override
  String get settingsAppearanceSection => 'Appearance';

  @override
  String get themeSystem => 'System';

  @override
  String get themeSystemSubtitle => 'Follow device setting';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get colorWhite => 'White';

  @override
  String get colorGray => 'Gray';

  @override
  String get colorBlue => 'Blue';

  @override
  String get colorBlack => 'Black';

  @override
  String get proActiveTitle => '✨ Pro Active';

  @override
  String proActiveUntil(Object time) {
    return 'Available until $time';
  }

  @override
  String get proUnlockTitle => '✨ Unlock Pro for today';

  @override
  String get proUnlockSubtitle =>
      'Watch a short ad to unlock all Pro features for 24 hours';

  @override
  String get btnWatchAd => 'Watch Ad';

  @override
  String get proUnlockedSnackbar => '✨ Pro unlocked for 24 hours!';

  @override
  String get adFailedSnackbar => 'Ad failed to load. Please try again.';

  @override
  String get backupErrorWebUnsupported =>
      'Backup/Restore is not available on web.';

  @override
  String get backupErrorFileNotFound => 'Backup file does not exist.';

  @override
  String get backupErrorInvalidFormat =>
      'Backup file is not in the correct format.';

  @override
  String get backupErrorNotAppBackup =>
      'This is not a backup file from this app.';

  @override
  String get backupErrorInvalidKdf => 'Invalid KDF iterations.';

  @override
  String get backupErrorDecrypt =>
      'Wrong passphrase or corrupted file. Cannot decrypt.';

  @override
  String get lockGateBiometricReason => 'Authenticate to open Smart Clipboard';
}
