import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'core/constants/app_config.dart';

import 'core/database/app_database.dart';
import 'generated/l10n/app_localizations.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/clipboard/clipboard_history_screen.dart';
import 'screens/snippets/snippets_screen.dart';
import 'screens/snippets/snippet_edit_screen.dart';
import 'screens/snippets/folders_screen.dart';
import 'screens/playground/playground_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'services/cache_sync_service.dart';
import 'state/providers.dart';
import 'widgets/lock_gate.dart';

const _sentryDsn = 'https://7a668ce084082307784ece27aaa7a588@o4505474077753344.ingest.us.sentry.io/4512003088908288';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Sentry: capture Flutter + platform errors
  await SentryFlutter.init(
    (options) {
      options.dsn = _sentryDsn;
      options.tracesSampleRate = 0.0; // Disable performance monitoring for now
    },
    appRunner: () async {
      // Mobile Ads SDK init — only when enableAds = true
      if (AppConfig.enableAds) {
        await MobileAds.instance.initialize();
      }

      // WAL mode + migration chạy trong transaction (STRICT RULE 3, mục 2.2).
      final db = await AppDatabase.open();

      // STRICT RULE 13 [CACHE REGEN]: sau khi migration thành công, bắt buộc gọi
      // regenerateSnippetCache() NGAY trước khi coi app "sẵn sàng" (mục 2.2).
      try {
        await CacheSyncService(db).regenerateSnippetCache();
      } catch (_) {
        // Cache hỏng không chặn app khởi động — IME sẽ fallback empty state (mục 1.3).
      }

      // Run app with ProviderScope — database override for DI
      runApp(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const SmartClipboardApp(),
      ));
    },
  );
}

/// Named routes cho deep-link support + onGenerateRoute.
/// Mỗi route tương ứng 1 screen — không dead-end, mọi screen đều
/// có thể truy cập bằng tên route.
class AppRoutes {
  static const root = '/';
  static const home = '/home';
  static const clipboardHistory = '/clipboard';
  static const snippets = '/snippets';
  static const snippetEdit = '/snippets/edit';
  static const folders = '/snippets/folders';
  static const playground = '/playground';
  static const settings = '/settings';
  static const onboarding = '/onboarding';
}

class SmartClipboardApp extends ConsumerWidget {
  const SmartClipboardApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Smart Clipboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF3D5AFE),
        brightness: Brightness.light,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF3D5AFE),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      themeMode: themeMode,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: ref.watch(localeProvider),
      initialRoute: AppRoutes.root,
      onGenerateRoute: (settings) {
        // Deep-link: nếu có shared text trong route args, xử lý tại đây.
        final sharedText = settings.arguments as String?;

        switch (settings.name) {
          case AppRoutes.root:
            return MaterialPageRoute(
                builder: (_) => const RootGate(), settings: settings);
          case AppRoutes.home:
            return MaterialPageRoute(
                builder: (_) => const HomeScreen(), settings: settings);
          case AppRoutes.clipboardHistory:
            return MaterialPageRoute(
                builder: (_) => const ClipboardHistoryScreen(),
                settings: settings);
          case AppRoutes.snippets:
            return MaterialPageRoute(
                builder: (_) => const SnippetsScreen(), settings: settings);
          case AppRoutes.snippetEdit:
            return MaterialPageRoute(
                builder: (_) => const SnippetEditScreen(), settings: settings);
          case AppRoutes.folders:
            return MaterialPageRoute(
                builder: (_) => const FoldersScreen(), settings: settings);
          case AppRoutes.playground:
            return MaterialPageRoute(
                builder: (_) => const PlaygroundScreen(), settings: settings);
          case AppRoutes.settings:
            return MaterialPageRoute(
                builder: (_) => const SettingsScreen(), settings: settings);
          case AppRoutes.onboarding:
            return MaterialPageRoute(
                builder: (_) => const OnboardingScreen(), settings: settings);
          default:
            return MaterialPageRoute(
                builder: (_) => const RootGate(), settings: settings);
        }
      },
    );
  }
}

/// Gate gốc: splash (đang load settings) → onboarding lần đầu → biometric
/// lock → HomeScreen.
class RootGate extends ConsumerWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);

    if (!settings.loaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!settings.onboardingDone) return const OnboardingScreen();

    // Biometric App Lock (P0 Free, mục 8).
    return settings.biometricLock
        ? const LockGate(child: HomeScreen())
        : const HomeScreen();
  }
}
