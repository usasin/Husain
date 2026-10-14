# CHECKPOINT — ÉTAT ACTUEL DU PROJET

- App : PRONO4 iOS.
- Branche : `usasin/Husain` / `prono4-build90-ios-prep`.
- Commit source : `f5be1ca7c755059e14a58a1c2a2a9e71e2187069` ; les commits suivants mettent uniquement ce checkpoint à jour.
- Version : `2.8.14+94` dans le source ; build IPA déterminé par le workflow (dernier TestFlight + 1).
- Dernier Codemagic réussi : `6ab7e959814284422fe3e955`, 26/09/2026, index 41, commit `eabdc04907ab0a40e00f264bb957c01e38723a32`, IPA `2.8.11 (30)` ; aucun nouveau build lancé.
- Workflow : `prono4-ios-release`, manuel, même Flutter `3.44.8`, certificat `ios_distribution_all_apps_2026`, profil `prono4_app_store_shared_2026`.
- Source après Restore : `.prono4/build90/ios-source.part-00` à `04`, via `RESTORE_BUILD90_SOURCE.sh` ; contenu 2.8.14, SHA-256 par fichier dans `source-manifest.json`, ATT définitivement intégré, validation sans patch.
- Fichiers modifiés : 33 fichiers du ZIP intégrés ; configuration native Google/Apple, archive, pubspec/lock, validation ; détail `PRONO4_IOS_UPDATE_FILES.json`.
- Modification : source fourni mis à jour sur la base iOS du dernier vert ; ATT conservé ; client Google iOS pris dans le vrai plist Firebase, URL scheme et entitlement Apple préparés sans changer le signing.
- Checks passés : Flutter/Dart 3.44.8/3.12.2 ; pub get (versions du ZIP conservées, ajout ATT uniquement) ; analyze lib sans erreur bloquante, avertissements non fatals ; 10 tests ; Restore + empreintes des 89 fichiers ; imports, YAML, scripts et git diff check.
- Confirmé : les tests préservent avatars/image équipe et présentation des gains ; assets identiques ; backend/règles distants non modifiés. Fonctionnement complet sur iPhone/iPad non testé.
- Firebase vérifié en direct le 14/10 : Google, Apple et Anonyme ACTIVÉS. Règles publiées : /teams/{teamId}/joinRequests autorise la lecture mais `allow create, update, delete: if false;` ; les transactions d’envoi/validation du ZIP échoueront. Validation par un membre écrit aussi /users/{applicantId}.teamId, actuellement réservée au propriétaire/admin. Aucun changement serveur effectué.
- Restant : corriger et tester l’admission serveur ; confirmer CLIENT_ID du vrai plist et capacité Apple du profil existant ; agrégats par compétition à vérifier. Session Apple déconnectée. Pas de nouvelle IPA ni soumission App Store.
- Prochaine action : résoudre les deux refus Firestore de l’admission (envoi et validation), tester candidat/membre/non-membre/équipe complète, puis vérifier le profil Apple avant un seul build manuel sur cette branche/HEAD et ce workflow. Test TestFlight avant soumission App Store.
- Ne pas modifier : Bundle ID `com.digitalsolutionsai.prono4`, app Apple `6809793049`, certificat/profil existants sans nécessité démontrée, secret plist Firebase, IDs AdMob, règles/points/données ; ne pas utiliser le codemagic.yaml Android du ZIP ni le dépôt `prono4-ios` avec `com.mundial.app`.
