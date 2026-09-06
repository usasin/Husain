import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/admob_config.dart';

/// Initialise AdMob et gère le consentement UMP pour les utilisateurs européens.
class AdService {
  AdService._();

  static final AdService instance = AdService._();

  Future<bool>? _initialization;
  bool _canRequestAds = false;

  bool get isSupported => !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  bool get canRequestAds => _canRequestAds;

  static const String _interstitialOpenCountKey =
      'admob_interstitial_tableau_final_open_count';
  static const String _interstitialLastShownAtKey =
      'admob_interstitial_tableau_final_last_shown_at';
  static const int _interstitialFrequency = 3;
  static const Duration _interstitialMinInterval = Duration(minutes: 10);

  Future<bool> initialize() {
    if (!isSupported) return Future<bool>.value(false);
    return _initialization ??= _initializeInternal();
  }

  Future<bool> _initializeInternal() async {
    final completer = Completer<bool>();
    var completed = false;

    Future<void> finish() async {
      if (completed) return;
      completed = true;

      try {
        _canRequestAds = await ConsentInformation.instance.canRequestAds();
        if (_canRequestAds) {
          await MobileAds.instance.initialize();
        }
      } catch (e) {
        debugPrint('AdMob initialization error: $e');
        _canRequestAds = false;
      }

      completer.complete(_canRequestAds);
    }

    final params = ConsentRequestParameters();
    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () {
        ConsentForm.loadAndShowConsentFormIfRequired((formError) async {
          if (formError != null) {
            debugPrint(
              'AdMob consent form error ${formError.errorCode}: '
              '${formError.message}',
            );
          }
          await finish();
        });
      },
      (formError) async {
        debugPrint(
          'AdMob consent update error ${formError.errorCode}: '
          '${formError.message}',
        );
        // Une décision valide d'une session précédente peut encore exister.
        await finish();
      },
    );

    return completer.future.timeout(
      const Duration(seconds: 35),
      onTimeout: () {
        _canRequestAds = false;
        return false;
      },
    );
  }


  static const String _predictionCountKey = 'admob_prediction_success_count';
  static const String _predictionLastShownKey = 'admob_prediction_last_shown';
  static const int _predictionFrequency = 3;
  static const Duration _predictionMinInterval = Duration(minutes: 7);

  /// Pub après une transition naturelle : tous les 3 pronostics validés,
  /// jamais à chaque clic, et jamais plus d'une fois toutes les 7 minutes.
  Future<bool> maybeShowPredictionInterstitial() async {
    if (!isSupported) return false;
    final prefs = await SharedPreferences.getInstance();
    final count=(prefs.getInt(_predictionCountKey)??0)+1;
    await prefs.setInt(_predictionCountKey,count);
    if (count % _predictionFrequency != 0) return false;
    final last=prefs.getInt(_predictionLastShownKey)??0;
    if (last>0 && DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(last)) < _predictionMinInterval) return false;
    if (!_canRequestAds) await initialize();
    if (!_canRequestAds) return false;
    final completer=Completer<bool>();
    await InterstitialAd.load(adUnitId:AdMobConfig.interstitialAdUnitId,request:const AdRequest(),adLoadCallback:InterstitialAdLoadCallback(
      onAdLoaded:(ad){ ad.fullScreenContentCallback=FullScreenContentCallback(
        onAdShowedFullScreenContent:(_)=>unawaited(prefs.setInt(_predictionLastShownKey,DateTime.now().millisecondsSinceEpoch)),
        onAdDismissedFullScreenContent:(a){a.dispose(); if(!completer.isCompleted) completer.complete(true);},
        onAdFailedToShowFullScreenContent:(a,e){a.dispose(); if(!completer.isCompleted) completer.complete(false);},
      ); ad.show(); },
      onAdFailedToLoad:(_){if(!completer.isCompleted) completer.complete(false);},
    ));
    return completer.future.timeout(const Duration(seconds:30),onTimeout:()=>false);
  }

  /// Affiche l'interstitiel du Tableau final avec un plafond intelligent :
  /// jamais au premier passage, puis au maximum une fois toutes les 3 ouvertures
  /// et avec au moins 10 minutes entre deux affichages.
  Future<bool> maybeShowBracketInterstitial() async {
    if (!isSupported) {
      debugPrint('Interstitial: plateforme non supportée.');
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final openCount = prefs.getInt(_interstitialOpenCountKey) ?? 0;
    final nextOpenCount = openCount + 1;
    await prefs.setInt(_interstitialOpenCountKey, nextOpenCount);

    if (nextOpenCount < _interstitialFrequency ||
        nextOpenCount % _interstitialFrequency != 0) {
      debugPrint('Interstitial: plafond fréquence, ouverture $nextOpenCount.');
      return false;
    }

    final lastShownAt = prefs.getInt(_interstitialLastShownAtKey) ?? 0;
    final now = DateTime.now();
    if (lastShownAt > 0) {
      final elapsed = now.difference(
        DateTime.fromMillisecondsSinceEpoch(lastShownAt),
      );
      if (elapsed < _interstitialMinInterval) {
        debugPrint('Interstitial: intervalle minimum non atteint.');
        return false;
      }
    }

    if (!_canRequestAds) {
      debugPrint('Interstitial: init pas prête, on attend initialize()...');
      await initialize();
    }
    if (!_canRequestAds) {
      debugPrint('Interstitial: ABANDON — canRequestAds=false.');
      return false;
    }

    debugPrint('Interstitial: chargement ${AdMobConfig.interstitialAdUnitId}');
    final completer = Completer<bool>();
    var settled = false;

    void done(bool value) {
      if (!settled) {
        settled = true;
        if (!completer.isCompleted) completer.complete(value);
      }
    }

    try {
      await InterstitialAd.load(
        adUnitId: AdMobConfig.interstitialAdUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            debugPrint('Interstitial: chargée, affichage.');
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdShowedFullScreenContent: (ad) {
                unawaited(prefs.setInt(
                  _interstitialLastShownAtKey,
                  DateTime.now().millisecondsSinceEpoch,
                ));
              },
              onAdDismissedFullScreenContent: (ad) {
                ad.dispose();
                done(true);
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                debugPrint('Interstitial: ÉCHEC affichage -> $error');
                ad.dispose();
                done(false);
              },
            );
            ad.show();
          },
          onAdFailedToLoad: (error) {
            debugPrint('Interstitial: ÉCHEC chargement -> $error');
            done(false);
          },
        ),
      );
    } catch (e) {
      debugPrint('maybeShowBracketInterstitial error: $e');
      done(false);
    }

    return completer.future
        .timeout(const Duration(seconds: 30), onTimeout: () => false);
  }

  /// Affiche une pub récompensée. Renvoie true seulement si l'utilisateur
  /// a regardé la pub jusqu'au bout (récompense obtenue).
  Future<bool> showRewardedAd() async {
    if (!isSupported) {
      debugPrint('Rewarded: plateforme non supportée.');
      return false;
    }
    // L'init au démarrage est lancée sans await : on s'assure qu'elle est
    // bien terminée (sinon _canRequestAds peut être encore false).
    if (!_canRequestAds) {
      debugPrint('Rewarded: init pas prête, on attend initialize()...');
      await initialize();
    }
    if (!_canRequestAds) {
      debugPrint('Rewarded: ABANDON — canRequestAds=false '
          '(consentement refusé ou non configuré).');
      return false;
    }
    debugPrint('Rewarded: chargement ${AdMobConfig.rewardedAdUnitId}');
    final completer = Completer<bool>();
    var settled = false;
    void done(bool v) {
      if (!settled) {
        settled = true;
        if (!completer.isCompleted) completer.complete(v);
      }
    }
    try {
      await RewardedAd.load(
        adUnitId: AdMobConfig.rewardedAdUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            debugPrint('Rewarded: chargée, affichage.');
            var earned = false;
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                ad.dispose();
                done(earned);
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                ad.dispose();
                done(false);
              },
            );
            ad.show(onUserEarnedReward: (ad, reward) {
              earned = true;
            });
          },
          onAdFailedToLoad: (error) {
            debugPrint('Rewarded: ÉCHEC chargement -> $error');
            done(false);
          },
        ),
      );
    } catch (e) {
      debugPrint('showRewardedAd error: $e');
      done(false);
    }
    return completer.future
        .timeout(const Duration(seconds: 30), onTimeout: () => false);
  }

  Future<String?> showPrivacyOptions() async {
    if (!isSupported) {
      return 'Les options publicitaires sont disponibles sur Android/iPhone.';
    }

    final completer = Completer<String?>();
    ConsentForm.showPrivacyOptionsForm((formError) {
      if (formError == null) {
        completer.complete(null);
      } else {
        completer.complete(formError.message);
      }
    });
    return completer.future;
  }
}
