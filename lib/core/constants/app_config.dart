/// App configuration — AdMob, Sentry, feature flags.
///
/// testAds = true → dùng Google test ad unit IDs (không bị AdMob giới hạn).
/// Flip to false khi release production + đã tạo ad units trên AdMob console.
class AppConfig {
  AppConfig._();

  /// Bật/tắt test ads. true = test ad units (Google cung cấp).
  static const bool testAds = true;

  // ---- AdMob ----
  // Google test App IDs
  static const String androidAppId = 'ca-app-pub-3940256099942544~3347511713';
  static const String iosAppId = 'ca-app-pub-3940256099942544~1458002511';

  // Test Banner Ad Unit ID (Google cung cấp)
  static const String testBannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';

  // Production Banner Ad Unit ID (điền sau khi tạo trên AdMob console)
  static const String prodBannerAdUnitId = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';

  /// Banner Ad Unit ID — auto-chọn theo testAds flag.
  static String get bannerAdUnitId =>
      testAds ? testBannerAdUnitId : prodBannerAdUnitId;
}
