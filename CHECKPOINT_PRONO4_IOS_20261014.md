# CHECKPOINT — ÉTAT ACTUEL DU PROJET

- App : PRONO4 iOS.
- Branche : `usasin/Husain` / `prono4-build90-ios-prep`.
- Commit source : `f5be1ca7c755059e14a58a1c2a2a9e71e2187069` ; source iOS inchangé depuis ce commit.
- Version : `2.8.14+94` dans le source ; build IPA déterminé par le workflow (dernier TestFlight + 1).
- Dernier Codemagic réussi : `6ab7e959814284422fe3e955`, 26/09/2026, index 41, commit `eabdc04907ab0a40e00f264bb957c01e38723a32`, IPA `2.8.11 (30)` ; aucun nouveau build lancé.
- Workflow : `prono4-ios-release`, manuel, même Flutter `3.44.8`, certificat `ios_distribution_all_apps_2026`, profil `prono4_app_store_shared_2026`.
- Source après Restore : `.prono4/build90/ios-source.part-00` à `04`, via `RESTORE_BUILD90_SOURCE.sh` ; contenu 2.8.14, SHA-256 par fichier dans `source-manifest.json`, ATT définitivement intégré, validation sans patch.
- Fichiers modifiés : 33 fichiers du ZIP intégrés ; prototype de règles et tests d’admission préparés séparément ; configuration native Google/Apple, archive, pubspec/lock, validation ; détail `PRONO4_IOS_UPDATE_FILES.json`.
- Modification : source fourni mis à jour sur la base iOS du dernier vert ; ATT conservé ; client Google iOS pris dans le vrai plist Firebase, URL scheme et entitlement Apple préparés sans changer le signing.
- Checks passés : Flutter/Dart 3.44.8/3.12.2 ; pub get (versions du ZIP conservées, ajout ATT uniquement) ; analyze lib sans erreur bloquante, avertissements non fatals ; 10 tests ; Restore + empreintes des 89 fichiers ; imports, YAML, scripts et git diff check.
- Confirmé : les tests préservent avatars/image équipe et présentation des gains ; assets identiques ; backend/règles distants non modifiés. Fonctionnement complet sur iPhone/iPad non testé.
- Firebase : Google/Apple/Anonyme activés ; base (default), Standard/native, eur3. Règles actuelles bloquent les écritures joinRequests et l'approbation du teamId d'un autre utilisateur.
- Correctif prêt, NON publié : `firestore-admission-proposed.rules`, SHA-256 `5079ed84e2b3bf9f9ddeb7de4465134aa32a672804f8f4d020695cc7d0ca7030` ; 37 scénarios émulateur passent (admission atomique, non-membre, identité usurpée, équipe pleine/verrouillée, création/départ/image préservés) ; appartenance protégée contre ajout frauduleux et suppression/recréation par un tiers. Baseline dans `.prono4/rules-backups/firestore-live-20261014.rules`. Anciennes versions qui adhèrent directement devront utiliser le nouveau parcours validé ; un UID de profil différent de l'UID Auth reste refusé sans preuve de récupération sûre.
- Apple vérifié : Bundle ID `com.digitalsolutionsai.prono4` (identifiant `QHC8MJMTV7`) ; profil actuel `7XN8526KZ7`, actif, expire 13/09/2027, capacité In-App Purchase uniquement. Sign In with Apple absent ; ajout coché en brouillon, NON enregistré. Même certificat `ios_distribution_all_apps_2026` à conserver.
- Blocage actuel : publication Firebase refusée par contrôle automatique, absence d'autorisation explicite pour modifier le backend de production. Aucun déploiement serveur et aucun nouveau build lancé. Sessions Google et Apple reconnectées.
- Prochaine action exacte, après accord : publier le correctif d'admission testé ; activer Sign In with Apple sur l'identifiant PRONO4 existant ; régénérer le profil existant et remplacer sa copie Codemagic sous la même référence/certificat ; vérifier CLIENT_ID du plist iOS ; un seul build manuel `Husain` / `prono4-ios-release` / `prono4-build90-ios-prep` / HEAD.
- Ne pas modifier : source canonique iOS déjà validé, Bundle ID, app Apple `6809793049`, certificat, IDs AdMob, votes/scores/classements ; ne pas utiliser le YAML Android du ZIP ni le dépôt `prono4-ios` avec `com.mundial.app`.
