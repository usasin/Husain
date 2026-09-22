# PRONO4 BUILD73 — un seul déploiement backend nécessaire
firebase deploy --only "functions:syncClubMatchesNow,functions:syncClubMatchesScheduled,functions:notifyMatchFinished,functions:notifyLastTeammateToVote"
