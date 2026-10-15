# PRONO4 — Ligue Europa manuelle — 15 octobre 2026

## Changement préparé

- Une seule compétition ajoutée : `europa-league` / `EL`, Ligue Europa.
- Icône SVG embarquée, disponible hors connexion ; les emblèmes existants restent utilisés pour les autres compétitions.
- Sélection disponible dans les réglages, le calendrier, les pages compétition et les formulaires administrateur. Les utilisateurs qui suivaient toutes les anciennes compétitions reçoivent la nouvelle une fois ; une désactivation explicite reste conservée localement et dans les préférences du compte.
- Ajout manuel des rencontres et saisie manuelle du score final par les contrôles administrateur existants. Match nul autorisé par défaut pour la phase de ligue ; réglage conservé pour les autres phases.
- Les nouvelles rencontres manuelles utilisent le préfixe `manual_el_`. Aucun jeton ni appel football-data n'est nécessaire pour cette compétition.

## Calendrier serveur

`badge-functions/europa-fixtures.json` prépare les huit rencontres de l'OM en phase de ligue 2026/27, sans aucun score. Source UEFA vérifiée le 15 octobre :

https://fr.uefa.com/uefaeuropaleague/news/02a8-21777ab4e01c-05f67fa1d878-1000--ligue-europa-le-calendrier-de-la-phase-de-ligue-par-equipe/

Le premier passage du planificateur existant initialise les rencontres absentes et publie `fixtureManifests/europa-league`. Les déclencheurs `publishEuropaLeagueMatch` et `publishEuropaLeagueResult` publient ensuite les changements. Le client écoute ce document et garde son calendrier en cache. Les matchs déjà modifiés ou supprimés après l'initialisation ne sont pas recréés. Aucun score n'est inventé ; un résultat 0–0 est pris en charge.

Le nouveau module écrit uniquement les nouvelles rencontres, son marqueur d'initialisation et le manifeste Europa. Il ne modifie ni les calendriers des autres compétitions, ni leurs métadonnées API, ni les points, photos, équipes ou classements. Le correctif général des badges reste dans la même codebase indépendante `prono4-badges`.

Déploiement ciblé préparé :

```sh
bash scripts/deploy_automatic_badges.sh
```

Ce script déploie uniquement `functions:prono4-badges`, puis déclenche son planificateur existant. Il ne déploie aucune règle Firestore et ne remplace pas la codebase historique des fonctions.

## Vérification

- 14 tests Flutter : catalogue, préférences, SVG local et régressions de publication existantes.
- 16 tests unitaires Node : badges, migrations, résultats et conversion du calendrier manuel.
- 12 tests d'intégration Firestore sur le projet local jetable `demo-prono4-badges` : réparation globale, concurrence, reprise, déclencheurs, initialisation sans écrasement et diffusion des scores manuels.
- Analyse de `lib` et `test` sans erreur ; avertissements et informations déjà présents dans le projet. L'analyse de la racine remonte aussi neuf erreurs dans le gabarit non compilé `scripts/templates/permissions_welcome_screen.dart`.
- Archive canonique reconstruite avec 92 fichiers ; restauration complète exécutée dans un répertoire temporaire et validée par `PATCH_IOS_ATT_PREFLIGHT.py`. Dépendances verrouillées, ATT et connexion Google conservés.
- SHA-256 archive : `d90422bf80cc5404a486727ea2a8c91651d9a6e10707c8bbfc2b94c4bd7d43d3`.

## État de livraison

Le code est préparé pour la PR existante https://github.com/usasin/Husain/pull/3, avec le correctif général des badges. Le déploiement de cette codebase n'est pas effectué : Cloud Shell affiche encore « Site Unavailable — Unable to access this site » dans le navigateur de travail lors de la vérification du 15 octobre.

Aucun nouveau build Codemagic n'a été lancé. La soumission App Store déjà envoyée reste indépendante et inchangée. La version source `2.8.14+94` est conservée sur cette branche de préparation ; avant une prochaine publication, choisir un numéro de build conforme à la plateforme.

Pour rendre la compétition visible dans les applications installées, il reste le déploiement ciblé du serveur puis une version Android/iOS contenant ce catalogue. Les appareils actuels ne peuvent pas découvrir une nouvelle compétition codée dans un futur catalogue.
