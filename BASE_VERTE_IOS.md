# PRONO4 iOS — base du dernier build vert

Base exacte : build Codemagic **42** du 14 octobre 2026, commit **ffb33d5b634885706695148033ab1baa7652c16a**, branche `prono4-build90-ios-prep`.

Cette branche conserve ses paramètres Flutter/Xcode, l’intégration Apple, le certificat, le profil, le Podfile et le script de connexion Google/Apple. Elle reprend son initialisation Firebase iOS native, son passage d’autorisations ATT et son identifiant de publicité récompensée iOS. Aucun nouveau droit Apple ni outil de modification Xcode n’est ajouté.

Les corrections Flutter courantes (comptes, résultats définitifs, classements mensuels, récompenses et présentation du profil) sont intégrées à l’archive de sources utilisée par le circuit existant. **110 empreintes de fichiers** et l’archive sont vérifiées. La version est **2.8.19 (99 minimum)** ; le numéro effectif suit TestFlight.

La seule protection ajoutée à la préparation native conserve le verrou de dépendances et évite le test d’exemple produit par `flutter create`. Les versions testées restent verrouillées. Les étapes de restauration/précontrôle reconnaissent la nouvelle version et les nouveaux fichiers.

Validation locale : **95 tests réussis**, incluant les 10 tests historiques du build vert et les 85 tests de la version corrigée. L’analyse et la compilation Mac sont à enregistrer après leurs résultats effectifs. Le workflow de validation reprend le workflow vert sans sa section de distribution. Aucune publication ni disponibilité TestFlight n’est annoncée avant confirmation.

Le profil existant ne couvre pas les notifications push iOS ; cette branche ne prétend pas les activer. La connexion native Google/Apple reste à vérifier sur un iPhone réel. Les fonctions serveur et le projet Android de travail ne sont pas modifiés par cette reprise iOS.
