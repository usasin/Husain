PRONO4 — REFONTE UI + ÉCUSSONS CLUBS
===================================

Ce build part du projet avec les Cloud Functions Matchs déjà corrigées.

CORRECTIONS IMPORTANTES
- Identité PRONO4 : #101211 / #F7F8F5 / #B6FF3B.
- Nouveau launcher icon P4 et splash.
- Accueil PRONO4 : équipe, points, classement, matchs à venir.
- Navigation sombre premium.
- Onglet Matchs : À venir / En direct / Terminés.
- Classement : Top équipes en premier, Top membres ensuite.
- Correction du bug MAR : Marseille ne peut plus être interprété comme Maroc.
- Les matchs de clubs n'utilisent plus le dictionnaire des drapeaux nationaux.
- football-data.org stocke maintenant les vrais écussons :
  homeCrestUrl / awayCrestUrl.
- Une collection Firestore `clubs` est alimentée automatiquement avec les clubs et leurs crestUrl.
- SVG et PNG sont pris en charge grâce à flutter_svg + cached_network_image.
- En absence d'écusson : badge neutre avec initiales du club.

POUR METTRE LES ÉCUSSONS EN PRODUCTION
Dans Cloud Shell, depuis la racine du projet :
  chmod +x DEPLOY_PRONO4_CLUB_LOGOS.sh
  ./DEPLOY_PRONO4_CLUB_LOGOS.sh

POUR GÉNÉRER L'APP ANDROID
Sur une machine avec Flutter :
  chmod +x BUILD_PRONO4_ANDROID.sh
  ./BUILD_PRONO4_ANDROID.sh

Le fichier AAB final sera dans :
  build/app/outputs/bundle/release/app-release.aab

NOTE PORTABILITÉ
- android/local.properties a volontairement été retiré du ZIP car il contenait des chemins Windows locaux.
- Flutter le recrée automatiquement sur le PC / Codemagic qui compile l'application.
