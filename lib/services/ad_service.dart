import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Ad unit IDs.
///
/// These are Google's public TEST ids — safe to ship in debug and to use
/// while developing. BEFORE release, create a new AdMob app under the same
/// AdMob account used for nanimonjya/petaname, generate real Banner and
/// Interstitial unit IDs, and swap them in here (see build reference memory
/// for how those IDs are organized).
class AdIds {
  static String get bannerUnitId => kReleaseMode
      ? 'ca-app-pub-REPLACE_WITH_REAL_ID/BANNER'
      : 'ca-app-pub-3940256099942544/6300978111'; // Google test banner

  static String get interstitialUnitId => kReleaseMode
      ? 'ca-app-pub-REPLACE_WITH_REAL_ID/INTERSTITIAL'
      : 'ca-app-pub-3940256099942544/1033173712'; // Google test interstitial
}

/// Thin wrapper around google_mobile_ads. Banner/interstitial only — no
/// rewarded ad, since nothing in this app is gated behind "watch a video".
class AdService {
  InterstitialAd? _interstitial;
  int _sessionActions = 0;

  Future<void> init() async {
    await MobileAds.instance.initialize();
    _loadInterstitial();
  }

  void _loadInterstitial() {
    InterstitialAd.load(
      adUnitId: AdIds.interstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (_) => _interstitial = null,
      ),
    );
  }

  BannerAd createBanner({required VoidCallback onLoaded}) {
    final banner = BannerAd(
      adUnitId: AdIds.bannerUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(onAdLoaded: (_) => onLoaded()),
    );
    banner.load();
    return banner;
  }

  /// Call after a nap finishes or an alarm is dismissed — every 3rd time,
  /// to keep it from ever interrupting the alarm itself.
  void maybeShowInterstitial() {
    _sessionActions++;
    if (_sessionActions % 3 != 0) return;
    final ad = _interstitial;
    if (ad == null) return;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _interstitial = null;
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose();
        _interstitial = null;
        _loadInterstitial();
      },
    );
    ad.show();
  }
}
