PRONO4 iPhone/iPad
Le code applicatif est maintenant compatible iOS/iPad et le pubspec génère aussi les icônes iOS.
Le projet source reçu était Android-only (aucun ios/).
Sur un Mac ou dans Codemagic : chmod +x scripts/PREPARE_IOS_IPAD.sh && ./scripts/PREPARE_IOS_IPAD.sh
Puis ajouter le GoogleService-Info.plist Firebase iOS dans ios/Runner/.
Les unités AdMob iOS Bannière et Interstitielle fournies ont été intégrées dans lib/config/admob_config.dart. Le Rewarded iOS n'existe pas encore dans la capture AdMob : il reste volontairement en TEST/fallback jusqu'à création d'une unité Rewarded iOS réelle. Il faut aussi fournir l'App ID AdMob iOS (format ca-app-pub-...~...) via ADMOB_IOS_APP_ID pour le build iOS release.
