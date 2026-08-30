import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../core/constants/app_limits.dart';
import '../core/database/app_database.dart';
import '../core/native_bridge/native_bridge.dart';
import '../core/utils/content_normalizer.dart' show contentHash;
import '../models/clipboard_item.dart';
import '../models/snippet.dart';
import '../repositories/clipboard_repository.dart';
import '../repositories/snippet_repository.dart';
import '../services/auth_service.dart';
import '../services/backup_service.dart';
import '../services/cache_sync_service.dart';
import '../services/clipboard_service.dart';
import '../services/expansion_engine.dart';
import '../services/metrics_service.dart';
import '../services/privacy_service.dart';

/// ============================================================================
/// STATE MANAGEMENT — RIVERPOD THỐNG NHẤT TOÀN APP (STRICT RULE 18).
/// Không trộn Provider/setState tự do ở các màn hình chính.
/// ============================================================================

/// Override bằng giá trị DB thật trong main() sau khi open+migration xong.
final databaseProvider = Provider<Database>(
    (ref) => throw UnimplementedError('Override trong main()'));

// --------------------------- Core services ---------------------------

final metaDaoProvider = Provider((ref) => MetaDao(ref.watch(databaseProvider)));
final cacheSyncProvider =
    Provider((ref) => CacheSyncService(ref.watch(databaseProvider)));
final privacyProvider = Provider((ref) => PrivacyService());

final snippetRepoProvider = Provider((ref) =>
    SnippetRepository(
        ref.watch(databaseProvider), ref.watch(cacheSyncProvider)));

final clipboardRepoProvider = Provider(
    (ref) => ClipboardRepository(
        ref.watch(databaseProvider),
        privacy: ref.watch(privacyProvider)));

final metricsProvider =
    Provider((ref) => MetricsService(ref.watch(metaDaoProvider)));

final clipboardServiceProvider = Provider((ref) => ClipboardService(
      repo: ref.watch(clipboardRepoProvider),
      meta: ref.watch(metaDaoProvider),
      metrics: ref.watch(metricsProvider),
      privacy: ref.watch(privacyProvider),
    ));

final backupServiceProvider =
    Provider((ref) => BackupService(ref.watch(databaseProvider)));

final authServiceProvider = Provider((ref) => AuthService());
final nativeBridgeProvider = Provider((ref) => NativeBridge());

// --------------------------- App Settings ---------------------------

class AppSettings {
  final int expirationDays;
  final bool capturePaused; // Incognito/Pause Mode (mục 5.2)
  final bool biometricLock;
  final bool onboardingDone;
  final String keyboardBgColor; // PLAN 7 P1-5: keyboard background hex

  /// false khi đang load từ DB lần đầu — UI hiển thị splash, tránh flash.
  final bool loaded;

  const AppSettings._({
    required this.expirationDays,
    required this.capturePaused,
    required this.biometricLock,
    required this.onboardingDone,
    required this.keyboardBgColor,
    required this.loaded,
  });

  factory AppSettings({
    int? expirationDays,
    bool capturePaused = false,
    bool biometricLock = false,
    bool onboardingDone = false,
    String keyboardBgColor = '#FFFFFF',
    bool loaded = false,
  }) => AppSettings._(
        expirationDays: expirationDays ?? 30,
        capturePaused: capturePaused,
        biometricLock: biometricLock,
        onboardingDone: onboardingDone,
        keyboardBgColor: keyboardBgColor,
        loaded: loaded,
      );

  AppSettings copyWith({
    int? expirationDays,
    bool? capturePaused,
    bool? biometricLock,
    bool? onboardingDone,
    String? keyboardBgColor,
    bool? loaded,
  }) =>
      AppSettings(
        expirationDays: expirationDays ?? this.expirationDays,
        capturePaused: capturePaused ?? this.capturePaused,
        biometricLock: biometricLock ?? this.biometricLock,
        onboardingDone: onboardingDone ?? this.onboardingDone,
        keyboardBgColor: keyboardBgColor ?? this.keyboardBgColor,
        loaded: loaded ?? this.loaded,
      );
}

class AppSettingsController extends StateNotifier<AppSettings> {
  final MetaDao _meta;
  AppSettingsController(this._meta) : super(AppSettings()) {
    _load();
  }

  Future<void> _load() async {
    final expirationDays = await _meta.getInt('expiration_days',
        fallback: AppLimits.expirationOptionsDays.last);
    final bgHex = await _meta.get('keyboard_bg_color');
    state = AppSettings(
      expirationDays: AppLimits.expirationOptionsDays.contains(expirationDays)
          ? expirationDays
          : AppLimits.expirationOptionsDays.last,
      capturePaused: await _meta.getBool('capture_paused'),
      biometricLock: await _meta.getBool('biometric_lock'),
      onboardingDone: await _meta.getBool('onboarding_done'),
      keyboardBgColor: (bgHex != null && bgHex.isNotEmpty) ? bgHex : '#FFFFFF',
      loaded: true,
    );
  }

  Future<void> setExpirationDays(int days) async {
    await _meta.set('expiration_days', '$days');
    state = state.copyWith(expirationDays: days);
  }

  /// Incognito/Pause Mode toggle 1 chạm (P0, mục 5.2).
  Future<void> setCapturePaused(bool paused) async {
    await _meta.setBool('capture_paused', paused);
    state = state.copyWith(capturePaused: paused);
  }

  Future<void> setBiometricLock(bool enabled) async {
    await _meta.setBool('biometric_lock', enabled);
    state = state.copyWith(biometricLock: enabled);
  }

  Future<void> completeOnboarding() async {
    await _meta.setBool('onboarding_done', true);
    state = state.copyWith(onboardingDone: true);
  }

  // PLAN 7 P1-5: Save keyboard background color
  Future<void> setKeyboardBgColor(String hex) async {
    await _meta.set('keyboard_bg_color', hex);
    state = state.copyWith(keyboardBgColor: hex);
  }
}

final appSettingsProvider = StateNotifierProvider<AppSettingsController,
    AppSettings>((ref) => AppSettingsController(ref.watch(metaDaoProvider)));

// --------------------------- Biometric Lock gate ---------------------------

/// true = đang khoá, yêu cầu xác thực sinh trắc học trước khi vào app.
final lockControllerProvider = StateProvider<bool>((ref) => false);

// --------------------------- Clipboard list ---------------------------

class ClipboardListController
    extends StateNotifier<AsyncValue<List<ClipboardItem>>> {
  final ClipboardRepository _repo;
  final Ref _ref;

  ClipboardListController(this._repo, this._ref)
      : super(const AsyncValue.loading()) {
    reload();
  }

  Future<void> reload() async {
    try {
      await _repo.purgeExpired(); // Auto-Expiration Engine (P0)
      state = AsyncValue.data(await _repo.getActive());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> togglePin(ClipboardItem item) async {
    await _repo.setPinned(item.id, !item.isPinned);
    await reload();
  }

  Future<void> toggleFavorite(ClipboardItem item) async {
    await _repo.setFavorite(item.id, !item.isFavorite);
    await reload();
  }

  Future<void> archiveItem(String id) async {
    await _repo.archive(id);
    await reload();
  }

  Future<void> deleteForever(String id) async {
    await _repo.deleteForever(id);
    await reload();
  }
}

final clipboardListProvider = StateNotifierProvider<ClipboardListController,
    AsyncValue<List<ClipboardItem>>>(
    (ref) => ClipboardListController(
        ref.watch(clipboardRepoProvider), ref));

final archivedClipboardCountProvider = FutureProvider<int>(
    (ref) async {
  ref.watch(clipboardListProvider); // refresh khi list đổi
  return ref.read(clipboardRepoProvider).archivedCount();
});

final snippetArchivedCountProvider = FutureProvider<int>((ref) async {
  ref.watch(snippetListProvider); // refresh khi list đổi
  return ref.read(snippetRepoProvider).archivedCount();
});

// --------------------------- Snippets & Folders ---------------------------

class SnippetListController extends StateNotifier<AsyncValue<List<Snippet>>> {
  final SnippetRepository _repo;
  final Ref _ref;

  SnippetListController(this._repo, this._ref)
      : super(const AsyncValue.loading()) {
    reload();
  }

  Future<void> reload() async {
    try {
      state = AsyncValue.data(await _repo.getAll());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<int> create({
    required String title,
    required String trigger,
    required String content,
    String? folderId,
  }) async {
    final archived =
        await _repo.create(title: title, trigger: trigger,
            content: content, folderId: folderId);
    await _ref.read(metricsProvider).increment(MetricsService.kSnippetsCreated);
    await reload();
    return archived;
  }

  Future<void> save(Snippet snippet) async {
    await _repo.update(snippet);
    await reload();
  }

  Future<void> toggleEnabled(Snippet snippet) async {
    await _repo.setEnabled(snippet.id, !snippet.isEnabled);
    await reload();
  }

  Future<void> archive(String id) async {
    await _repo.archive(id);
    await reload();
  }

  Future<void> deleteForever(String id) async {
    await _repo.deleteForever(id);
    await reload();
  }
}

final snippetListProvider =
    StateNotifierProvider<SnippetListController, AsyncValue<List<Snippet>>>(
        (ref) => SnippetListController(ref.watch(snippetRepoProvider), ref));

class FolderListController
    extends StateNotifier<AsyncValue<List<Map<String, Object?>>>> {
  final SnippetRepository _repo;

  FolderListController(this._repo) : super(const AsyncValue.loading()) {
    reload();
  }

  Future<void> reload() async {
    try {
      final folders = await _repo.getFolders();
      state = AsyncValue.data(folders
          .map((f) => {'id': f.id, 'name': f.name} as Map<String, Object?>)
          .toList());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> create(String name) async {
    if (!await _repo.canCreateFolder()) return false;
    await _repo.createFolder(name);
    await reload();
    return true;
  }

  Future<void> rename(String id, String name) async {
    await _repo.renameFolder(id, name);
    await reload();
  }

  Future<void> delete(String id) async {
    await _repo.deleteFolder(id);
    await reload();
  }
}

final folderListProvider = StateNotifierProvider<FolderListController,
    AsyncValue<List<Map<String, Object?>>>>(
    (ref) => FolderListController(ref.watch(snippetRepoProvider)));

// --------------------------- Expansion Engine ---------------------------

final expansionEngineProvider = Provider<ExpansionEngine>((ref) {
  final snippets = ref.watch(snippetListProvider).value ?? const <Snippet>[];
  return ExpansionEngine(
    triggerToContent: {
      for (final s in snippets.where((s) => s.isEnabled))
        s.trigger: s.content,
    },
    triggerToId: {
      for (final s in snippets.where((s) => s.isEnabled)) s.trigger: s.id,
    },
  );
});

// --------------------------- Keyboard / Pro status ---------------------------

/// Phase 0: stub trả về false cho đến khi native IME (Phase 1) tồn tại.
final keyboardEnabledProvider = FutureProvider<bool>(
    (ref) => ref.watch(nativeBridgeProvider).isKeyboardEnabled());

enum KeyboardActivationState { disabled, enabledNotActive, active }

final keyboardActiveProvider = FutureProvider<bool>(
    (ref) => ref.watch(nativeBridgeProvider).isKeyboardActive());

final keyboardActivationStateProvider =
    FutureProvider<KeyboardActivationState>((ref) async {
  final enabled =
      await ref.watch(nativeBridgeProvider).isKeyboardEnabled();
  if (!enabled) return KeyboardActivationState.disabled;
  final active =
      await ref.watch(nativeBridgeProvider).isKeyboardActive();
  return active
      ? KeyboardActivationState.active
      : KeyboardActivationState.enabledNotActive;
});

/// Pro status stub — wire-up `in_app_purchase` ở phase IAP (không thuộc P0).
/// false = bản Free, áp dụng AppLimits (soft-delete Rule 17).
final proStatusProvider = StateProvider<bool>((_) => false);

/// Locale provider — persists language choice in app_meta.
/// Default: follow system locale. User can override in Settings.
final localeProvider = StateNotifierProvider<LocaleController, Locale?>((ref) {
  return LocaleController(ref.watch(metaDaoProvider));
});

class LocaleController extends StateNotifier<Locale?> {
  final MetaDao _meta;
  LocaleController(this._meta) : super(null) {
    _load();
  }

  Future<void> _load() async {
    final code = await _meta.get('app_language');
    if (code != null && code.isNotEmpty) {
      state = Locale(code);
    }
    // null = follow system locale
  }

  Future<void> setLocale(Locale? locale) async {
    state = locale;
    if (locale == null) {
      await _meta.set('app_language', '');
    } else {
      await _meta.set('app_language', locale.languageCode);
    }
  }
}

/// Helper dùng chung: hash nội dung (để kiểm tra dedup ngoài repository nếu cần).
String hashOf(String raw) => contentHash(raw);

// --------------------------- Clipboard Filter (Batch 2) ---------------------------

class ClipboardFilterState {
  final String query;
  final bool favoriteOnly;
  final bool pinnedOnly;

  const ClipboardFilterState({
    this.query = '',
    this.favoriteOnly = false,
    this.pinnedOnly = false,
  });

  ClipboardFilterState copyWith({
    String? query,
    bool? favoriteOnly,
    bool? pinnedOnly,
  }) =>
      ClipboardFilterState(
        query: query ?? this.query,
        favoriteOnly: favoriteOnly ?? this.favoriteOnly,
        pinnedOnly: pinnedOnly ?? this.pinnedOnly,
      );
}

final clipboardFilterProvider =
    StateProvider<ClipboardFilterState>((ref) => const ClipboardFilterState());

/// Provider phái sinh — KHÔNG đụng ClipboardListController.
/// Tự động re-tính mỗi khi list gốc HOẶC filter đổi.
final visibleClipboardItemsProvider = Provider<List<ClipboardItem>>((ref) {
  final items = ref.watch(clipboardListProvider).value ?? const <ClipboardItem>[];
  final f = ref.watch(clipboardFilterProvider);

  return items.where((item) {
    if (f.favoriteOnly && !item.isFavorite) return false;
    if (f.pinnedOnly && !item.isPinned) return false;
    if (f.query.isNotEmpty &&
        !item.content.toLowerCase().contains(f.query.toLowerCase())) {
      return false;
    }
    return true;
  }).toList();
});

// --------------------------- Snippet Filter (Batch 3) ---------------------------

/// Trạng thái filter snippet: All, Enabled, Disabled.
enum SnippetFilterMode { all, enabled, disabled }

class SnippetFilterState {
  final String query;
  final SnippetFilterMode mode;
  final String? folderId;

  const SnippetFilterState({
    this.query = '',
    this.mode = SnippetFilterMode.all,
    this.folderId,
  });

  SnippetFilterState copyWith({
    String? query,
    SnippetFilterMode? mode,
    String? Function()? folderId,
  }) =>
      SnippetFilterState(
        query: query ?? this.query,
        mode: mode ?? this.mode,
        folderId: folderId != null ? folderId() : this.folderId,
      );
}

final snippetFilterProvider =
    StateProvider<SnippetFilterState>((ref) => const SnippetFilterState());

final visibleSnippetsProvider = Provider<List<Snippet>>((ref) {
  final items = ref.watch(snippetListProvider).value ?? const <Snippet>[];
  final f = ref.watch(snippetFilterProvider);

  return items.where((s) {
    if (f.mode == SnippetFilterMode.enabled && !s.isEnabled) return false;
    if (f.mode == SnippetFilterMode.disabled && s.isEnabled) return false;
    if (f.folderId != null && s.folderId != f.folderId) return false;
    if (f.query.isNotEmpty) {
      final q = f.query.toLowerCase();
      final match = s.title.toLowerCase().contains(q) ||
          s.trigger.toLowerCase().contains(q) ||
          s.content.toLowerCase().contains(q);
      if (!match) return false;
    }
    return true;
  }).toList();
});
