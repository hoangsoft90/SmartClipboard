import 'package:flutter/widgets.dart';

import 'app_localizations_en.dart';
import 'app_localizations_vi.dart';

/// Smart Clipboard localization — simplified generated-style class.
/// Matches the API of flutter gen-l10n output for easy migration.
class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('vi'),
  ];

  late final Map<String, String> _strings = _loadStrings();

  Map<String, String> _loadStrings() {
    switch (locale.languageCode) {
      case 'vi':
        return appStringsVi;
      case 'en':
      default:
        return appStringsEn;
    }
  }

  String _t(String key, [Map<String, String>? params]) {
    var value = _strings[key] ?? key;
    if (params != null) {
      for (final entry in params.entries) {
        value = value.replaceAll('{${entry.key}}', entry.value);
      }
    }
    return value;
  }

  // ---- Navigation ----
  String get appTitle => _t('appTitle');
  String get tabClipboard => _t('tabClipboard');
  String get tabSnippets => _t('tabSnippets');
  String get tabPlayground => _t('tabPlayground');
  String get tabSettings => _t('tabSettings');

  // ---- Common buttons ----
  String get btnEnable => _t('btnEnable');
  String get btnCancel => _t('btnCancel');
  String get btnSave => _t('btnSave');
  String get btnCreate => _t('btnCreate');
  String get btnExport => _t('btnExport');
  String get btnRestore => _t('btnRestore');
  String get btnExit => _t('btnExit');
  String get btnStay => _t('btnStay');
  String get btnSkip => _t('btnSkip');
  String get btnLater => _t('btnLater');
  String get btnCopy => _t('btnCopy');
  String get btnRename => _t('btnRename');
  String get btnDelete => _t('btnDelete');
  String get btnClose => _t('btnClose');
  String get btnBack => _t('btnBack');
  String get btnDone => _t('btnDone');
  String get btnNext => _t('btnNext');

  // ---- Clipboard History ----
  String get clipboardHistoryTitle => _t('clipboardHistoryTitle');
  String get clipboardEmpty => _t('clipboardEmpty');
  String get clipboardLoadError => _t('clipboardLoadError');
  String get clipboardCopied => _t('clipboardCopied');
  String get clipboardSavedToHistory => _t('clipboardSavedToHistory');
  String get clipboardPaused => _t('clipboardPaused');
  String get clipboardPauseResumeTooltip => _t('clipboardPauseResumeTooltip');
  String get clipboardPauseTooltip => _t('clipboardPauseTooltip');
  String get clipboardPauseSubtitle => _t('clipboardPauseSubtitle');
  String get clipboardAutoDelete => _t('clipboardAutoDelete');
  String get clipboardAutoDeleteSubtitle => _t('clipboardAutoDeleteSubtitle');

  // ---- Popup menu ----
  String get popupCopyAgain => _t('popupCopyAgain');
  String get popupSaveAsSnippet => _t('popupSaveAsSnippet');
  String get popupDeleteAfter24h => _t('popupDeleteAfter24h');
  String get popupHideFromHistory => _t('popupHideFromHistory');
  String get popupDeletePermanently => _t('popupDeletePermanently');
  String get popupPin => _t('popupPin');
  String get popupUnpin => _t('popupUnpin');
  String get popupFavorite => _t('popupFavorite');
  String get popupUnfavorite => _t('popupUnfavorite');

  // ---- Snippets ----
  String get snippetsTitle => _t('snippetsTitle');
  String get snippetsEmpty => _t('snippetsEmpty');
  String get snippetsNew => _t('snippetsNew');
  String get snippetNewTitle => _t('snippetNewTitle');
  String get snippetTitleLabel => _t('snippetTitleLabel');
  String get snippetTriggerLabel => _t('snippetTriggerLabel');
  String get snippetTriggerPrefix => _t('snippetTriggerPrefix');
  String get snippetContentLabel => _t('snippetContentLabel');
  String get snippetFolderOptional => _t('snippetFolderOptional');
  String get snippetCreated => _t('snippetCreated');
  String snippetCreatedWithArchived(int count) =>
      _t('snippetCreatedWithArchived', {'count': '$count'});
  String get snippetDeleteTitle => _t('snippetDeleteTitle');
  String get snippetDiscardTitle => _t('snippetDiscardTitle');
  String get snippetDiscardContent => _t('snippetDiscardContent');
  String get snippetEnable => _t('snippetEnable');
  String get snippetDisable => _t('snippetDisable');
  String get snippetUsage => _t('snippetUsage');

  // ---- Folders ----
  String get foldersTitle => _t('foldersTitle');
  String get foldersEmpty => _t('foldersEmpty');
  String get foldersNew => _t('foldersNew');
  String get foldersFreeLimit => _t('foldersFreeLimit');
  String get foldersRename => _t('foldersRename');

  // ---- Playground ----
  String get playgroundTitle => _t('playgroundTitle');
  String playgroundHintText(String trigger) =>
      _t('playgroundHintText', {'trigger': trigger});
  String get playgroundHelperText => _t('playgroundHelperText');
  String get playgroundNoSnippets => _t('playgroundNoSnippets');
  String playgroundPrefixDefault(String prefix) =>
      _t('playgroundPrefixDefault', {'prefix': prefix});
  String get playgroundKeyboardEnabled => _t('playgroundKeyboardEnabled');
  String get playgroundKeyboardDisabled => _t('playgroundKeyboardDisabled');
  String get playgroundKeyboardSubtitle => _t('playgroundKeyboardSubtitle');
  String get playgroundKeyboardPhase0 => _t('playgroundKeyboardPhase0');
  String playgroundExpanded(String trigger) =>
      _t('playgroundExpanded', {'trigger': trigger});
  String get playgroundCopyResult => _t('playgroundCopyResult');
  String get playgroundCopied => _t('playgroundCopied');

  // ---- Settings ----
  String get settingsTitle => _t('settingsTitle');
  String get settingsPauseLogging => _t('settingsPauseLogging');
  String get settingsAutoDelete => _t('settingsAutoDelete');
  String get settingsBiometricLock => _t('settingsBiometricLock');
  String get settingsBiometricSubtitle => _t('settingsBiometricSubtitle');
  String get settingsBiometricNotSupported =>
      _t('settingsBiometricNotSupported');
  String get settingsSensitiveDetection => _t('settingsSensitiveDetection');
  String get settingsSensitiveSubtitle => _t('settingsSensitiveSubtitle');
  String get settingsExportBackup => _t('settingsExportBackup');
  String get settingsExportSubtitle => _t('settingsExportSubtitle');
  String get settingsRestoreBackup => _t('settingsRestoreBackup');
  String get settingsBackupSection => _t('settingsBackupSection');
  String get settingsSecuritySection => _t('settingsSecuritySection');
  String get settingsCaptureSection => _t('settingsCaptureSection');
  String get settingsStatsSection => _t('settingsStatsSection');
  String get settingsKeyboardBgColor => _t('settingsKeyboardBgColor');

  // ---- Export/Restore dialogs ----
  String get exportDialogPassphraseTitle =>
      _t('exportDialogPassphraseTitle');
  String get exportDialogPassphraseLabel =>
      _t('exportDialogPassphraseLabel');
  String get exportDialogPassphraseWarning =>
      _t('exportDialogPassphraseWarning');
  String get exportPassphraseTooShort => _t('exportPassphraseTooShort');
  String exportSuccess(String path) =>
      _t('exportSuccess', {'path': path});
  String get exportFailed => _t('exportFailed');
  String get exportInProgress => _t('exportInProgress');

  String get restoreDialogTitle => _t('restoreDialogTitle');
  String get restoreDialogPathLabel => _t('restoreDialogPathLabel');
  String get restoreDialogPathHelper => _t('restoreDialogPathHelper');
  String get restoreDialogPassphraseLabel =>
      _t('restoreDialogPassphraseLabel');
  String get restoreDialogWarning => _t('restoreDialogWarning');
  String get restorePathEmpty => _t('restorePathEmpty');
  String get restoreSuccess => _t('restoreSuccess');
  String get restoreFailed => _t('restoreFailed');
  String get restoreInProgress => _t('restoreInProgress');

  // ---- Stats ----
  String get statsSnippetsCreated => _t('statsSnippetsCreated');
  String get statsExpansions => _t('statsExpansions');
  String get statsClipboardSaved => _t('statsClipboardSaved');
  String get statsClipboardReused => _t('statsClipboardReused');
  String get statsPlaygroundExpansions => _t('statsPlaygroundExpansions');
  String get statsActiveDays => _t('statsActiveDays');
  String statsPerDay(String value) =>
      _t('statsPerDay', {'value': value});

  // ---- High Risk dialog ----
  String get highRiskTitle => _t('highRiskTitle');
  String get highRiskContent => _t('highRiskContent');
  String get highRiskDontSave => _t('highRiskDontSave');
  String get highRiskSaveAndDelete => _t('highRiskSaveAndDelete');

  // ---- Share Intent ----
  String shareReceived(int length) =>
      _t('shareReceived', {'length': '$length'});
  String get shareSaveToHistory => _t('shareSaveToHistory');
  String get shareCreateSnippet => _t('shareCreateSnippet');

  // ---- Onboarding ----
  String get onboardingTitle1 => _t('onboardingTitle1');
  String get onboardingSubtitle1 => _t('onboardingSubtitle1');
  String get onboardingTitle2 => _t('onboardingTitle2');
  String get onboardingSubtitle2 => _t('onboardingSubtitle2');
  String get onboardingTitle3 => _t('onboardingTitle3');
  String get onboardingSubtitle3 => _t('onboardingSubtitle3');
  String get onboardingTitle4 => _t('onboardingTitle4');
  String get onboardingSubtitle4 => _t('onboardingSubtitle4');
  String get onboardingSkipHint => _t('onboardingSkipHint');
  String get onboardingEnableKeyboard => _t('onboardingEnableKeyboard');
  String get onboardingGetStarted => _t('onboardingGetStarted');

  // ---- Lock Gate ----
  String get lockGateTitle => _t('lockGateTitle');
  String get lockGateSubtitle => _t('lockGateSubtitle');

  // ---- Pro Upgrade ----
  String get proUpgradeTitle => _t('proUpgradeTitle');
  String get proUpgradeSubtitle => _t('proUpgradeSubtitle');
  String get proUpgradePrice => _t('proUpgradePrice');

  // ---- Language ----
  String get appLanguage => _t('appLanguage');
  String get appLanguageSubtitle => _t('appLanguageSubtitle');
  String get langVietnamese => _t('langVietnamese');
  String get langEnglish => _t('langEnglish');

  // ---- Time ago ----
  String get timeAgoJustNow => _t('timeAgoJustNow');
  String timeAgoMinutes(int minutes) =>
      _t('timeAgoMinutes', {'minutes': '$minutes'});
  String timeAgoHours(int hours) =>
      _t('timeAgoHours', {'hours': '$hours'});
  String timeAgoDays(int days) =>
      _t('timeAgoDays', {'days': '$days'});
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['en', 'vi'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
