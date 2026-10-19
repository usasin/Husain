import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/admob_config.dart';
import '../services/ad_service.dart';
import '../theme/app_theme.dart';
import '../l10n/app_locale.dart';

/// Bannière AdMob fixe au-dessus de la navigation.
/// Elle reste invisible si l'utilisateur refuse les publicités ou si le
/// chargement échoue.
class AdMobBanner extends StatefulWidget {
  const AdMobBanner({super.key});

  @override
  State<AdMobBanner> createState() => _AdMobBannerState();
}

class _AdMobBannerState extends State<AdMobBanner> {
  BannerAd? _bannerAd;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!AdService.instance.isSupported || kIsWeb) return;

    final allowed = await AdService.instance.initialize();
    if (!allowed || !mounted) return;

    final ad = BannerAd(
      adUnitId: AdMobConfig.bannerAdUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('AdMob banner load error: $error');
          ad.dispose();
        },
      ),
    );

    _bannerAd = ad;
    await ad.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _bannerAd;
    if (!_loaded || ad == null) return const SizedBox.shrink();

    return AdvertisementFrame(
        child: SizedBox(
            width: ad.size.width.toDouble(),
            height: ad.size.height.toDouble(),
            child: AdWidget(ad: ad)));
  }
}

/// Distinguishes the ad from app controls without covering its creative or
/// changing loading, consent, clicks, dimensions or the advertising unit.
class AdvertisementFrame extends StatelessWidget {
  final Widget child;
  const AdvertisementFrame({super.key, required this.child});
  @override
  Widget build(BuildContext context) => ColoredBox(
      color: AppColors.bg1,
      child: SafeArea(
          top: false,
          bottom: false,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Divider(
                height: 1, color: AppColors.overlayBase.withValues(alpha: .12)),
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(context.tr('PUBLICITÉ', 'ADVERTISEMENT'),
                    style: TextStyle(
                        color: AppColors.text2,
                        fontSize: 9,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w700))),
            Center(child: child),
            const SizedBox(height: 4),
          ])));
}
