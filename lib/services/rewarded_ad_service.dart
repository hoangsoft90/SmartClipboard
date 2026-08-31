import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../core/constants/app_config.dart';

/// RewardedAdService — loads and shows rewarded ads for Pro unlock.
///
/// Uses AppConfig.rewardedAdUnitId (test or real based on testAds flag).
/// Caller provides callbacks for success (onEarned) and failure (onFailed).
class RewardedAdService {
  RewardedAd? _rewardedAd;

  /// Load and show a rewarded ad.
  /// [onEarned] called when user earns reward → unlock Pro.
  /// [onFailed] called when ad fails to load or show.
  void showAd({
    required void Function() onEarned,
    required void Function() onFailed,
  }) {
    if (!AppConfig.enableAds) {
      onFailed();
      return;
    }

    final adUnitId = AppConfig.testAds
        ? 'ca-app-pub-3940256099942544/5224354917' // Google test rewarded
        : AppConfig.rewardedAdUnitId;

    RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _rewardedAd = null;
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _rewardedAd = null;
              onFailed();
            },
          );
          ad.show(
            onUserEarnedReward: (ad, reward) {
              onEarned();
            },
          );
        },
        onAdFailedToLoad: (error) {
          onFailed();
        },
      ),
    );
  }

  void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
  }
}
