import 'package:flutter/foundation.dart';

/// Configuration AdMob.
///
/// En mode debug (`flutter run`), les annonces de test Google sont utilisées.
/// En version release, l'identifiant AdMob réel Android est utilisé.
class AdMobConfig {
  static bool get useTestAds => kDebugMode;

  static const String _androidTestBannerId =
      'ca-app-pub-3940256099942544/9214589741';
  static const String _iosTestBannerId =
      'ca-app-pub-3940256099942544/2435281174';

  static const String androidBannerAdUnitId =
      'ca-app-pub-1360261396564293/9415203040';
  static const String iosBannerAdUnitId =
      'ca-app-pub-1360261396564293/3147910611';

  static String get bannerAdUnitId {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return (useTestAds || iosBannerAdUnitId.startsWith('CA_APP_')) ? _iosTestBannerId : iosBannerAdUnitId;
    }
    return useTestAds ? _androidTestBannerId : androidBannerAdUnitId;
  }

  // ── Pub interstitielle (Tableau final) ──
  static const String _androidTestInterstitialId =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _iosTestInterstitialId =
      'ca-app-pub-3940256099942544/4411468910';

  static const String androidInterstitialAdUnitId =
      'ca-app-pub-1360261396564293/4859482530';
  static const String iosInterstitialAdUnitId =
      'ca-app-pub-1360261396564293/2271259865';

  static String get interstitialAdUnitId {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return (useTestAds || iosInterstitialAdUnitId.startsWith('CA_APP_')) ? _iosTestInterstitialId : iosInterstitialAdUnitId;
    }
    return useTestAds ? _androidTestInterstitialId : androidInterstitialAdUnitId;
  }

  // ── Pub récompensée (changement de prono à la mi-temps) ──
  static const String _androidTestRewardedId =
      'ca-app-pub-3940256099942544/5224354917';
  static const String _iosTestRewardedId =
      'ca-app-pub-3940256099942544/1712485313';

  static const String androidRewardedAdUnitId =
      'ca-app-pub-1360261396564293/6948869531';
  static const String iosRewardedAdUnitId =
      'ca-app-pub-1360261396564293/9012762187';

  static String get rewardedAdUnitId {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return (useTestAds || iosRewardedAdUnitId.startsWith('CA_APP_')) ? _iosTestRewardedId : iosRewardedAdUnitId;
    }
    return useTestAds ? _androidTestRewardedId : androidRewardedAdUnitId;
  }
}
