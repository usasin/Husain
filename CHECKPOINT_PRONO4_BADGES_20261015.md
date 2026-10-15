# PRONO4 — correction générale des badges, 15 octobre 2026

## État

**Correctif général préparé et testé ; pas encore déployé en production.**
Le terminal Cloud Shell affiche « Site Unavailable » dans la session distante.
La correction manuelle d'un seul profil effectuée précédemment ne constitue pas la correction générale.
Aucun nouveau build Codemagic n'a été lancé. La version iOS soumise reste inchangée.

## Défaut et correction

Le backend BUILD90 met à jour les points après les résultats mais ne recalcule pas les champs `badge`, `knowledgeScore` et `resolved` pendant ses mises à jour incrémentales. Une migration peut aussi laisser des copies du même pronostic sous plusieurs identifiants.

Le nouveau codebase indépendant `prono4-badges` :

- répare tous les joueurs existants au premier passage ;
- surveille résultats finaux, pronostics, migrations, changements de membres, dates des matchs et reconstructions générales ;
- regroupe les changements et recalcule les badges toutes les 15 minutes si nécessaire ;
- suit les chaînes `migratedTo`, utilise le profil actif et déduplique chaque couple joueur/match ;
- conserve le barème : 30 derniers matchs terminés, +0,45 par score exact et lissage existant ; Amateur à 40, Connaisseur à 55, Confirmé à 70, Expert à 85 ; moins de trois résultats : Footix provisoire à 50 ;
- exclut les scores encore en direct ; conserve les anciens résultats manuels sans champ de statut ;
- modifie uniquement les trois champs du badge dans les quatre tableaux `rankingSnapshots` ;
- ne modifie aucun point, profil, avatar, équipe, duel, classement par compétition, résultat, pronostic ou règle de sécurité ;
- utilise des transactions, un verrou temporaire et une révision des sources pour préserver les modifications concurrentes et reporter tout calcul devenu ancien.

Une période absente ou incompatible laisse la réparation en attente. Après une erreur, le verrou est libéré pour permettre une nouvelle tentative. Sans changement, un passage lit seulement le document d'état `system/automaticBadgesV1`.

## Déploiement ciblé

Depuis un environnement connecté au projet existant `mundial2026-ibab-01`, à la racine du dépôt :

```bash
bash scripts/deploy_automatic_badges.sh
```

Le script installe les dépendances verrouillées, exécute les tests unitaires, déploie uniquement `functions:prono4-badges` avec `firebase.badges.json`, puis lance immédiatement sa tâche planifiée.
Il ne déploie ni les anciennes fonctions, ni les règles Firestore, ni le code mobile.

Pour inspecter la réparation une fois la tâche terminée :

```bash
node badge-functions/repair.js --status
```

`version: 1`, `dirty: false` et une date `repairedAt` récente indiquent un passage terminé. `--preview` calcule un aperçu sans écriture ; `--apply` force une réparation générale avec les mêmes protections. Ces commandes ne publient ni noms, ni courriels, ni identifiants dans leur sortie.

## Validation

- 13 tests unitaires : seuils, plusieurs joueurs et périodes, migrations successives, copies, identifiants archivés/supprimés, deux profils actifs, absence de fusion de comptes sans lien, cycle invalide, scores en direct, corrections/retraits, limite de 30, nouveau joueur, conservation exacte des autres champs et idempotence.
- 8 tests sur l'émulateur Firestore : réparation persistée dans les quatre vues, profils/équipes inchangés, second passage léger, correction future d'un résultat, concurrence avec les sources et les points/images, périodes absentes, reprise après erreur, vrais gestionnaires de résultat/migration et absence de boucle.
- Sept fonctions v2 chargées avec le SDK installé ; syntaxe Node et script de déploiement vérifiés.

Lancer les tests d'intégration uniquement sur le projet local isolé :

```bash
python3 scripts/test_badges_emulator.py --emulator-jar /chemin/firestore-emulator.jar
```

## Autres compétitions sans football-data

La saisie administrateur des matchs (`saveClubMatch`) et des scores finaux (`setMatchScore`) existe. Le catalogue `kCompetitions` et ses icônes restent intégrés au code mobile ; les compétitions inconnues sont filtrées. Les calendriers diffusés (`fixtureManifests`) sont actuellement reconstruits à partir des réponses football-data et ne fusionnent pas les matchs ajoutés manuellement.

Ajouter des compétitions gérées sans API est donc possible, mais nécessite un changement applicatif pour un catalogue administrable (nom, icône, activation), et un changement serveur pour publier/conserver les calendriers et scores manuels. Sans fournisseur automatique, les matchs et les scores doivent être saisis par un administrateur ou fournis par une autre source autorisée. La liste exacte des nouvelles compétitions n'a pas encore été choisie. Aucune compétition ni icône supplémentaire n'a été ajoutée dans ce correctif.
