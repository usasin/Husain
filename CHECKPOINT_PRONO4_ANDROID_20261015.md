# PRONO4 — préparation Android — 15 octobre 2026

## État constaté dans Google Play Console

- Application : PRONO4 : Pronostics Foot, `com.mundial.app`.
- Version publiée : **2.8.14 (94)**, production, déploiement à 100 % ; dernière version et dernier bundle affichés : 94.
- SDK cible du bundle 94 : 36 ; Android minimal : API 24.
- La version suivante préparée est **2.8.15 (95)**.
- Tableau de bord vérifié après reconnexion au compte développeur le 15 octobre au soir.
- Classification déjà en vigueur : **PEGI 3 en Europe**, tout public ESRB et ClassInd ; aucune modification du questionnaire Android n'a été nécessaire.

Le workflow manuel `prono4-android-release` utilise une machine Linux et Flutter 3.44.8. Il restaure l'archive canonique contenant la Ligue Europa, valide le certificat de la clé d'importation avant compilation, résout les dépendances verrouillées, analyse `lib`/`test`, exécute les 14 tests Flutter puis produit et vérifie l'AAB signé. Les versions sont fournies par les arguments Android de compilation : aucune modification du numéro de version canonique iOS n'est nécessaire.

## Signature indispensable avant compilation

Aucune clé Android n'est enregistrée dans les identités Codemagic. Les variables de l'application ne contiennent que les fichiers Firebase iOS ; aucune variable globale n'existe. L'archive Android transmise `prono4 mise a jours dernier 90(1).zip` ne contient ni `.jks`, ni `.keystore`, ni `key.properties`, ni AAB.

Il faut donc importer la **clé d'importation existante** dans Codemagic, section **Code signing identities → Android keystores**, avec la référence `prono4_android_upload`. Les mots de passe et l'alias se renseignent directement dans les champs privés Codemagic, jamais dans GitHub.

Certificat public d'importation relevé dans Google Play :

- SHA-256 : `70:D9:ED:8F:BA:A4:4F:08:76:8F:BB:F4:D7:D8:41:8C:40:2C:D3:D0:00:AA:C3:83:98:FF:CE:88:0D:BB:FA:84`.
- SHA-1 : `4B:59:43:1A:81:1C:C0:B4:28:06:6C:65:FA:65:14:BE:23:5B:C1:92`.

`scripts/PREPARE_ANDROID_SIGNING.py` bloque toute autre clé, n'affiche aucun secret et refuse d'écraser un `android/key.properties` existant. Il vérifie également `com.mundial.app` et le projet Firebase attendu. Les fichiers de signature restent ignorés par Git.

Validation de la préparation : YAML analysé, deux workflows iOS antérieurs comparés et identiques, absence de déclenchement ou de publication automatique, absence de clé et certificat différent correctement refusés sans création de fichier privé. Le contrôle d'artefact refuse un ZIP non signé et un ZIP signé avec un certificat jetable différent, via l'outil réel `jarsigner` du module JDK local ; aucun AAB de production n'a été compilé. L'échappement des propriétés privées a été vérifié avec le lecteur Java `Properties`, y compris espaces, séparateurs, retours à la ligne et Unicode. `flutter pub get --offline --enforce-lockfile` réussit sans modification du verrou de dépendances.

## Serveur et livraison

Le serveur de badges généraux et de calendrier Europa reste à déployer avec `scripts/deploy_automatic_badges.sh`. Cloud Shell affiche toujours « Site Unavailable » dans le navigateur de travail lors de la nouvelle tentative du soir.

Aucun build Android ou iOS supplémentaire n'a été lancé pendant cette préparation. Aucun AAB 95 n'a été envoyé, et la production Android 94 reste inchangée. La soumission App Store existante n'a pas été modifiée. Après configuration de la clé : sélectionner la branche de cette PR et uniquement `prono4-android-release` dans Codemagic, puis importer le bundle 95 dans Google Play. Ne pas relancer le workflow iOS.
