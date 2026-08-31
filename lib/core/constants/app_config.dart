/// App configuration — AdMob, Sentry, feature flags.
///
/// enableAds = false → AdMob SDK KHÔNG init, KHÔNG load ads (debug mode).
/// Flip to true khi release production.
class AppConfig {
  AppConfig._();

  /// Bật/tắt toàn bộ AdMob. false = no ads, no SDK init.
  static const bool enableAds = false;

  // ---- AdMob (hoangsoft90 production IDs) ----
  static const String androidAppId = 'ca-app-pub-6917313063209470~4788568410';
  static const String bannerAdUnitId = 'ca-app-pub-6917313063209470/6763995063';
  static const String interstitialAdUnitId = 'ca-app-pub-6917313063209470/7046960890';
  static const String rewardedAdUnitId = 'ca-app-pub-6917313063209470/6528086144';
}
