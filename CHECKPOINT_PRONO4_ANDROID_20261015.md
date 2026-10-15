# PRONO4 — livraison Android Studio — 15 octobre 2026

## Fonctionnement demandé par l’utilisateur

- iOS : sources GitHub puis Codemagic.
- Android : fournir le ZIP du projet Flutter pour compilation dans Android Studio sur son ordinateur.
- La clé privée et les mots de passe Android restent dans son environnement Android Studio ; aucun ajout de clé Android à Codemagic n’est nécessaire.

## Version

Google Play Console a été vérifiée le 15 octobre au soir : production 2.8.14 (94), déployée à 100 %, SDK cible 36 et minimum API 24. La classification européenne est déjà PEGI 3.

Le projet du ZIP porte la version **2.8.15+95** et contient le catalogue Ligue Europa, l’icône locale, la saisie manuelle des rencontres et des résultats, ainsi que les préférences de compétition. Les 12 images d’origine sont conservées octet pour octet ; seule l’icône Europa est ajoutée.

La version du ZIP est indépendante du `pubspec.yaml` canonique iOS, qui reste inchangé. Le workflow Android expérimental préparé précédemment a été retiré ; `codemagic.yaml` conserve exactement ses deux workflows iOS antérieurs. Aucun nouveau build Codemagic n’a été lancé.

## Utilisation du ZIP

Décompresser dans un nouveau dossier et ouvrir le dossier contenant `pubspec.yaml` dans Android Studio. Conserver la clé de publication Android existante et recopier `android/key.properties` depuis l’ancien projet, avec son fichier de clé à l’emplacement indiqué. Le ZIP ne contient pas de mot de passe ni de clé privée. Suivre `LISEZ_MOI_ANDROID_STUDIO.txt` ou lancer `CONSTRUIRE_ANDROID_95.bat` depuis un environnement où Flutter est disponible.

## Serveur

Le dossier `serveur` du ZIP fournit uniquement la codebase indépendante des badges généraux et du calendrier manuel Europa, sa configuration ciblée et son script de déploiement. Les fonctions historiques et les règles Firestore ne sont pas remplacées par ce script.

Le déploiement serveur reste à effectuer : Cloud Shell affiche « Site Unavailable » dans le navigateur de travail. Installer la nouvelle version Android ne déploie pas automatiquement le serveur.

Aucun AAB 95 n’a été compilé ou envoyé à Google Play dans cette session. La production 94 et la soumission App Store existante restent inchangées.

## Livrable vérifié

ZIP : `PRONO4_ANDROID_STUDIO_2.8.15_95.zip`, 174 fichiers, 4460944 octets. SHA-256 : `b9b53181a37f2f135b15e616147dfc2015c1cf114ccedce284e19903dd2e9eb6`.

Sur le projet exporté : 14 tests Flutter et 16 tests serveur réussis, analyse `lib`/`test` sans erreur (avertissements et informations existants). Les dépendances verrouillées sont conservées et les 12 images d’origine sont identiques à l’archive transmise. Le ZIP ne contient ni cache de compilation, ni chemin SDK local, ni clé privée. Il contient les sources serveur ciblées avec leur script de déploiement, encore à exécuter.
