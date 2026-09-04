import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('vi')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Smart Clipboard'**
  String get appTitle;

  /// No description provided for @tabClipboard.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get tabClipboard;

  /// No description provided for @tabSnippets.
  ///
  /// In en, this message translates to:
  /// **'Snippet'**
  String get tabSnippets;

  /// No description provided for @tabPlayground.
  ///
  /// In en, this message translates to:
  /// **'Playground'**
  String get tabPlayground;

  /// No description provided for @tabSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get tabSettings;

  /// No description provided for @btnEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get btnEnable;

  /// No description provided for @btnCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get btnCancel;

  /// No description provided for @btnSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get btnSave;

  /// No description provided for @btnCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get btnCreate;

  /// No description provided for @btnExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get btnExport;

  /// No description provided for @btnRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get btnRestore;

  /// No description provided for @btnExit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get btnExit;

  /// No description provided for @btnStay.
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get btnStay;

  /// No description provided for @btnSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get btnSkip;

  /// No description provided for @btnLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get btnLater;

  /// No description provided for @btnCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get btnCopy;

  /// No description provided for @btnRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get btnRename;

  /// No description provided for @btnEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get btnEdit;

  /// No description provided for @btnDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get btnDelete;

  /// No description provided for @btnClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get btnClose;

  /// No description provided for @btnBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get btnBack;

  /// No description provided for @btnDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get btnDone;

  /// No description provided for @btnNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get btnNext;

  /// No description provided for @clipboardHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Clipboard History'**
  String get clipboardHistoryTitle;

  /// No description provided for @clipboardEmpty.
  ///
  /// In en, this message translates to:
  /// **'No content yet.\nSwitch to another app and come back to save clipboard.'**
  String get clipboardEmpty;

  /// No description provided for @clipboardLoadError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load data'**
  String get clipboardLoadError;

  /// No description provided for @clipboardCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get clipboardCopied;

  /// No description provided for @clipboardSavedToHistory.
  ///
  /// In en, this message translates to:
  /// **'Saved to history'**
  String get clipboardSavedToHistory;

  /// No description provided for @clipboardPaused.
  ///
  /// In en, this message translates to:
  /// **'CLIPBOARD LOGGING PAUSED'**
  String get clipboardPaused;

  /// No description provided for @clipboardPauseResumeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Resume clipboard logging'**
  String get clipboardPauseResumeTooltip;

  /// No description provided for @clipboardPauseTooltip.
  ///
  /// In en, this message translates to:
  /// **'Pause clipboard logging (Incognito)'**
  String get clipboardPauseTooltip;

  /// No description provided for @clipboardPauseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Incognito/Pause Mode — one-tap pause, no background logging'**
  String get clipboardPauseSubtitle;

  /// No description provided for @clipboardAutoDelete.
  ///
  /// In en, this message translates to:
  /// **'Auto-delete history after'**
  String get clipboardAutoDelete;

  /// No description provided for @clipboardAutoDeleteSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-Expiration Engine (1/7/30 days)'**
  String get clipboardAutoDeleteSubtitle;

  /// No description provided for @clipboardAutoDeleteOption.
  ///
  /// In en, this message translates to:
  /// **'{days} days'**
  String clipboardAutoDeleteOption(Object days);

  /// No description provided for @popupCopyAgain.
  ///
  /// In en, this message translates to:
  /// **'Copy again'**
  String get popupCopyAgain;

  /// No description provided for @popupSaveAsSnippet.
  ///
  /// In en, this message translates to:
  /// **'Save as Snippet'**
  String get popupSaveAsSnippet;

  /// No description provided for @popupDeleteAfter24h.
  ///
  /// In en, this message translates to:
  /// **'Delete after 24h ⚠️ heuristic'**
  String get popupDeleteAfter24h;

  /// No description provided for @popupHideFromHistory.
  ///
  /// In en, this message translates to:
  /// **'Hide from history'**
  String get popupHideFromHistory;

  /// No description provided for @popupDeletePermanently.
  ///
  /// In en, this message translates to:
  /// **'Delete permanently'**
  String get popupDeletePermanently;

  /// No description provided for @popupPin.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get popupPin;

  /// No description provided for @popupUnpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get popupUnpin;

  /// No description provided for @popupFavorite.
  ///
  /// In en, this message translates to:
  /// **'Favorite'**
  String get popupFavorite;

  /// No description provided for @popupUnfavorite.
  ///
  /// In en, this message translates to:
  /// **'Unfavorite'**
  String get popupUnfavorite;

  /// No description provided for @snippetsTitle.
  ///
  /// In en, this message translates to:
  /// **'Snippets (Text Expander)'**
  String get snippetsTitle;

  /// No description provided for @snippetsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No snippets yet.\nCreate a snippet first, then come back to try text expansion!'**
  String get snippetsEmpty;

  /// No description provided for @snippetsNew.
  ///
  /// In en, this message translates to:
  /// **'New Snippet'**
  String get snippetsNew;

  /// No description provided for @snippetNewTitle.
  ///
  /// In en, this message translates to:
  /// **'Create new snippet'**
  String get snippetNewTitle;

  /// No description provided for @snippetTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Name (e.g. Work email)'**
  String get snippetTitleLabel;

  /// No description provided for @snippetTriggerLabel.
  ///
  /// In en, this message translates to:
  /// **'Trigger without spaces (e.g. email)'**
  String get snippetTriggerLabel;

  /// No description provided for @snippetTriggerPrefix.
  ///
  /// In en, this message translates to:
  /// **'Trigger prefix'**
  String get snippetTriggerPrefix;

  /// No description provided for @snippetContentLabel.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get snippetContentLabel;

  /// No description provided for @snippetFolderOptional.
  ///
  /// In en, this message translates to:
  /// **'Folder (optional)'**
  String get snippetFolderOptional;

  /// No description provided for @snippetCreated.
  ///
  /// In en, this message translates to:
  /// **'Snippet created'**
  String get snippetCreated;

  /// No description provided for @snippetCreatedWithArchived.
  ///
  /// In en, this message translates to:
  /// **'Snippet created. {count} old snippet(s) hidden due to Free limit — upgrade to Pro to unlock.'**
  String snippetCreatedWithArchived(Object count);

  /// No description provided for @snippetDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete snippet?'**
  String get snippetDeleteTitle;

  /// No description provided for @snippetDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Exit without saving?'**
  String get snippetDiscardTitle;

  /// No description provided for @snippetDiscardContent.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes. Exiting will lose them.'**
  String get snippetDiscardContent;

  /// No description provided for @snippetEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get snippetEnable;

  /// No description provided for @snippetDisable.
  ///
  /// In en, this message translates to:
  /// **'Disable'**
  String get snippetDisable;

  /// No description provided for @snippetUsage.
  ///
  /// In en, this message translates to:
  /// **'Usage'**
  String get snippetUsage;

  /// No description provided for @foldersTitle.
  ///
  /// In en, this message translates to:
  /// **'Folders'**
  String get foldersTitle;

  /// No description provided for @foldersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No folders yet'**
  String get foldersEmpty;

  /// No description provided for @foldersNew.
  ///
  /// In en, this message translates to:
  /// **'New Folder'**
  String get foldersNew;

  /// No description provided for @foldersFreeLimit.
  ///
  /// In en, this message translates to:
  /// **'Free version limit'**
  String get foldersFreeLimit;

  /// No description provided for @foldersRename.
  ///
  /// In en, this message translates to:
  /// **'Rename folder'**
  String get foldersRename;

  /// No description provided for @playgroundTitle.
  ///
  /// In en, this message translates to:
  /// **'✨ Smart Expander Playground'**
  String get playgroundTitle;

  /// No description provided for @playgroundHintText.
  ///
  /// In en, this message translates to:
  /// **'Enter a trigger (e.g. {trigger}) then press space...'**
  String playgroundHintText(Object trigger);

  /// No description provided for @playgroundHelperText.
  ///
  /// In en, this message translates to:
  /// **'Tip: ;;email → outputs ;email (escape). Triggers only expand after Space/Enter/punctuation.'**
  String get playgroundHelperText;

  /// No description provided for @playgroundNoSnippets.
  ///
  /// In en, this message translates to:
  /// **'No snippets yet. Create snippets in the \"Snippet\" tab first, then come back to try shortcuts!'**
  String get playgroundNoSnippets;

  /// No description provided for @playgroundPrefixDefault.
  ///
  /// In en, this message translates to:
  /// **'Default prefix: \"{prefix}\" (Pro: customizable)'**
  String playgroundPrefixDefault(Object prefix);

  /// No description provided for @playgroundKeyboardEnabled.
  ///
  /// In en, this message translates to:
  /// **'Smart Clipboard keyboard enabled'**
  String get playgroundKeyboardEnabled;

  /// No description provided for @playgroundKeyboardDisabled.
  ///
  /// In en, this message translates to:
  /// **'💡 Enable Smart Clipboard keyboard to use it in all apps!'**
  String get playgroundKeyboardDisabled;

  /// No description provided for @playgroundKeyboardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'🔧 Feature coming in Phase 1 — currently only available in Playground'**
  String get playgroundKeyboardSubtitle;

  /// No description provided for @playgroundKeyboardPhase0.
  ///
  /// In en, this message translates to:
  /// **'Smart Clipboard keyboard not available in Phase 0. Under development!'**
  String get playgroundKeyboardPhase0;

  /// No description provided for @playgroundExpanded.
  ///
  /// In en, this message translates to:
  /// **'Expanded {trigger}'**
  String playgroundExpanded(Object trigger);

  /// No description provided for @playgroundCopyResult.
  ///
  /// In en, this message translates to:
  /// **'Copy result'**
  String get playgroundCopyResult;

  /// No description provided for @playgroundCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get playgroundCopied;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsPauseLogging.
  ///
  /// In en, this message translates to:
  /// **'Pause Clipboard History logging'**
  String get settingsPauseLogging;

  /// No description provided for @settingsAutoDelete.
  ///
  /// In en, this message translates to:
  /// **'Auto-delete history after'**
  String get settingsAutoDelete;

  /// No description provided for @settingsBiometricLock.
  ///
  /// In en, this message translates to:
  /// **'Lock app with biometrics'**
  String get settingsBiometricLock;

  /// No description provided for @settingsBiometricSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint/Face — Free version'**
  String get settingsBiometricSubtitle;

  /// No description provided for @settingsBiometricNotSupported.
  ///
  /// In en, this message translates to:
  /// **'Device does not support biometrics or not configured'**
  String get settingsBiometricNotSupported;

  /// No description provided for @settingsSensitiveDetection.
  ///
  /// In en, this message translates to:
  /// **'Sensitive data detection'**
  String get settingsSensitiveDetection;

  /// No description provided for @settingsSensitiveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'⚠️ HEURISTIC ONLY (regex + entropy) for SUGGESTIONS — NOT a security guarantee. High entropy could just be a random ID.'**
  String get settingsSensitiveSubtitle;

  /// No description provided for @settingsExportBackup.
  ///
  /// In en, this message translates to:
  /// **'Export encrypted backup (AES-256-GCM)'**
  String get settingsExportBackup;

  /// No description provided for @settingsExportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Key derived from your passphrase via PBKDF2 (≥100k iterations). Remember your passphrase — no one can restore without it!'**
  String get settingsExportSubtitle;

  /// No description provided for @settingsRestoreBackup.
  ///
  /// In en, this message translates to:
  /// **'Restore from backup file'**
  String get settingsRestoreBackup;

  /// No description provided for @settingsBackupSection.
  ///
  /// In en, this message translates to:
  /// **'Backup & Restore'**
  String get settingsBackupSection;

  /// No description provided for @settingsSecuritySection.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get settingsSecuritySection;

  /// No description provided for @settingsCaptureSection.
  ///
  /// In en, this message translates to:
  /// **'Logging'**
  String get settingsCaptureSection;

  /// No description provided for @settingsStatsSection.
  ///
  /// In en, this message translates to:
  /// **'Statistics (local only)'**
  String get settingsStatsSection;

  /// No description provided for @settingsKeyboardBgColor.
  ///
  /// In en, this message translates to:
  /// **'Keyboard background color'**
  String get settingsKeyboardBgColor;

  /// No description provided for @exportDialogPassphraseTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter passphrase for backup'**
  String get exportDialogPassphraseTitle;

  /// No description provided for @exportDialogPassphraseLabel.
  ///
  /// In en, this message translates to:
  /// **'Passphrase (your choice)'**
  String get exportDialogPassphraseLabel;

  /// No description provided for @exportDialogPassphraseWarning.
  ///
  /// In en, this message translates to:
  /// **'Encryption key is derived from this passphrase. FORGETTING PASSPHRASE = CANNOT RESTORE. Salt + nonce are stored in the file.'**
  String get exportDialogPassphraseWarning;

  /// No description provided for @exportPassphraseTooShort.
  ///
  /// In en, this message translates to:
  /// **'Passphrase must be at least 8 characters.'**
  String get exportPassphraseTooShort;

  /// No description provided for @exportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Exported: {path}'**
  String exportSuccess(Object path);

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed. Please try again.'**
  String get exportFailed;

  /// No description provided for @exportInProgress.
  ///
  /// In en, this message translates to:
  /// **'Exporting... Please wait.'**
  String get exportInProgress;

  /// No description provided for @restoreDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore from backup'**
  String get restoreDialogTitle;

  /// No description provided for @restoreDialogPathLabel.
  ///
  /// In en, this message translates to:
  /// **'Backup file path (.scbak)'**
  String get restoreDialogPathLabel;

  /// No description provided for @restoreDialogPathHelper.
  ///
  /// In en, this message translates to:
  /// **'e.g. /data/user/0/.../files/smart_clipboard_backup_....scbak'**
  String get restoreDialogPathHelper;

  /// No description provided for @restoreDialogPassphraseLabel.
  ///
  /// In en, this message translates to:
  /// **'Passphrase'**
  String get restoreDialogPassphraseLabel;

  /// No description provided for @restoreDialogWarning.
  ///
  /// In en, this message translates to:
  /// **'⚠️ Restore will REPLACE all current data in the app.'**
  String get restoreDialogWarning;

  /// No description provided for @restorePathEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please enter backup file path.'**
  String get restorePathEmpty;

  /// No description provided for @restoreSuccess.
  ///
  /// In en, this message translates to:
  /// **'Restore successful!'**
  String get restoreSuccess;

  /// No description provided for @restoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Restore failed. Check file/passphrase.'**
  String get restoreFailed;

  /// No description provided for @restoreInProgress.
  ///
  /// In en, this message translates to:
  /// **'Restoring... Do not close this dialog.'**
  String get restoreInProgress;

  /// No description provided for @statsSnippetsCreated.
  ///
  /// In en, this message translates to:
  /// **'Snippets created'**
  String get statsSnippetsCreated;

  /// No description provided for @statsExpansions.
  ///
  /// In en, this message translates to:
  /// **'Expansions'**
  String get statsExpansions;

  /// No description provided for @statsClipboardSaved.
  ///
  /// In en, this message translates to:
  /// **'Clipboard saved'**
  String get statsClipboardSaved;

  /// No description provided for @statsClipboardReused.
  ///
  /// In en, this message translates to:
  /// **'Clipboard reused'**
  String get statsClipboardReused;

  /// No description provided for @statsPlaygroundExpansions.
  ///
  /// In en, this message translates to:
  /// **'Playground expansions'**
  String get statsPlaygroundExpansions;

  /// No description provided for @statsActiveDays.
  ///
  /// In en, this message translates to:
  /// **'Active days'**
  String get statsActiveDays;

  /// No description provided for @statsPerDay.
  ///
  /// In en, this message translates to:
  /// **'Expansions / active day: {value}\n≥ 1 → Text Expander habit formed (Go Phase 1 criteria — spec section 10)'**
  String statsPerDay(Object value);

  /// No description provided for @highRiskTitle.
  ///
  /// In en, this message translates to:
  /// **'Content may be sensitive ⚠️'**
  String get highRiskTitle;

  /// No description provided for @highRiskContent.
  ///
  /// In en, this message translates to:
  /// **'Clipboard content looks like OTP / password / API key.\n\nSave to history? If saved, will auto-delete after 24h.\n\n(This detection is heuristic only, not a security guarantee.)'**
  String get highRiskContent;

  /// No description provided for @highRiskDontSave.
  ///
  /// In en, this message translates to:
  /// **'Don\'t save'**
  String get highRiskDontSave;

  /// No description provided for @highRiskSaveAndDelete.
  ///
  /// In en, this message translates to:
  /// **'Save & delete after 24h'**
  String get highRiskSaveAndDelete;

  /// No description provided for @shareReceived.
  ///
  /// In en, this message translates to:
  /// **'Shared text ({length} characters)'**
  String shareReceived(Object length);

  /// No description provided for @shareSaveToHistory.
  ///
  /// In en, this message translates to:
  /// **'Save to Clipboard History'**
  String get shareSaveToHistory;

  /// No description provided for @shareCreateSnippet.
  ///
  /// In en, this message translates to:
  /// **'Create Snippet with trigger'**
  String get shareCreateSnippet;

  /// No description provided for @onboardingTitle1.
  ///
  /// In en, this message translates to:
  /// **'Smart Clipboard'**
  String get onboardingTitle1;

  /// No description provided for @onboardingSubtitle1.
  ///
  /// In en, this message translates to:
  /// **'Save once. Paste anywhere.'**
  String get onboardingSubtitle1;

  /// No description provided for @onboardingTitle2.
  ///
  /// In en, this message translates to:
  /// **'Text expander everywhere'**
  String get onboardingTitle2;

  /// No description provided for @onboardingSubtitle2.
  ///
  /// In en, this message translates to:
  /// **'Type ;email → expands to your email. Works in any app!'**
  String get onboardingSubtitle2;

  /// No description provided for @onboardingTitle3.
  ///
  /// In en, this message translates to:
  /// **'Privacy first'**
  String get onboardingTitle3;

  /// No description provided for @onboardingSubtitle3.
  ///
  /// In en, this message translates to:
  /// **'100% local. No cloud. Your data never leaves your device.'**
  String get onboardingSubtitle3;

  /// No description provided for @onboardingTitle4.
  ///
  /// In en, this message translates to:
  /// **'Enable keyboard'**
  String get onboardingTitle4;

  /// No description provided for @onboardingSubtitle4.
  ///
  /// In en, this message translates to:
  /// **'This feature will be available in the next update.'**
  String get onboardingSubtitle4;

  /// No description provided for @onboardingSkipHint.
  ///
  /// In en, this message translates to:
  /// **'You can skip this and come back later.'**
  String get onboardingSkipHint;

  /// No description provided for @onboardingEnableKeyboard.
  ///
  /// In en, this message translates to:
  /// **'Enable keyboard (Phase 1)'**
  String get onboardingEnableKeyboard;

  /// No description provided for @onboardingGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get onboardingGetStarted;

  /// No description provided for @lockGateTitle.
  ///
  /// In en, this message translates to:
  /// **'Smart Clipboard is locked'**
  String get lockGateTitle;

  /// No description provided for @lockGateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Authenticate to unlock'**
  String get lockGateSubtitle;

  /// No description provided for @proUpgradeTitle.
  ///
  /// In en, this message translates to:
  /// **'Smart Clipboard Pro'**
  String get proUpgradeTitle;

  /// No description provided for @proUpgradeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Pro to unlock everything'**
  String get proUpgradeSubtitle;

  /// No description provided for @proUpgradePrice.
  ///
  /// In en, this message translates to:
  /// **'Lifetime purchase'**
  String get proUpgradePrice;

  /// No description provided for @appLanguage.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get appLanguage;

  /// No description provided for @appLanguageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your preferred language'**
  String get appLanguageSubtitle;

  /// No description provided for @langVietnamese.
  ///
  /// In en, this message translates to:
  /// **'Vietnamese'**
  String get langVietnamese;

  /// No description provided for @langEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get langEnglish;

  /// No description provided for @timeAgoJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get timeAgoJustNow;

  /// No description provided for @timeAgoMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m ago'**
  String timeAgoMinutes(Object minutes);

  /// No description provided for @timeAgoHours.
  ///
  /// In en, this message translates to:
  /// **'{hours}h ago'**
  String timeAgoHours(Object hours);

  /// No description provided for @timeAgoDays.
  ///
  /// In en, this message translates to:
  /// **'{days}d ago'**
  String timeAgoDays(Object days);

  /// No description provided for @searchClipboardHint.
  ///
  /// In en, this message translates to:
  /// **'Search clipboard...'**
  String get searchClipboardHint;

  /// No description provided for @searchSnippetsHint.
  ///
  /// In en, this message translates to:
  /// **'Search snippets...'**
  String get searchSnippetsHint;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @filterFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get filterFavorites;

  /// No description provided for @filterPinned.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get filterPinned;

  /// No description provided for @filterEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get filterEnabled;

  /// No description provided for @filterDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get filterDisabled;

  /// No description provided for @snippetEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit snippet'**
  String get snippetEditTitle;

  /// No description provided for @triggerLabel.
  ///
  /// In en, this message translates to:
  /// **'Trigger'**
  String get triggerLabel;

  /// No description provided for @triggerHelperText.
  ///
  /// In en, this message translates to:
  /// **'Type ;{trigger} + space to expand'**
  String triggerHelperText(Object trigger);

  /// No description provided for @triggerErrorEmpty.
  ///
  /// In en, this message translates to:
  /// **'Cannot be empty'**
  String get triggerErrorEmpty;

  /// No description provided for @triggerErrorInvalid.
  ///
  /// In en, this message translates to:
  /// **'Trigger must be letters/numbers/symbols without spaces or punctuation'**
  String get triggerErrorInvalid;

  /// No description provided for @snippetDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this snippet? This cannot be undone.'**
  String get snippetDeleteConfirm;

  /// No description provided for @privacyHeuristicHigh.
  ///
  /// In en, this message translates to:
  /// **'Heuristic: text may contain sensitive data (OTP/password/API key?). Prediction only.'**
  String get privacyHeuristicHigh;

  /// No description provided for @privacyHeuristicLow.
  ///
  /// In en, this message translates to:
  /// **'Heuristic: text looks random, may be sensitive. Prediction only.'**
  String get privacyHeuristicLow;

  /// No description provided for @onboardingLocalFirstTitle.
  ///
  /// In en, this message translates to:
  /// **'100% Local-first'**
  String get onboardingLocalFirstTitle;

  /// No description provided for @onboardingLocalFirstSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Clipboard and snippet content NEVER leaves your device.'**
  String get onboardingLocalFirstSubtitle;

  /// No description provided for @onboardingSecurityTitle.
  ///
  /// In en, this message translates to:
  /// **'Android security warning'**
  String get onboardingSecurityTitle;

  /// No description provided for @onboardingSecurityBody.
  ///
  /// In en, this message translates to:
  /// **'Android will show a standard security warning for every keyboard: \'This keyboard can read everything you type, including passwords and card numbers.\''**
  String get onboardingSecurityBody;

  /// No description provided for @onboardingSecurityNote.
  ///
  /// In en, this message translates to:
  /// **'This is Android\'s default warning for ALL keyboards, not specific to Smart Clipboard.'**
  String get onboardingSecurityNote;

  /// No description provided for @onboardingPrivacySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your clipboard/snippet content never leaves your device. Network is only used for ads (not personalized by your copied content) and anonymous error reporting.'**
  String get onboardingPrivacySubtitle;

  /// No description provided for @onboardingNoPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'No password storage'**
  String get onboardingNoPasswordTitle;

  /// No description provided for @onboardingNoPasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The keyboard does not read/save content from system password fields. If you copy a password to the clipboard, use Incognito Mode or delete it manually after use.'**
  String get onboardingNoPasswordSubtitle;

  /// No description provided for @onboardingOemTitle.
  ///
  /// In en, this message translates to:
  /// **'Tips for Xiaomi / Oppo / Samsung devices'**
  String get onboardingOemTitle;

  /// No description provided for @onboardingOemBody.
  ///
  /// In en, this message translates to:
  /// **'Some devices (MIUI, ColorOS, One UI) have strict battery management that may prevent the keyboard/snippets from updating in time.\n\nRecommended:\n• Settings > Battery > Battery optimization\n• Select Smart Clipboard → \"No restrictions\" (No optimization)\n• MIUI: add the app to the auto-start protection list'**
  String get onboardingOemBody;

  /// No description provided for @onboardingKeyboardEnabledNotActive.
  ///
  /// In en, this message translates to:
  /// **'Keyboard enabled! Tap below to switch to Smart Clipboard.'**
  String get onboardingKeyboardEnabledNotActive;

  /// No description provided for @onboardingKeyboardActive.
  ///
  /// In en, this message translates to:
  /// **'Smart Clipboard is your active keyboard!'**
  String get onboardingKeyboardActive;

  /// No description provided for @onboardingSwitchKeyboard.
  ///
  /// In en, this message translates to:
  /// **'Switch to Smart Clipboard'**
  String get onboardingSwitchKeyboard;

  /// No description provided for @playgroundTapToSwitch.
  ///
  /// In en, this message translates to:
  /// **'Tap to switch to Smart Clipboard'**
  String get playgroundTapToSwitch;

  /// No description provided for @playgroundActiveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Try typing ;email + Space in Telegram'**
  String get playgroundActiveSubtitle;

  /// No description provided for @btnSwitch.
  ///
  /// In en, this message translates to:
  /// **'Switch'**
  String get btnSwitch;

  /// No description provided for @langSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get langSystem;

  /// No description provided for @settingsProSection.
  ///
  /// In en, this message translates to:
  /// **'Pro'**
  String get settingsProSection;

  /// No description provided for @settingsAppearanceSection.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearanceSection;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeSystemSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Follow device setting'**
  String get themeSystemSubtitle;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @colorWhite.
  ///
  /// In en, this message translates to:
  /// **'White'**
  String get colorWhite;

  /// No description provided for @colorGray.
  ///
  /// In en, this message translates to:
  /// **'Gray'**
  String get colorGray;

  /// No description provided for @colorBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get colorBlue;

  /// No description provided for @colorBlack.
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get colorBlack;

  /// No description provided for @proActiveTitle.
  ///
  /// In en, this message translates to:
  /// **'✨ Pro Active'**
  String get proActiveTitle;

  /// No description provided for @proActiveUntil.
  ///
  /// In en, this message translates to:
  /// **'Available until {time}'**
  String proActiveUntil(Object time);

  /// No description provided for @proUnlockTitle.
  ///
  /// In en, this message translates to:
  /// **'✨ Unlock Pro for today'**
  String get proUnlockTitle;

  /// No description provided for @proUnlockSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Watch a short ad to unlock all Pro features for 24 hours'**
  String get proUnlockSubtitle;

  /// No description provided for @btnWatchAd.
  ///
  /// In en, this message translates to:
  /// **'Watch Ad'**
  String get btnWatchAd;

  /// No description provided for @proUnlockedSnackbar.
  ///
  /// In en, this message translates to:
  /// **'✨ Pro unlocked for 24 hours!'**
  String get proUnlockedSnackbar;

  /// No description provided for @adFailedSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Ad failed to load. Please try again.'**
  String get adFailedSnackbar;

  /// No description provided for @backupErrorWebUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Backup/Restore is not available on web.'**
  String get backupErrorWebUnsupported;

  /// No description provided for @backupErrorFileNotFound.
  ///
  /// In en, this message translates to:
  /// **'Backup file does not exist.'**
  String get backupErrorFileNotFound;

  /// No description provided for @backupErrorInvalidFormat.
  ///
  /// In en, this message translates to:
  /// **'Backup file is not in the correct format.'**
  String get backupErrorInvalidFormat;

  /// No description provided for @backupErrorNotAppBackup.
  ///
  /// In en, this message translates to:
  /// **'This is not a backup file from this app.'**
  String get backupErrorNotAppBackup;

  /// No description provided for @backupErrorInvalidKdf.
  ///
  /// In en, this message translates to:
  /// **'Invalid KDF iterations.'**
  String get backupErrorInvalidKdf;

  /// No description provided for @backupErrorDecrypt.
  ///
  /// In en, this message translates to:
  /// **'Wrong passphrase or corrupted file. Cannot decrypt.'**
  String get backupErrorDecrypt;

  /// No description provided for @lockGateBiometricReason.
  ///
  /// In en, this message translates to:
  /// **'Authenticate to open Smart Clipboard'**
  String get lockGateBiometricReason;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'vi':
      return AppLocalizationsVi();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
