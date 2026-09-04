/// App configuration — AdMob, Sentry, feature flags.
///
/// enableAds = false → AdMob SDK KHÔNG init, KHÔNG load ads.
/// testAds = true → dùng Google test ad unit IDs (không bị giới hạn).
class AppConfig {
  AppConfig._();

  /// Bật/tắt toàn bộ AdMob. false = no ads, no SDK init.
  static const bool enableAds = true;

  /// Bật/tắt test ads. true = Google test IDs, false = real IDs.
  static const bool testAds = false;

  // ---- Google Test Ad Unit IDs ----
  static const String testAndroidAppId = 'ca-app-pub-3940256099942544~3347511713';
  static const String testBannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
  static const String testInterstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712';
  static const String testRewardedAdUnitId = 'ca-app-pub-3940256099942544/5224354917';

  // ---- Real Ad Unit IDs (hoangsoft90) ----
  static const String prodAndroidAppId = 'ca-app-pub-6917313063209470~4788568410';
  static const String prodBannerAdUnitId = 'ca-app-pub-6917313063209470/6763995063';
  static const String prodInterstitialAdUnitId = 'ca-app-pub-6917313063209470/7046960890';
  static const String prodRewardedAdUnitId = 'ca-app-pub-6917313063209470/6528086144';

  // ---- Auto-selected by testAds flag ----
  static String get androidAppId => testAds ? testAndroidAppId : prodAndroidAppId;
  static String get bannerAdUnitId => testAds ? testBannerAdUnitId : prodBannerAdUnitId;
  static String get interstitialAdUnitId => testAds ? testInterstitialAdUnitId : prodInterstitialAdUnitId;
  static String get rewardedAdUnitId => testAds ? testRewardedAdUnitId : prodRewardedAdUnitId;
}
